import Phaser from 'phaser';
import { FONTS } from '../utils/layout';

function randomZone(geom: Phaser.Geom.Rectangle | Phaser.Geom.Circle): Phaser.GameObjects.Particles.Zones.RandomZone {
  return new Phaser.GameObjects.Particles.Zones.RandomZone(
    geom as unknown as Phaser.Types.GameObjects.Particles.RandomZoneSource,
  );
}

const BODY_WIDTH = 100;
const BODY_HEIGHT = 70;
const RIM_WIDTH = 120;
const RIM_HEIGHT = 16;
const LEG_WIDTH = 8;
const LEG_HEIGHT = 18;

const BODY_COLOR = 0x2a2a3a;
const RIM_COLOR = 0x4a4a5a;
const LEG_COLOR = 0x3a3a4a;
const LIQUID_COLOR = 0x6030a0;
const GLOW_COLOR = 0x8040d0;

export class Cauldron extends Phaser.GameObjects.Container {
  private readonly gfx: Phaser.GameObjects.Graphics;
  private readonly glowCircle: Phaser.GameObjects.Arc;
  private readonly bubbleEmitter: Phaser.GameObjects.Particles.ParticleEmitter;
  private readonly steamEmitter: Phaser.GameObjects.Particles.ParticleEmitter;
  private readonly label: Phaser.GameObjects.Text;
  private glowTween: Phaser.Tweens.Tween;
  private brewBurstActive = false;

  constructor(scene: Phaser.Scene, x: number, y: number) {
    super(scene, x, y);

    this.glowCircle = scene.add.circle(0, -BODY_HEIGHT * 0.2, BODY_WIDTH * 0.7, GLOW_COLOR, 0.08);
    this.glowCircle.setBlendMode(Phaser.BlendModes.ADD);

    this.gfx = scene.add.graphics();
    this.drawCauldron();

    this.label = scene.add.text(0, LEG_HEIGHT + 14, 'The Athanor', {
      ...FONTS.title,
      fontSize: '15px',
    });
    this.label.setOrigin(0.5, 0);

    this.bubbleEmitter = scene.add.particles(0, -BODY_HEIGHT * 0.55, 'particle-arcane', {
      quantity: 1,
      frequency: 180,
      lifespan: 1200,
      speedY: { min: -40, max: -18 },
      speedX: { min: -20, max: 20 },
      scale: { start: 0.5, end: 0 },
      alpha: { start: 0.7, end: 0 },
      tint: [LIQUID_COLOR, GLOW_COLOR, 0xce95ff],
      blendMode: Phaser.BlendModes.ADD,
      emitZone: randomZone(new Phaser.Geom.Rectangle(-BODY_WIDTH * 0.3, -4, BODY_WIDTH * 0.6, 8)),
    });

    this.steamEmitter = scene.add.particles(0, -BODY_HEIGHT * 0.7, 'particle-smoke', {
      quantity: 1,
      frequency: 350,
      lifespan: 2000,
      speedY: { min: -25, max: -10 },
      speedX: { min: -12, max: 12 },
      scale: { start: 0.4, end: 1.0 },
      alpha: { start: 0.12, end: 0 },
      blendMode: Phaser.BlendModes.ADD,
      emitZone: randomZone(new Phaser.Geom.Rectangle(-BODY_WIDTH * 0.25, -2, BODY_WIDTH * 0.5, 4)),
    });

    this.add([this.glowCircle, this.gfx, this.bubbleEmitter, this.steamEmitter, this.label]);
    scene.add.existing(this);

    this.glowTween = scene.tweens.add({
      targets: this.glowCircle,
      alpha: 0.15,
      scale: 1.12,
      yoyo: true,
      repeat: -1,
      duration: 2000,
      ease: 'Sine.InOut',
    });
  }

  playBrewReaction(): void {
    if (this.brewBurstActive) return;
    this.brewBurstActive = true;

    const prevFreq = this.bubbleEmitter.frequency;
    this.bubbleEmitter.setFrequency(40);

    this.scene.tweens.add({
      targets: this.glowCircle,
      alpha: 0.35,
      scale: 1.3,
      duration: 300,
      yoyo: true,
      ease: 'Sine.Out',
      onComplete: () => {
        this.bubbleEmitter.setFrequency(prevFreq);
        this.brewBurstActive = false;
      },
    });
  }

  playDiscoveryReaction(): void {
    this.bubbleEmitter.setFrequency(25);
    this.scene.time.delayedCall(1200, () => this.bubbleEmitter.setFrequency(180));

    this.scene.tweens.add({
      targets: this.glowCircle,
      alpha: 0.5,
      scale: 1.5,
      duration: 400,
      yoyo: true,
      ease: 'Sine.Out',
    });
  }

  override destroy(fromScene?: boolean): void {
    this.glowTween.stop();
    this.bubbleEmitter.destroy();
    this.steamEmitter.destroy();
    this.gfx.destroy();
    super.destroy(fromScene);
  }

  private drawCauldron(): void {
    const g = this.gfx;
    g.clear();

    const legSpread = BODY_WIDTH * 0.35;
    g.fillStyle(LEG_COLOR, 0.9);
    g.fillRect(-legSpread - LEG_WIDTH / 2, 0, LEG_WIDTH, LEG_HEIGHT);
    g.fillRect(legSpread - LEG_WIDTH / 2, 0, LEG_WIDTH, LEG_HEIGHT);

    const bx = -BODY_WIDTH / 2;
    const by = -BODY_HEIGHT;
    g.fillStyle(BODY_COLOR, 0.95);
    g.fillRoundedRect(bx, by, BODY_WIDTH, BODY_HEIGHT, { tl: 8, tr: 8, bl: 20, br: 20 });

    g.fillStyle(BODY_COLOR, 0.3);
    g.fillEllipse(0, -BODY_HEIGHT + 4, BODY_WIDTH - 4, 14);

    g.fillStyle(LIQUID_COLOR, 0.5);
    g.fillEllipse(0, -BODY_HEIGHT * 0.55, BODY_WIDTH * 0.7, 18);

    const rx = -RIM_WIDTH / 2;
    const ry = -BODY_HEIGHT - RIM_HEIGHT * 0.4;
    g.fillStyle(RIM_COLOR, 1);
    g.fillRoundedRect(rx, ry, RIM_WIDTH, RIM_HEIGHT, 6);

    g.lineStyle(1, 0x5a5a6a, 0.5);
    g.strokeRoundedRect(rx, ry, RIM_WIDTH, RIM_HEIGHT, 6);
  }
}
