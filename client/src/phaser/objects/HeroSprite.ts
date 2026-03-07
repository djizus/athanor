import Phaser from 'phaser';
import { ROLE_NAMES } from '@/game/constants';
import type { AthanorHero } from '../PhaserBridge';
import { PhaserBridge } from '../PhaserBridge';
import { COLORS } from '../utils/colors';
import { FONTS } from '../utils/layout';
import type { EventEffect } from './EventEffect';

const HERO_TINTS = [0x4080d0, 0x40c060, 0xa050d0];
const HERO_PORTRAIT_KEYS = ['role-mage', 'role-rogue', 'role-warrior'];
const PORTRAIT_RADIUS = 26;
const PORTRAIT_Y = 0;
const HP_RING_RADIUS = 29;
const HP_RING_WIDTH = 3;
const SELECTION_RING_RADIUS = 33;
const EXPLORING_SCALE = 0.72;
const IDLE_SCALE = 1.0;
const FLIGHT_DURATION = 600;

function deriveStatus(availableAt: number): number {
  const now = Math.floor(Date.now() / 1000);
  return availableAt > now ? 1 : 0;
}

const STATUS_IDLE = 0;

export class HeroSprite extends Phaser.GameObjects.Container {
  private readonly sceneRef: Phaser.Scene;
  private baseX: number;
  private baseY: number;
  private readonly heroTint: number;
  readonly eventEffect: EventEffect;

  private readonly aura: Phaser.GameObjects.Arc;
  private readonly hpRingGfx: Phaser.GameObjects.Graphics;
  private readonly selectionRing: Phaser.GameObjects.Arc;
  private readonly trailEmitter: Phaser.GameObjects.Particles.ParticleEmitter;
  private readonly bridge: PhaserBridge | null;
  private heroId: number;

  private bobTween: Phaser.Tweens.Tween;
  private auraTween: Phaser.Tweens.Tween | null = null;
  private moveTween: Phaser.Tweens.Tween | null = null;
  private ringTween: Phaser.Tweens.Tween | null = null;

  private lastStatus = -1;
  private lastHpRatio = -1;
  private lastTargetX = -1;
  private lastTargetY = -1;
  private lastDefeated = false;
  private maskGfx: Phaser.GameObjects.Graphics | null = null;
  private isSelected = false;
  private scaleTween: Phaser.Tweens.Tween | null = null;

  private readonly onHeroSelected = (selectedHeroId: number): void => {
    this.updateSelection(selectedHeroId === this.heroId);
  };

