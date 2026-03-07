import Phaser from 'phaser';
import { COLORS } from '../utils/colors';

/** Dark golden gradient: deep brown-gold at top → near-black at bottom */
const BG_TOP = 0x1a1408;
const BG_BOTTOM = 0x080810;

export class ZoneBackground {
  private readonly scene: Phaser.Scene;
  private readonly bgGfx: Phaser.GameObjects.Graphics;
  private ambientEmitter: Phaser.GameObjects.Particles.ParticleEmitter | null = null;
  private dustEmitter: Phaser.GameObjects.Particles.ParticleEmitter | null = null;

  constructor(scene: Phaser.Scene) {
    this.scene = scene;

    this.bgGfx = scene.add.graphics();
    this.bgGfx.setDepth(0);

    const w = scene.scale.width;
    const h = scene.scale.height;
    this.drawGradient(w, h);
    this.createAmbientParticles(w, h);
  }

  resize(w: number, h: number): void {
    this.drawGradient(w, h);
    this.destroyEmitters();
    this.createAmbientParticles(w, h);
  }

  destroy(): void {
    this.destroyEmitters();
    this.bgGfx.destroy();
  }

  private drawGradient(w: number, h: number): void {
    this.bgGfx.clear();
    this.bgGfx.fillGradientStyle(BG_TOP, BG_TOP, BG_BOTTOM, BG_BOTTOM, 1);
    this.bgGfx.fillRect(0, 0, w, h);
  }

  private destroyEmitters(): void {
    this.ambientEmitter?.destroy();
    this.ambientEmitter = null;
    this.dustEmitter?.destroy();
    this.dustEmitter = null;
  }

  private createAmbientParticles(w: number, h: number): void {
    this.ambientEmitter = this.scene.add.particles(0, 0, 'particle-gold', {
      x: { min: w * 0.2, max: w * 0.8 },
      y: { min: h * 0.1, max: h * 0.95 },
      quantity: 1,
      frequency: 250,
      lifespan: 5000,
      speedY: { min: -15, max: -5 },
      speedX: { min: -8, max: 8 },
      scale: { start: 0.35, end: 0.08 },
      alpha: { start: 0.4, end: 0 },
      tint: [0xf6d77f, COLORS.gold],
      blendMode: Phaser.BlendModes.ADD,
    });
    this.ambientEmitter.setDepth(1);

    this.dustEmitter = this.scene.add.particles(0, 0, 'particle-dust', {
      x: { min: 0, max: w },
      y: { min: 0, max: h },
      quantity: 1,
      frequency: 400,
      lifespan: 6000,
      speedY: { min: -6, max: 6 },
      speedX: { min: -4, max: 4 },
      scale: { start: 0.3, end: 0 },
      alpha: { start: 0.15, end: 0 },
      tint: 0x9090b0,
      blendMode: Phaser.BlendModes.ADD,
    });
    this.dustEmitter.setDepth(1);
  }
}
