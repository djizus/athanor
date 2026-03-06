import Phaser from 'phaser';
import { getZoneForDepth, HERO_STATUS_EXPLORING } from '@/game/constants';
import { getSettingsSnapshot } from '@/stores/settingsStore';
import type { AthanorHero } from '../PhaserBridge';
import { PhaserBridge } from '../PhaserBridge';
import { EventEffect } from '../objects/EventEffect';
import { HeroSprite } from '../objects/HeroSprite';
import { ZoneBackground } from '../objects/ZoneBackground';
import { GAME_WIDTH } from '../utils/layout';

const HERO_Y = 500;

export class MainScene extends Phaser.Scene {
  private bridge: PhaserBridge | null = null;

  private zoneBackground: ZoneBackground | null = null;
  private eventEffect: EventEffect | null = null;

  private heroContainer!: Phaser.GameObjects.Container;
  private heroSprites = new Map<number, HeroSprite>();
  private focusedHeroId = 0;
  private lastHeroes: AthanorHero[] = [];

  private readonly onHeroesUpdated = (heroes: AthanorHero[]): void => {
    this.lastHeroes = heroes;
    this.syncHeroes(heroes);

    const zoneId = this.getZoneForFocusedHero(heroes);
    this.zoneBackground?.setActiveZone(zoneId);
  };

  private readonly onFocusedHeroChange = (heroId: number): void => {
    this.focusedHeroId = heroId;
    const zoneId = this.getZoneForFocusedHero(this.lastHeroes);
    this.zoneBackground?.setActiveZone(zoneId);
  };

  private readonly onZoneChange = (zoneId: number | null): void => {
    this.zoneBackground?.setActiveZone(zoneId);
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

    this.focusedHeroId = this.bridge.focusedHeroId;

    this.bridge.on('heroesUpdated', this.onHeroesUpdated);
    this.bridge.on('focusedHeroChange', this.onFocusedHeroChange);
    this.bridge.on('zoneChange', this.onZoneChange);
    this.bridge.on('craftResult', this.onCraftResult);
    this.bridge.on('gameOver', this.onGameOver);

    this.events.once(Phaser.Scenes.Events.SHUTDOWN, this.shutdown, this);
  }

  private syncHeroes(heroes: AthanorHero[]): void {
    const activeIds = new Set(heroes.map((h) => h.hero_id));

    for (const [heroId, sprite] of this.heroSprites.entries()) {
      if (!activeIds.has(heroId)) {
        sprite.destroy();
        this.heroSprites.delete(heroId);
      }
    }

    const slotSpacing = 190;
    const centerX = GAME_WIDTH / 2;
    const startX = centerX - ((heroes.length - 1) * slotSpacing) / 2;

    heroes.forEach((hero, index) => {
      const bx = startX + index * slotSpacing;
      const sprite = this.getOrCreateHeroSprite(hero, index, bx, HERO_Y);
      sprite.setBasePosition(bx, HERO_Y);
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

  private getZoneForFocusedHero(heroes: AthanorHero[]): number | null {
    const hero = heroes.find((h) => h.hero_id === this.focusedHeroId) ?? heroes[0];
    if (!hero || hero.status !== HERO_STATUS_EXPLORING) return null;
    return getZoneForDepth(hero.death_depth);
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
      this.bridge.off('zoneChange', this.onZoneChange);
      this.bridge.off('craftResult', this.onCraftResult);
      this.bridge.off('gameOver', this.onGameOver);
    }

    for (const sprite of this.heroSprites.values()) sprite.destroy();
    this.heroSprites.clear();

    this.zoneBackground?.destroy();
    this.zoneBackground = null;
    this.eventEffect = null;
  }
}
