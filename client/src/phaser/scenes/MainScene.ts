import Phaser from 'phaser';
import { getSettingsSnapshot } from '@/stores/settingsStore';
import { getZoneForDepth, ZONE_DEPTHS } from '@/game/constants';
import type { AthanorHero, CraftResultPayload, ExplorationEventPayload } from '../PhaserBridge';
import { PhaserBridge } from '../PhaserBridge';
import { COLORS, ZONE_TINTS } from '../utils/colors';
import { EventEffect } from '../objects/EventEffect';
import { HeroSprite } from '../objects/HeroSprite';
import { ZoneBackground } from '../objects/ZoneBackground';
import { Cauldron } from '../objects/Cauldron';
import { ZonePortal } from '../objects/ZonePortal';
import { computePortalLayout, PORTAL_COUNT } from '../utils/layout';

interface HeroExpedition {
  startTime: number;
  lastKnownZone: number;
}

const MUSIC_PLAYLIST = ['menu-theme', 'game-loop-1', 'game-loop-2'] as const;

const LAZY_MUSIC = [
  { key: 'game-loop-1', file: 'game_loop_1.mp3' },
  { key: 'game-loop-2', file: 'game_loop_2.mp3' },
] as const;

const EFFECT_TINTS: Record<string, number> = {
  health: COLORS.green,
  power: COLORS.purple,
  regen: COLORS.blue,
};

const ENERGY_LINE_ALPHA = 0.2;
const ENERGY_LINE_WIDTH = 2;

export class MainScene extends Phaser.Scene {
  private bridge: PhaserBridge | null = null;

  private zoneBackground: ZoneBackground | null = null;
  private eventEffect: EventEffect | null = null;
  private cauldron: Cauldron | null = null;
  private portals: ZonePortal[] = [];
  private energyLinesGfx: Phaser.GameObjects.Graphics | null = null;

  private heroContainer!: Phaser.GameObjects.Container;
  private heroSprites = new Map<number, HeroSprite>();
  private heroExpeditions = new Map<number, HeroExpedition>();
  private lastHeroes: AthanorHero[] = [];
  private currentMusicIndex = 0;
  private currentMusicSound: Phaser.Sound.BaseSound | null = null;
  private ambientSound: Phaser.Sound.BaseSound | null = null;

  private readonly onMusicComplete = (): void => {
    this.playNextMusicTrack();
  };

  private readonly onFirstInteractionMusic = (): void => {
    this.startMusicPlaylist();
  };

  private readonly onHeroesUpdated = (heroes: AthanorHero[]): void => {
    this.lastHeroes = heroes;
    this.bootstrapExpeditions(heroes);
    this.syncHeroes(heroes);
    this.updatePortalExploringStates(heroes);
  };

  private readonly onCraftResult = (payload: CraftResultPayload): void => {
    if (!this.eventEffect) return;
    this.cauldron?.playBrewReaction();
    if (payload.isSoup) {
      this.eventEffect.playCraftGold(payload.goldEarned);
      this.tryPlaySound('brew-success', 0.4);
    } else {
      this.eventEffect.playCraftSuccess();
      this.tryPlaySound('brew-success', 0.4);
    }
  };

  private readonly onExplorationEvent = (payload: ExplorationEventPayload): void => {
    if (!this.eventEffect) return;

    if (payload.zoneId != null) {
      const expedition = this.heroExpeditions.get(payload.heroId);
      if (expedition) {
        expedition.lastKnownZone = payload.zoneId;
      }
      this.syncHeroes(this.lastHeroes);
      this.updatePortalExploringStates(this.lastHeroes);
    }

    const sprite = this.heroSprites.get(payload.heroId);
    const x = sprite?.x ?? this.scale.width / 2;
    const y = sprite?.y ?? this.scale.height * 0.5;

    const portalIdx = payload.zoneId ?? this.getExploringPortalIndex(payload.heroId);
    const portal = this.portals[portalIdx];
    if (portal) {
      portal.pulseEvent(this.getEventColor(payload.kind));
    }

    switch (payload.kind) {
      case 'trap':
        this.eventEffect.playTrap(x, y, sprite ?? undefined);
        this.eventEffect.floatingText(x, y - 20, `-${payload.value} HP`, '#d04050');
        this.tryPlaySound('trap', 0.5);
        break;
      case 'gold':
        this.eventEffect.playGold(x, y, payload.value);
        this.tryPlaySound('gold-find', 0.5);
        break;
      case 'heal':
        this.eventEffect.playHeal(x, y, sprite ?? undefined);
        this.eventEffect.floatingText(x, y - 20, `+${payload.value} HP`, '#40c060');
        this.tryPlaySound('heal', 0.5);
        break;
      case 'beastWin':
        this.eventEffect.playBeastWin(x, y, sprite ?? undefined);
        this.tryPlaySound('beast-win', 0.5);
        break;
      case 'beastLose':
        this.eventEffect.playBeastLose(x, y, sprite ?? undefined);
        this.eventEffect.floatingText(x, y - 20, `-${payload.value} HP`, '#d04050');
        this.tryPlaySound('beast-lose', 0.5);
        break;
      case 'ingredient':
        this.eventEffect.playIngredientDrop(x, y, sprite ?? undefined);
        this.eventEffect.floatingText(x, y - 20, '+1 Ingredient', '#a050d0');
        this.tryPlaySound('gold-find', 0.3);
        break;
    }
  };

