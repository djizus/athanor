import Phaser from 'phaser';
import { getSettingsSnapshot } from '@/stores/settingsStore';
import type { AthanorHero } from '../PhaserBridge';
import { PhaserBridge } from '../PhaserBridge';
import { EventEffect } from '../objects/EventEffect';
import { HeroSprite } from '../objects/HeroSprite';
import { ZoneBackground } from '../objects/ZoneBackground';
import { BASE_CAMP_X, GAME_HEIGHT, GAME_WIDTH, WORLD_WIDTH } from '../utils/layout';

const HERO_START_Y = 430;
const HERO_ROW_SPACING = 48;
const HERO_STATUS_EXPLORING = 1;
const MUSIC_PLAYLIST = ['menu-theme', 'game-loop-1', 'game-loop-2'] as const;

export class MainScene extends Phaser.Scene {
  private bridge: PhaserBridge | null = null;

  private zoneBackground: ZoneBackground | null = null;
  private eventEffect: EventEffect | null = null;

  private heroContainer!: Phaser.GameObjects.Container;
  private heroSprites = new Map<number, HeroSprite>();
  private lastHeroes: AthanorHero[] = [];
  private cameraTargetX = BASE_CAMP_X;
  private dragActive = false;
  private lastPointerX = 0;
  private manualPanUntil = 0;
  private currentMusicIndex = 0;
  private currentMusicSound: Phaser.Sound.BaseSound | null = null;

  private readonly onMusicComplete = (): void => {
    console.info('[MainScene:music] track completed, advancing playlist');
    this.playNextMusicTrack();
  };

  private readonly onFirstInteractionMusic = (): void => {
    console.info('[MainScene:music] first pointer interaction received, attempting playlist start');
    this.startMusicPlaylist();
  };

  private readonly onHeroesUpdated = (heroes: AthanorHero[]): void => {
    this.lastHeroes = heroes;
    this.syncHeroes(heroes);
  };

  private readonly onFocusedHeroChange = (): void => {
    this.updateCameraTarget();
  };

  private readonly onHeroSelected = (heroId: number): void => {
    const selectedSprite = this.heroSprites.get(heroId);
    if (!selectedSprite) return;
    this.cameraTargetX = selectedSprite.x;
    this.manualPanUntil = 0;
  };

  private readonly onPointerDown = (pointer: Phaser.Input.Pointer): void => {
    const isDragButton = pointer.rightButtonDown() || pointer.middleButtonDown();
    if (!isDragButton) return;
    this.dragActive = true;
    this.lastPointerX = pointer.x;
  };

  private readonly onPointerMove = (pointer: Phaser.Input.Pointer): void => {
    if (!this.dragActive || !pointer.isDown) return;
    const isDragButton = pointer.rightButtonDown() || pointer.middleButtonDown();
    if (!isDragButton) return;

    const deltaX = pointer.x - this.lastPointerX;
    this.lastPointerX = pointer.x;

    const cam = this.cameras.main;
    const maxScrollX = Math.max(0, WORLD_WIDTH - GAME_WIDTH);
    cam.scrollX = Phaser.Math.Clamp(cam.scrollX - deltaX, 0, maxScrollX);
    this.manualPanUntil = this.time.now + 1800;
    this.cameraTargetX = cam.midPoint.x;
  };

  private readonly onPointerUp = (): void => {
    this.dragActive = false;
  };

  private readonly onCraftResult = (payload: { discovered: boolean }): void => {
    if (!this.eventEffect) return;
    if (payload.discovered) {
      this.eventEffect.playDiscovery();
      this.tryPlaySound('discovery', 0.6);
    } else {
      this.eventEffect.playCraftFail();
      this.tryPlaySound('brew-fail', 0.3);
    }
  };

  private readonly onGameOver = (): void => {
    this.eventEffect?.playGameOver();
    this.tryPlaySound('victory', 0.7);
  };

  constructor() {
    super('MainScene');
  }

