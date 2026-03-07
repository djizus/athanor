import Phaser from 'phaser';
import { ZONE_NAMES } from '@/game/constants';
import { getSettingsSnapshot } from '@/stores/settingsStore';
import type { AthanorHero } from '../PhaserBridge';
import { PhaserBridge } from '../PhaserBridge';
import { EventEffect } from '../objects/EventEffect';
import { HeroSprite } from '../objects/HeroSprite';
import { ZoneBackground } from '../objects/ZoneBackground';
import { ZoneConnection } from '../objects/ZoneConnection';
import { ZoneNode } from '../objects/ZoneNode';
import { computeNodeLayout, NODE_COUNT } from '../utils/layout';

const ZONE_TEXTURE_KEYS = [
  'zone-athanor', 'zone-hollows', 'zone-cavern', 'zone-spire', 'zone-abyss', 'zone-crystalveil',
];

const ZONE_LABELS = ['The Athanor', ...ZONE_NAMES];

const MUSIC_PLAYLIST = ['menu-theme', 'game-loop-1', 'game-loop-2'] as const;

const LAZY_MUSIC = [
  { key: 'game-loop-1', file: 'game_loop_1.mp3' },
  { key: 'game-loop-2', file: 'game_loop_2.mp3' },
] as const;

export class MainScene extends Phaser.Scene {
  private bridge: PhaserBridge | null = null;

  private zoneBackground: ZoneBackground | null = null;
  private eventEffect: EventEffect | null = null;
  private zoneNodes: ZoneNode[] = [];
  private zoneConnections: ZoneConnection[] = [];

  private heroContainer!: Phaser.GameObjects.Container;
  private heroSprites = new Map<number, HeroSprite>();
  private lastHeroes: AthanorHero[] = [];
  private currentMusicIndex = 0;
  private currentMusicSound: Phaser.Sound.BaseSound | null = null;

  private readonly onMusicComplete = (): void => {
    this.playNextMusicTrack();
  };

  private readonly onFirstInteractionMusic = (): void => {
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

    this.createNodeGraph();

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

    if (this.sound.locked) {
      this.sound.once(Phaser.Sound.Events.UNLOCKED, this.startMusicPlaylist, this);
      this.input.once(Phaser.Input.Events.POINTER_DOWN, this.onFirstInteractionMusic);
    } else {
      this.startMusicPlaylist();
    }

    this.events.once(Phaser.Scenes.Events.SHUTDOWN, this.shutdown, this);
  }

  update(time: number, delta: number): void {
    for (const conn of this.zoneConnections) {
      conn.update(time, delta);
    }
  }

  private createNodeGraph(): void {
    const w = this.scale.width;
    const h = this.scale.height;
    const layout = computeNodeLayout(w, h);

    for (let i = 0; i < NODE_COUNT; i++) {
      const node = new ZoneNode(
        this,
        i,
        ZONE_LABELS[i],
        ZONE_TEXTURE_KEYS[i],
        layout.centerX,
        layout.nodeY(i),
        layout.nodeWidth,
        layout.nodeHeight,
      );
      node.setDepth(5);
      this.zoneNodes.push(node);
    }

    for (let i = 0; i < NODE_COUNT - 1; i++) {
      const conn = new ZoneConnection(this, i);
      conn.setDepth(4);

      const bottom = this.zoneNodes[i].getTopAnchor();
      const top = this.zoneNodes[i + 1].getBottomAnchor();
      conn.setEndpoints(bottom.x, bottom.y, top.x, top.y);

      this.zoneConnections.push(conn);
    }
  }

  private onResize(gameSize: Phaser.Structs.Size): void {
    const w = gameSize.width;
    const h = gameSize.height;

    this.zoneBackground?.resize(w, h);
    this.repositionNodeGraph(w, h);
    this.repositionHeroes();
  }

  private repositionNodeGraph(w: number, h: number): void {
    const layout = computeNodeLayout(w, h);

    for (let i = 0; i < this.zoneNodes.length; i++) {
      this.zoneNodes[i].resize(layout.centerX, layout.nodeY(i), layout.nodeWidth, layout.nodeHeight);
    }

    for (let i = 0; i < this.zoneConnections.length; i++) {
      const bottom = this.zoneNodes[i].getTopAnchor();
      const top = this.zoneNodes[i + 1].getBottomAnchor();
      this.zoneConnections[i].setEndpoints(bottom.x, bottom.y, top.x, top.y);
    }
  }

  private repositionHeroes(): void {
    this.lastHeroes.forEach((hero, index) => {
      const sprite = this.heroSprites.get(hero.hero_id);
      if (!sprite) return;
      const pos = this.getHeroTargetPosition(hero, index, this.lastHeroes.length);
      sprite.setBasePosition(pos.x, pos.y);
      sprite.syncToHero(hero);
    });
  }

  private startMusicPlaylist(): void {
    if (this.currentMusicSound) return;
    this.currentMusicIndex = 0;
    this.playMusicTrack(this.currentMusicIndex);
  }

  private playNextMusicTrack(): void {
    this.currentMusicIndex = (this.currentMusicIndex + 1) % MUSIC_PLAYLIST.length;
    this.playMusicTrack(this.currentMusicIndex);
  }

  private playMusicTrack(index: number): void {
    const key = MUSIC_PLAYLIST[index];
    if (!this.cache.audio.exists(key)) {
      this.playNextMusicTrack();
      return;
    }

    this.currentMusicSound?.off(Phaser.Sound.Events.COMPLETE, this.onMusicComplete, this);
    this.currentMusicSound?.destroy();

    const { musicVolume } = getSettingsSnapshot();
    const music = this.sound.add(key, { loop: false, volume: musicVolume });
    music.once(Phaser.Sound.Events.COMPLETE, this.onMusicComplete, this);
    music.play();

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
      const pos = this.getHeroTargetPosition(hero, index, heroes.length);
      const sprite = this.getOrCreateHeroSprite(hero, index, pos.x, pos.y);
      sprite.setBasePosition(pos.x, pos.y);
      sprite.syncToHero(hero);
    });
  }

  private getHeroTargetPosition(hero: AthanorHero, heroIndex: number, heroCount: number): { x: number; y: number } {
    const now = Math.floor(Date.now() / 1000);
    const isExploring = hero.available_at > now;

    if (isExploring) {
      const zoneIndex = this.getExploringZoneIndex(hero);
      const node = this.zoneNodes[zoneIndex];
      if (node) {
        return node.getHeroSlotWorldPosition(heroIndex, heroCount);
      }
    }

    const athanorNode = this.zoneNodes[0];
    if (athanorNode) {
      return athanorNode.getHeroSlotWorldPosition(heroIndex, heroCount);
    }

    return { x: this.scale.width / 2, y: this.scale.height * 0.82 };
  }

  private getExploringZoneIndex(hero: AthanorHero): number {
    const now = Math.floor(Date.now() / 1000);
    const remaining = Math.max(0, hero.available_at - now);

    if (remaining > 50) return 1;
    if (remaining > 40) return 2;
    if (remaining > 30) return 3;
    if (remaining > 20) return 4;
    if (remaining > 10) return 5;
    return 1;
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

    for (const conn of this.zoneConnections) conn.destroy();
    this.zoneConnections = [];

    for (const node of this.zoneNodes) node.destroy();
    this.zoneNodes = [];

    this.zoneBackground?.destroy();
    this.zoneBackground = null;
    this.eventEffect = null;
  }
}