  private readonly onExpeditionStart = (payload: { heroId: number }): void => {
    this.heroExpeditions.set(payload.heroId, {
      startTime: Math.floor(Date.now() / 1000),
      lastKnownZone: 0,
    });

    if (!this.eventEffect) return;
    const sprite = this.heroSprites.get(payload.heroId);
    const x = sprite?.x ?? this.scale.width / 2;
    const y = sprite?.y ?? this.scale.height * 0.8;
    this.eventEffect.playExpeditionStart(x, y);
    this.tryPlaySound('expedition-start', 0.5);
  };

  private readonly onClaimLoot = (payload: { heroId: number; gold: number }): void => {
    if (!this.eventEffect) return;
    const sprite = this.heroSprites.get(payload.heroId);
    const x = sprite?.x ?? this.scale.width / 2;
    const y = sprite?.y ?? this.scale.height * 0.8;
    this.eventEffect.playClaimLoot(x, y, payload.gold);
    this.tryPlaySound('claim-loot', 0.5);
  };

  private readonly onRecruit = (): void => {
    this.eventEffect?.playRecruitEffect();
    this.tryPlaySound('recruit', 0.6);
  };

  private readonly onBuff = (payload: { heroId: number; effectIdx: number }): void => {
    if (!this.eventEffect) return;
    const sprite = this.heroSprites.get(payload.heroId);
    const x = sprite?.x ?? this.scale.width / 2;
    const y = sprite?.y ?? this.scale.height * 0.8;
    const category = payload.effectIdx < 10 ? 'health' : payload.effectIdx < 20 ? 'power' : 'regen';
    const tint = EFFECT_TINTS[category] ?? COLORS.green;
    this.eventEffect.playBuffEffect(x, y, tint);
    this.tryPlaySound('potion-apply', 0.5);
  };

  private readonly onHintReveal = (): void => {
    this.eventEffect?.playHintRevealEffect();
    this.tryPlaySound('notification', 0.4);
  };

  private readonly onUiClick = (): void => {
    this.tryPlaySound('click', 0.25);
  };

  private readonly onDiscovery = (): void => {
    if (!this.eventEffect) return;
    this.cauldron?.playDiscoveryReaction();
    this.eventEffect.playDiscovery();
    this.tryPlaySound('discovery', 0.6);
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

    this.createLabScene();

    this.heroContainer = this.add.container(0, 0);
    this.heroContainer.setDepth(12);

    this.input.mouse?.disableContextMenu();
    this.sound.pauseOnBlur = false;

    this.bridge.on('heroesUpdated', this.onHeroesUpdated);
    this.bridge.on('craftResult', this.onCraftResult);
    this.bridge.on('discovery', this.onDiscovery);
    this.bridge.on('gameOver', this.onGameOver);
    this.bridge.on('explorationEvent', this.onExplorationEvent);
    this.bridge.on('expeditionStart', this.onExpeditionStart);
    this.bridge.on('claimLoot', this.onClaimLoot);
    this.bridge.on('recruit', this.onRecruit);
    this.bridge.on('buff', this.onBuff);
    this.bridge.on('hintReveal', this.onHintReveal);
    this.bridge.on('uiClick', this.onUiClick);

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

    this.startAmbientLoop();

    this.events.once(Phaser.Scenes.Events.SHUTDOWN, this.shutdown, this);
  }

  update(_time: number, _delta: number): void { /* noop */ }