  constructor(
    scene: Phaser.Scene,
    hero: AthanorHero,
    heroIndex: number,
    baseX: number,
    baseY: number,
    eventEffect: EventEffect,
  ) {
    super(scene, baseX, baseY);
    this.sceneRef = scene;
    this.baseX = baseX;
    this.baseY = baseY;
    this.heroId = hero.hero_id;
    this.heroTint = HERO_TINTS[heroIndex] ?? COLORS.white;
    this.eventEffect = eventEffect;
    const bridgeFromRegistry = scene.registry.get('bridge');
    this.bridge = bridgeFromRegistry instanceof PhaserBridge ? bridgeFromRegistry : null;

    this.aura = scene.add.circle(0, PORTRAIT_Y, SELECTION_RING_RADIUS + 4, COLORS.white, 0.08);
    this.aura.setBlendMode(Phaser.BlendModes.ADD);

    this.selectionRing = scene.add.circle(0, PORTRAIT_Y, SELECTION_RING_RADIUS);
    this.selectionRing.setStrokeStyle(3, COLORS.gold, 0.95);
    this.selectionRing.setFillStyle(0x000000, 0);
    this.selectionRing.setVisible(false);

    this.hpRingGfx = scene.add.graphics();

    const roleIdx = hero.role > 0 ? hero.role - 1 : heroIndex;
    const portraitKey = HERO_PORTRAIT_KEYS[roleIdx];
    const hasPortrait = portraitKey && scene.textures.exists(portraitKey);
    const bodyParts: Phaser.GameObjects.GameObject[] = [];

    if (hasPortrait) {
      // Solid backing circle provides contrast on the transparent canvas
      const backing = scene.add.circle(0, PORTRAIT_Y, PORTRAIT_RADIUS + 1, COLORS.bgCard, 1);
      bodyParts.push(backing);

      const portrait = scene.add.image(0, PORTRAIT_Y, portraitKey);
      portrait.setDisplaySize(PORTRAIT_RADIUS * 2, PORTRAIT_RADIUS * 2);
      portrait.setOrigin(0.5, 0.5);
      const mask = scene.make.graphics({ x: 0, y: 0 });
      mask.fillCircle(0, 0, PORTRAIT_RADIUS);
      portrait.setMask(new Phaser.Display.Masks.GeometryMask(scene, mask));
      this.maskGfx = mask;
      this.sceneRef.events.on(Phaser.Scenes.Events.PRE_UPDATE, this.updateMaskPos, this);
      bodyParts.push(portrait);
    } else {
      const head = scene.add.circle(0, PORTRAIT_Y, PORTRAIT_RADIUS, this.heroTint, 1);
      bodyParts.push(head);
    }

    const name = ROLE_NAMES[roleIdx] ?? `Hero ${heroIndex}`;
    const label = scene.add.text(0, PORTRAIT_RADIUS + 8, name, FONTS.bodySmall);
    label.setOrigin(0.5, 0);

    this.add([this.aura, this.selectionRing, this.hpRingGfx, ...bodyParts, label]);
    scene.add.existing(this);

    this.setInteractive(new Phaser.Geom.Circle(0, PORTRAIT_Y, SELECTION_RING_RADIUS), Phaser.Geom.Circle.Contains);
    this.on(Phaser.Input.Events.POINTER_DOWN, () => {
      this.bridge?.selectHero(this.heroId);
    });

    this.bobTween = scene.tweens.add({
      targets: this,
      y: baseY - 3,
      yoyo: true,
      repeat: -1,
      duration: 1000,
      ease: 'Sine.InOut',
    });

    this.trailEmitter = scene.add.particles(0, 0, 'particle-generic', {
      lifespan: 500,
      speed: { min: 8, max: 24 },
      frequency: 90,
      quantity: 1,
      scale: { start: 0.65, end: 0 },
      alpha: { start: 0.6, end: 0 },
      tint: this.heroTint,
      blendMode: Phaser.BlendModes.ADD,
      emitting: false,
    });
    this.trailEmitter.startFollow(this, -18, 14);

    this.bridge?.on('heroSelected', this.onHeroSelected);
    this.updateSelection(this.bridge?.selectedHeroId === this.heroId);

    this.syncToHero(hero);
  }

  private readonly updateMaskPos = (): void => {
    if (this.maskGfx) this.maskGfx.setPosition(this.x, this.y + PORTRAIT_Y);
  };

  syncToHero(hero: AthanorHero): void {
    this.heroId = hero.hero_id;
    const hpRatio = hero.max_health > 0 ? Phaser.Math.Clamp(hero.health / hero.max_health, 0, 1) : 0;
    const defeated = hero.health <= 0;
    const status = deriveStatus(hero.available_at);

    if (Math.abs(hpRatio - this.lastHpRatio) > 0.001) {
      this.drawHpRing(hpRatio);
      this.lastHpRatio = hpRatio;
    }

    if (defeated && !this.lastDefeated) {
      this.stopAuras();
      this.trailEmitter.stop();
      if (!this.bobTween.isPaused()) this.bobTween.pause();
      this.moveTween?.stop();
      this.moveTween = null;
      this.setPosition(this.baseX, this.baseY);
      this.setAlpha(0.3);
      this.lastDefeated = true;
      this.lastStatus = status;
      this.lastTargetX = this.baseX;
      this.lastTargetY = this.baseY;
      return;
    }

    if (!defeated && this.lastDefeated) {
      this.setAlpha(1);
      this.lastDefeated = false;
    }
    if (defeated) return;

    if (status !== this.lastStatus) {
      this.setAlpha(1);

      if (status === STATUS_IDLE) {
        if (this.bobTween.isPaused()) this.bobTween.resume();
        this.trailEmitter.stop();
        this.configureAura(COLORS.white, 0.08, 1.06, 1400);
        this.animateScaleTo(IDLE_SCALE);
      } else {
        if (!this.bobTween.isPaused()) this.bobTween.pause();
        this.y = this.baseY;
        this.trailEmitter.start();
        this.configureAura(COLORS.blue, 0.2, 1.18, 1000);
        this.animateScaleTo(EXPLORING_SCALE);
      }
      this.lastStatus = status;
    }

    const targetX = this.baseX;
    const targetY = this.baseY;
    const dx = Math.abs(targetX - this.lastTargetX);
    const dy = Math.abs(targetY - this.lastTargetY);

    if (dx > 1 || dy > 1) {
      this.moveTween?.stop();
      const distance = Math.sqrt(dx * dx + dy * dy);
      const duration = Math.min(FLIGHT_DURATION, Math.max(250, distance * 1.5));
      this.moveTween = this.sceneRef.tweens.add({
        targets: this,
        x: targetX,
        y: targetY,
        duration,
        ease: 'Cubic.Out',
      });
      this.lastTargetX = targetX;
      this.lastTargetY = targetY;
    }
  }

