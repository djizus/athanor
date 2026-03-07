import Phaser from 'phaser';
import { getSettingsSnapshot } from '@/stores/settingsStore';
import type { AthanorHero } from '../PhaserBridge';
import { PhaserBridge } from '../PhaserBridge';
import { EventEffect } from '../objects/EventEffect';
import { HeroSprite } from '../objects/HeroSprite';
import { ZoneBackground } from '../objects/ZoneBackground';
import { baseCampWorldX, HERO_ROW_SPACING, HERO_Y_RATIO } from '../utils/layout';

const MUSIC_PLAYLIST = ['menu-theme', 'game-loop-1', 'game-loop-2'] as const;

/** Tracks loaded lazily after boot (not blocking initial load) */
const LAZY_MUSIC = [
  { key: 'game-loop-1', file: 'game_loop_1.mp3' },
  { key: 'game-loop-2', file: 'game_loop_2.mp3' },
] as const;

export class MainScene extends Phaser.Scene {
  private bridge: PhaserBridge | null = null;

  private zoneBackground: ZoneBackground | null = null;
  private eventEffect: EventEffect | null = null;

  private heroContainer!: Phaser.GameObjects.Container;
  private heroSprites = new Map<number, HeroSprite>();
  private lastHeroes: AthanorHero[] = [];
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

    this.input.mouse?.disableContextMenu();
    this.sound.pauseOnBlur = false;

    this.bridge.on('heroesUpdated', this.onHeroesUpdated);
    this.bridge.on('craftResult', this.onCraftResult);
    this.bridge.on('gameOver', this.onGameOver);

    this.scale.on(Phaser.Scale.Events.RESIZE, this.onResize, this);

    for (const track of LAZY_MUSIC) {
      if (!this.cache.audio.exists(track.key)) {
        this.load.audio(track.key, `/assets/sounds/music/${track.file}`);
      }
    }
    this.load.start();

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

  private onResize(gameSize: Phaser.Structs.Size): void {
    const w = gameSize.width;
    const h = gameSize.height;

    this.zoneBackground?.resize(w, h);
    this.repositionHeroes(w, h);
  }

  private repositionHeroes(w: number, h: number): void {
    const bx = baseCampWorldX(w);

    this.lastHeroes.forEach((hero, index) => {
      const by = h * HERO_Y_RATIO + index * HERO_ROW_SPACING;
      const sprite = this.heroSprites.get(hero.hero_id);
      if (!sprite) return;
      sprite.setBasePosition(bx, by);
      sprite.syncToHero(hero);
    });
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
      console.info('[MainScene:music] track not yet loaded, skipping', { key, index });
      this.playNextMusicTrack();
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
    const w = this.scale.width;
    const h = this.scale.height;
    const bx = baseCampWorldX(w);

    for (const [heroId, sprite] of this.heroSprites.entries()) {
      if (!activeIds.has(heroId)) {
        sprite.destroy();
        this.heroSprites.delete(heroId);
      }
    }

    heroes.forEach((hero, index) => {
      const by = h * HERO_Y_RATIO + index * HERO_ROW_SPACING;
      const sprite = this.getOrCreateHeroSprite(hero, index, bx, by);
      sprite.setBasePosition(bx, by);
      sprite.syncToHero(hero);
    });
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

  private tryPlaySound(key: string, volume = 0.5): void {
    if (!this.cache.audio.exists(key)) return;
    const { sfxVolume } = getSettingsSnapshot();
    this.sound.play(key, { volume: volume * sfxVolume });
  }

  private shutdown(): void {
    this.scale.off(Phaser.Scale.Events.RESIZE, this.onResize, this);

    if (this.bridge) {
      this.bridge.off('heroesUpdated', this.onHeroesUpdated);
      this.bridge.off('craftResult', this.onCraftResult);
      this.bridge.off('gameOver', this.onGameOver);
    }

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