  private createLabScene(): void {
    const layout = computePortalLayout(this.scale.width, this.scale.height);

    this.energyLinesGfx = this.add.graphics();
    this.energyLinesGfx.setDepth(3);

    this.cauldron = new Cauldron(this, layout.cauldronX, layout.cauldronY);
    this.cauldron.setDepth(6);

    for (let i = 0; i < PORTAL_COUNT; i++) {
      const pos = layout.portalPositions[i];
      const portal = new ZonePortal(this, i, pos.x, pos.y);
      portal.setDepth(5);
      this.portals.push(portal);
    }

    this.drawEnergyLines(layout);
  }

  private drawEnergyLines(layout: ReturnType<typeof computePortalLayout>): void {
    const g = this.energyLinesGfx;
    if (!g) return;
    g.clear();

    const positions = layout.portalPositions;
    let prevX = layout.cauldronX;
    let prevY = layout.cauldronY - 35;

    for (let i = 0; i < positions.length; i++) {
      const tint = ZONE_TINTS[i] ?? COLORS.white;
      g.lineStyle(ENERGY_LINE_WIDTH, tint, ENERGY_LINE_ALPHA);
      g.lineBetween(prevX, prevY, positions[i].x, positions[i].y);
      prevX = positions[i].x;
      prevY = positions[i].y;
    }
  }

  private onResize(gameSize: Phaser.Structs.Size): void {
    const w = gameSize.width;
    const h = gameSize.height;

    this.zoneBackground?.resize(w, h);
    this.repositionLabScene(w, h);
    this.repositionHeroes();
  }