  create(): void {
    const bridge = this.registry.get('bridge');
    if (!(bridge instanceof PhaserBridge)) return;
    this.bridge = bridge;

    this.zoneBackground = new ZoneBackground(this);
    this.eventEffect = new EventEffect(this);
    this.heroContainer = this.add.container(0, 0);
    this.heroContainer.setDepth(12);

    const cam = this.cameras.main;
    cam.setBounds(0, 0, WORLD_WIDTH, GAME_HEIGHT);
    cam.centerOn(BASE_CAMP_X, GAME_HEIGHT / 2);
    this.cameraTargetX = cam.midPoint.x;

    this.input.mouse?.disableContextMenu();
    this.sound.pauseOnBlur = false;

    this.bridge.on('heroesUpdated', this.onHeroesUpdated);
    this.bridge.on('focusedHeroChange', this.onFocusedHeroChange);
    this.bridge.on('heroSelected', this.onHeroSelected);
    this.bridge.on('craftResult', this.onCraftResult);
    this.bridge.on('gameOver', this.onGameOver);

    this.input.on(Phaser.Input.Events.POINTER_DOWN, this.onPointerDown);
    this.input.on(Phaser.Input.Events.POINTER_MOVE, this.onPointerMove);
    this.input.on(Phaser.Input.Events.POINTER_UP, this.onPointerUp);
    this.input.on(Phaser.Input.Events.GAME_OUT, this.onPointerUp);
    this.input.on(Phaser.Input.Events.POINTER_UP_OUTSIDE, this.onPointerUp);

    console.info('[MainScene:music] audio setup', {
      locked: this.sound.locked,
      playlist: [...MUSIC_PLAYLIST],
    });

    if (this.sound.locked) {
      console.warn('[MainScene:music] sound is locked, waiting for unlock');
      this.sound.once(Phaser.Sound.Events.UNLOCKED, this.startMusicPlaylist, this);
      this.input.once(Phaser.Input.Events.POINTER_DOWN, this.onFirstInteractionMusic);
    } else {
      this.startMusicPlaylist();
    }

    this.events.once(Phaser.Scenes.Events.SHUTDOWN, this.shutdown, this);
  }

  update(_time: number, delta: number): void {
    if (this.manualPanUntil > this.time.now) return;

    this.updateCameraTarget();

    const cam = this.cameras.main;
    const maxScrollX = Math.max(0, WORLD_WIDTH - GAME_WIDTH);
    const desiredScrollX = Phaser.Math.Clamp(this.cameraTargetX - GAME_WIDTH / 2, 0, maxScrollX);
    const lerpFactor = 1 - Math.exp(-delta * 0.008);
    cam.scrollX = Phaser.Math.Linear(cam.scrollX, desiredScrollX, lerpFactor);
  }

  private startMusicPlaylist(): void {
    if (this.currentMusicSound) {
      console.info('[MainScene:music] playlist already started');
      return;
    }
    this.currentMusicIndex = 0;
    console.info('[MainScene:music] starting playlist from first track');
    this.playMusicTrack(this.currentMusicIndex);
  }

  private playNextMusicTrack(): void {
    this.currentMusicIndex = (this.currentMusicIndex + 1) % MUSIC_PLAYLIST.length;
    this.playMusicTrack(this.currentMusicIndex);
  }

  private playMusicTrack(index: number): void {
    const key = MUSIC_PLAYLIST[index];
    if (!this.cache.audio.exists(key)) {
      console.error('[MainScene:music] track missing in cache', { key, index });
      return;
    }

    this.currentMusicSound?.off(Phaser.Sound.Events.COMPLETE, this.onMusicComplete, this);
    this.currentMusicSound?.destroy();

    const { musicVolume } = getSettingsSnapshot();
    console.info('[MainScene:music] playing track', { key, index, musicVolume });
    const music = this.sound.add(key, { loop: false, volume: musicVolume });
    music.once(Phaser.Sound.Events.COMPLETE, this.onMusicComplete, this);
    const started = music.play();

    if (!started) {
      console.warn('[MainScene:music] play() returned false', { key, index, musicVolume });
    }

    this.currentMusicSound = music;
  }

