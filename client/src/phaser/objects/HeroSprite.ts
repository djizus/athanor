import Phaser from 'phaser';
import { HERO_NAMES } from '@/game/constants';
import type { AthanorHero } from '../PhaserBridge';
import { COLORS } from '../utils/colors';
import { FONTS } from '../utils/layout';
import type { EventEffect } from './EventEffect';

const HERO_TINTS = [0x4080d0, 0x40c060, 0xa050d0];
const HERO_PORTRAIT_KEYS = ['hero-alaric', 'hero-brynn', 'hero-cassiel'];
const PORTRAIT_SIZE = 48;
const EXPLORE_RANGE = 220;
const HP_BAR_WIDTH = 40;

const STATUS_IDLE = 0;
const STATUS_EXPLORING = 1;

export class HeroSprite extends Phaser.GameObjects.Container {
  private readonly sceneRef: Phaser.Scene;
  private baseX: number;
  private baseY: number;
  private readonly heroTint: number;
  readonly eventEffect: EventEffect;

  private readonly aura: Phaser.GameObjects.Arc;
  private readonly hpFill: Phaser.GameObjects.Rectangle;
  private readonly trailEmitter: Phaser.GameObjects.Particles.ParticleEmitter;

  private bobTween: Phaser.Tweens.Tween;
  private auraTween: Phaser.Tweens.Tween | null = null;
  private hpTween: Phaser.Tweens.Tween | null = null;
  private moveTween: Phaser.Tweens.Tween | null = null;

  private lastStatus = -1;
  private lastHpRatio = -1;
  private lastTargetX = -1;
  private lastDefeated = false;
  private maskGfx: Phaser.GameObjects.Graphics | null = null;

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
    this.heroTint = HERO_TINTS[heroIndex] ?? COLORS.white;
    this.eventEffect = eventEffect;

    this.aura = scene.add.circle(0, 6, 36, COLORS.white, 0.08);
    this.aura.setBlendMode(Phaser.BlendModes.ADD);

    const hpBg = scene.add.rectangle(-HP_BAR_WIDTH / 2, -44, HP_BAR_WIDTH, 4, COLORS.black, 0.6);
    hpBg.setOrigin(0, 0.5);
    hpBg.setStrokeStyle(1, 0xffffff, 0.2);

    this.hpFill = scene.add.rectangle(-HP_BAR_WIDTH / 2, -44, HP_BAR_WIDTH, 4, COLORS.hpGreen, 1);
    this.hpFill.setOrigin(0, 0.5);

    const portraitKey = HERO_PORTRAIT_KEYS[heroIndex];
    const hasPortrait = portraitKey && scene.textures.exists(portraitKey);
    const bodyParts: Phaser.GameObjects.GameObject[] = [];

    if (hasPortrait) {
      const portrait = scene.add.image(0, 8, portraitKey);
      portrait.setDisplaySize(PORTRAIT_SIZE, PORTRAIT_SIZE);
      portrait.setOrigin(0.5, 0.5);
      const mask = scene.make.graphics({ x: 0, y: 0 });
      mask.fillCircle(0, 0, PORTRAIT_SIZE / 2);
      portrait.setMask(new Phaser.Display.Masks.GeometryMask(scene, mask));
      this.maskGfx = mask;
      this.sceneRef.events.on(Phaser.Scenes.Events.PRE_UPDATE, this.updateMaskPos, this);
      bodyParts.push(portrait);
    } else {
      const head = scene.add.circle(0, -4, 24, this.heroTint, 1);
      const body = scene.add.triangle(0, 32, -16, -8, 16, -8, 0, 26, this.heroTint, 0.9);
      bodyParts.push(body, head);
    }

    const name = HERO_NAMES[heroIndex] ?? `Hero ${heroIndex}`;
    const label = scene.add.text(0, 60, name, FONTS.bodySmall);
    label.setOrigin(0.5, 0);

    this.add([this.aura, hpBg, this.hpFill, ...bodyParts, label]);
    scene.add.existing(this);

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

    this.syncToHero(hero);
  }

  private readonly updateMaskPos = (): void => {
    if (this.maskGfx) this.maskGfx.setPosition(this.x, this.y + 8);
  };

  syncToHero(hero: AthanorHero): void {
    const hpRatio = hero.max_hp > 0 ? Phaser.Math.Clamp(hero.hp / hero.max_hp, 0, 1) : 0;
    const defeated = hero.hp <= 0;
    const targetX = this.getTargetX(hero);

    if (Math.abs(hpRatio - this.lastHpRatio) > 0.001) {
      this.updateHpBar(hpRatio);
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
      this.lastStatus = hero.status;
      this.lastTargetX = this.baseX;
      return;
    }

    if (!defeated && this.lastDefeated) {
      this.setAlpha(1);
      this.lastDefeated = false;
    }
    if (defeated) return;

    if (hero.status !== this.lastStatus) {
      this.setAlpha(1);

      if (hero.status === STATUS_IDLE) {
        if (this.bobTween.isPaused()) this.bobTween.resume();
        this.trailEmitter.stop();
        this.configureAura(COLORS.white, 0.08, 1.06, 1400);
      } else {
        if (!this.bobTween.isPaused()) this.bobTween.pause();
        this.y = this.baseY;

        if (hero.status === STATUS_EXPLORING) {
          this.trailEmitter.start();
          this.configureAura(COLORS.blue, 0.2, 1.18, 1000);
        } else {
          this.trailEmitter.stop();
          this.configureAura(COLORS.gold, 0.24, 1.2, 900);
        }
      }
      this.lastStatus = hero.status;
    }

    if (Math.abs(targetX - this.lastTargetX) > 1) {
      this.moveTween?.stop();
      this.moveTween = this.sceneRef.tweens.add({
        targets: this,
        x: targetX,
        duration: 250,
        ease: 'Sine.Out',
      });
      this.lastTargetX = targetX;
    }
  }

  setBasePosition(bx: number, by: number): void {
    this.baseX = bx;
    this.baseY = by;
  }

  override destroy(fromScene?: boolean): void {
    this.sceneRef.events.off(Phaser.Scenes.Events.PRE_UPDATE, this.updateMaskPos, this);
    this.maskGfx?.destroy();
    this.bobTween.stop();
    this.stopAuras();
    this.hpTween?.stop();
    this.moveTween?.stop();
    this.trailEmitter.destroy();
    super.destroy(fromScene);
  }

  private getTargetX(hero: AthanorHero): number {
    if (hero.status === STATUS_EXPLORING) {
      return this.baseX + Math.min(EXPLORE_RANGE, hero.death_depth * 5);
    }
    return this.baseX;
  }

  private updateHpBar(hpRatio: number): void {
    this.hpFill.setFillStyle(hpRatio > 0.3 ? COLORS.hpGreen : COLORS.hpRed, 1);
    this.hpTween?.stop();
    this.hpTween = this.sceneRef.tweens.add({
      targets: this.hpFill,
      scaleX: hpRatio,
      duration: 220,
      ease: 'Sine.Out',
    });
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

  private stopAuras(): void {
    this.auraTween?.stop();
    this.auraTween = null;
    this.aura.setVisible(false);
  }
}