  private repositionLabScene(w: number, h: number): void {
    const layout = computePortalLayout(w, h);

    this.cauldron?.setPosition(layout.cauldronX, layout.cauldronY);

    for (let i = 0; i < this.portals.length; i++) {
      const pos = layout.portalPositions[i];
      this.portals[i].reposition(pos.x, pos.y);
    }

    this.drawEnergyLines(layout);
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

  private updatePortalExploringStates(heroes: AthanorHero[]): void {
    const now = Math.floor(Date.now() / 1000);
    const activePortals = new Set<number>();

    for (const hero of heroes) {
      if (hero.available_at > now && hero.health > 0) {
        const phase = this.getExpeditionPhase(hero);
        if (!phase.returning) {
          activePortals.add(phase.portalIndex);
        }
      }
    }

    for (let i = 0; i < this.portals.length; i++) {
      this.portals[i].setExploring(activePortals.has(i));
    }
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

  private startAmbientLoop(): void {
    if (!this.cache.audio.exists('ambient-lab')) return;
    const { sfxVolume } = getSettingsSnapshot();
    this.ambientSound = this.sound.add('ambient-lab', { loop: true, volume: 0.15 * sfxVolume });
    this.ambientSound.play();
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
    const isExploring = hero.available_at > now && hero.health > 0;
    const layout = computePortalLayout(this.scale.width, this.scale.height);

    if (isExploring) {
      const phase = this.getExpeditionPhase(hero);

      if (phase.returning) {
        const spacing = 70;
        const totalWidth = (heroCount - 1) * spacing;
        const startX = layout.heroIdleX - totalWidth / 2;
        return {
          x: startX + heroIndex * spacing,
          y: layout.heroIdleY,
        };
      }

      const portal = this.portals[phase.portalIndex];
      if (portal) {
        const anchor = portal.getHeroAnchor();
        const offset = this.getHeroPortalOffset(heroIndex, heroCount);
        return { x: anchor.x + offset.x, y: anchor.y + portal.portalRadius + 18 + offset.y };
      }
    }

    this.heroExpeditions.delete(hero.hero_id);

    const spacing = 70;
    const totalWidth = (heroCount - 1) * spacing;
    const startX = layout.heroIdleX - totalWidth / 2;
    return {
      x: startX + heroIndex * spacing,
      y: layout.heroIdleY,
    };
  }

  private getHeroPortalOffset(heroIndex: number, heroCount: number): { x: number; y: number } {
    if (heroCount <= 1) return { x: 0, y: 0 };
    const spacing = 40;
    const totalWidth = (heroCount - 1) * spacing;
    const offsetX = -totalWidth / 2 + heroIndex * spacing;
    return { x: offsetX, y: Math.abs(offsetX) * 0.15 };
  }

  private getExpeditionPhase(hero: AthanorHero): { portalIndex: number; returning: boolean } {
    const now = Math.floor(Date.now() / 1000);
    const expedition = this.heroExpeditions.get(hero.hero_id);

    if (expedition) {
      const totalTime = hero.available_at - expedition.startTime;
      const forwardTime = Math.floor(totalTime * 2 / 3);
      const elapsed = now - expedition.startTime;

      if (elapsed >= forwardTime) {
        return { portalIndex: expedition.lastKnownZone, returning: true };
      }

      const currentDepth = Math.min(elapsed, forwardTime);
      const computedZone = getZoneForDepth(currentDepth);
      return { portalIndex: Math.max(computedZone, expedition.lastKnownZone), returning: false };
    }

    return this.estimateExpeditionPhase(hero, now);
  }

  private estimateExpeditionPhase(hero: AthanorHero, now: number): { portalIndex: number; returning: boolean } {
    const remaining = hero.available_at - now;
    const maxDepth = ZONE_DEPTHS[ZONE_DEPTHS.length - 1];
    const maxExpeditionTime = Math.floor(3 * maxDepth / 2);

    if (remaining <= 0) return { portalIndex: 0, returning: true };

    const estimatedTotal = Math.min(remaining * 3, maxExpeditionTime * 3);
    const estimatedForward = Math.floor(estimatedTotal * 2 / 3);
    const estimatedElapsed = estimatedTotal - remaining;

    if (estimatedElapsed >= estimatedForward) {
      return { portalIndex: 4, returning: true };
    }

    const depth = Math.min(estimatedElapsed, estimatedForward);
    return { portalIndex: getZoneForDepth(depth), returning: false };
  }

  private bootstrapExpeditions(heroes: AthanorHero[]): void {
    const now = Math.floor(Date.now() / 1000);
    const activeHeroes = new Set<number>();

    for (const hero of heroes) {
      const isExploring = hero.available_at > now && hero.health > 0;
      if (isExploring) {
        activeHeroes.add(hero.hero_id);
        if (!this.heroExpeditions.has(hero.hero_id)) {
          this.heroExpeditions.set(hero.hero_id, {
            startTime: now,
            lastKnownZone: 0,
          });
        }
      }
    }

    for (const heroId of this.heroExpeditions.keys()) {
      if (!activeHeroes.has(heroId)) {
        this.heroExpeditions.delete(heroId);
      }
    }
  }

  private getExploringPortalIndex(heroId: number): number {
    const hero = this.lastHeroes.find((h) => h.hero_id === heroId);
    if (!hero) return 0;
    const phase = this.getExpeditionPhase(hero);
    return phase.portalIndex;
  }

  private getEventColor(kind: ExplorationEventPayload['kind']): number {
    switch (kind) {
      case 'trap': return COLORS.red;
      case 'gold': return COLORS.gold;
      case 'heal': return COLORS.green;
      case 'beastWin': return COLORS.green;
      case 'beastLose': return COLORS.red;
      case 'ingredient': return COLORS.purple;
    }
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
      this.bridge.off('discovery', this.onDiscovery);
      this.bridge.off('gameOver', this.onGameOver);
      this.bridge.off('explorationEvent', this.onExplorationEvent);
      this.bridge.off('expeditionStart', this.onExpeditionStart);
      this.bridge.off('claimLoot', this.onClaimLoot);
      this.bridge.off('recruit', this.onRecruit);
      this.bridge.off('buff', this.onBuff);
      this.bridge.off('hintReveal', this.onHintReveal);
      this.bridge.off('uiClick', this.onUiClick);
    }

    this.input.off(Phaser.Input.Events.POINTER_DOWN, this.onFirstInteractionMusic);
    this.sound.off(Phaser.Sound.Events.UNLOCKED, this.startMusicPlaylist, this);

    this.currentMusicSound?.off(Phaser.Sound.Events.COMPLETE, this.onMusicComplete, this);
    this.currentMusicSound?.stop();
    this.currentMusicSound?.destroy();
    this.currentMusicSound = null;

    this.ambientSound?.stop();
    this.ambientSound?.destroy();
    this.ambientSound = null;

    for (const sprite of this.heroSprites.values()) sprite.destroy();
    this.heroSprites.clear();
    this.heroExpeditions.clear();

    for (const portal of this.portals) portal.destroy();
    this.portals = [];

    this.cauldron?.destroy();
    this.cauldron = null;

    this.energyLinesGfx?.destroy();
    this.energyLinesGfx = null;

    this.zoneBackground?.destroy();
    this.zoneBackground = null;
    this.eventEffect = null;
  }
}