  private syncHeroes(heroes: AthanorHero[]): void {
    const activeIds = new Set(heroes.map((h) => h.hero_id));

    for (const [heroId, sprite] of this.heroSprites.entries()) {
      if (!activeIds.has(heroId)) {
        sprite.destroy();
        this.heroSprites.delete(heroId);
      }
    }

    heroes.forEach((hero, index) => {
      const by = HERO_START_Y + index * HERO_ROW_SPACING;
      const sprite = this.getOrCreateHeroSprite(hero, index, BASE_CAMP_X, by);
      sprite.setBasePosition(BASE_CAMP_X, by);
      sprite.syncToHero(hero);
    });

    this.updateCameraTarget();
  }

  private getOrCreateHeroSprite(hero: AthanorHero, idx: number, bx: number, by: number): HeroSprite {
    const existing = this.heroSprites.get(hero.hero_id);
    if (existing) return existing;

    if (!this.eventEffect) throw new Error('EventEffect must exist before creating hero sprites');

    const sprite = new HeroSprite(this, hero, idx, bx, by, this.eventEffect);
    this.heroContainer.add(sprite);
    this.heroSprites.set(hero.hero_id, sprite);
    return sprite;
  }

  private updateCameraTarget(): void {
    const selectedHeroId = this.bridge?.selectedHeroId ?? -1;
    const focusedHeroId = this.bridge?.focusedHeroId ?? -1;

    const selectedHero = this.lastHeroes.find((hero) => hero.hero_id === selectedHeroId);
    if (selectedHero) {
      this.cameraTargetX = this.getHeroWorldX(selectedHero);
      return;
    }

    const focusedHero = this.lastHeroes.find((hero) => hero.hero_id === focusedHeroId);
    if (focusedHero?.status === HERO_STATUS_EXPLORING) {
      this.cameraTargetX = this.getHeroWorldX(focusedHero);
      return;
    }

    const exploringHero = this.lastHeroes.find((hero) => hero.status === HERO_STATUS_EXPLORING);
    if (exploringHero) {
      this.cameraTargetX = this.getHeroWorldX(exploringHero);
      return;
    }

    this.cameraTargetX = BASE_CAMP_X;
  }

  private getHeroWorldX(hero: AthanorHero): number {
    if (hero.status === HERO_STATUS_EXPLORING) {
      const progress = Phaser.Math.Clamp(hero.death_depth / 60, 0, 1);
      return BASE_CAMP_X + progress * (WORLD_WIDTH - BASE_CAMP_X - 100);
    }
    return BASE_CAMP_X;
  }

  private tryPlaySound(key: string, volume = 0.5): void {
    if (!this.cache.audio.exists(key)) return;
    const { sfxVolume } = getSettingsSnapshot();
    this.sound.play(key, { volume: volume * sfxVolume });
  }

  private shutdown(): void {
    if (this.bridge) {
      this.bridge.off('heroesUpdated', this.onHeroesUpdated);
      this.bridge.off('focusedHeroChange', this.onFocusedHeroChange);
      this.bridge.off('heroSelected', this.onHeroSelected);
      this.bridge.off('craftResult', this.onCraftResult);
      this.bridge.off('gameOver', this.onGameOver);
    }

    this.input.off(Phaser.Input.Events.POINTER_DOWN, this.onPointerDown);
    this.input.off(Phaser.Input.Events.POINTER_MOVE, this.onPointerMove);
    this.input.off(Phaser.Input.Events.POINTER_UP, this.onPointerUp);
    this.input.off(Phaser.Input.Events.GAME_OUT, this.onPointerUp);
    this.input.off(Phaser.Input.Events.POINTER_UP_OUTSIDE, this.onPointerUp);
    this.input.off(Phaser.Input.Events.POINTER_DOWN, this.onFirstInteractionMusic);
    this.sound.off(Phaser.Sound.Events.UNLOCKED, this.startMusicPlaylist, this);

    this.currentMusicSound?.off(Phaser.Sound.Events.COMPLETE, this.onMusicComplete, this);
    this.currentMusicSound?.stop();
    this.currentMusicSound?.destroy();
    this.currentMusicSound = null;

    for (const sprite of this.heroSprites.values()) sprite.destroy();
    this.heroSprites.clear();

    this.zoneBackground?.destroy();
    this.zoneBackground = null;
    this.eventEffect = null;
  }
}