  setBasePosition(bx: number, by: number): void {
    this.baseX = bx;
    this.baseY = by;
  }

  override destroy(fromScene?: boolean): void {
    this.sceneRef.events.off(Phaser.Scenes.Events.PRE_UPDATE, this.updateMaskPos, this);
    this.bridge?.off('heroSelected', this.onHeroSelected);
    this.maskGfx?.destroy();
    this.bobTween.stop();
    this.stopAuras();
    this.moveTween?.stop();
    this.scaleTween?.stop();
    this.ringTween?.stop();
    this.trailEmitter.destroy();
    super.destroy(fromScene);
  }

  private drawHpRing(hpRatio: number): void {
    const g = this.hpRingGfx;
    g.clear();

    g.lineStyle(HP_RING_WIDTH, 0x000000, 0.4);
    g.beginPath();
    g.arc(0, PORTRAIT_Y, HP_RING_RADIUS, 0, Math.PI * 2);
    g.strokePath();

    if (hpRatio > 0.001) {
      const color = hpRatio > 0.3 ? COLORS.hpGreen : COLORS.hpRed;
      const startAngle = -Math.PI / 2;
      const endAngle = startAngle + hpRatio * Math.PI * 2;
      g.lineStyle(HP_RING_WIDTH, color, 0.9);
      g.beginPath();
      g.arc(0, PORTRAIT_Y, HP_RING_RADIUS, startAngle, endAngle);
      g.strokePath();
    }
  }

  private configureAura(color: number, alpha: number, scale: number, duration: number): void {
    this.aura.setVisible(true);
    this.aura.setFillStyle(color, alpha);
    this.auraTween?.stop();
    this.aura.setScale(1);
    this.auraTween = this.sceneRef.tweens.add({
      targets: this.aura,
      scale,
      alpha: alpha * 0.45,
      yoyo: true,
      repeat: -1,
      duration,
      ease: 'Sine.InOut',
    });
  }

  private animateScaleTo(target: number): void {
    this.scaleTween?.stop();
    this.scaleTween = this.sceneRef.tweens.add({
      targets: this,
      scaleX: target,
      scaleY: target,
      duration: 350,
      ease: 'Sine.InOut',
    });
  }

  private stopAuras(): void {
    this.auraTween?.stop();
    this.auraTween = null;
    this.aura.setVisible(false);
  }

  private updateSelection(selected: boolean): void {
    if (this.isSelected === selected) return;
    this.isSelected = selected;
    this.selectionRing.setVisible(selected);

    this.ringTween?.stop();
    this.ringTween = null;

    if (!selected) {
      this.selectionRing.setAlpha(1);
      this.selectionRing.setScale(1);
      this.selectionRing.setAngle(0);
      return;
    }

    this.ringTween = this.sceneRef.tweens.add({
      targets: this.selectionRing,
      alpha: 0.45,
      scale: 1.08,
      angle: 360,
      duration: 900,
      ease: 'Sine.InOut',
      yoyo: true,
      repeat: -1,
    });
  }
}
