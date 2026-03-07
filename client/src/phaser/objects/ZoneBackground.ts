import Phaser from 'phaser';
import { COLORS } from '../utils/colors';
import { MAP_HEIGHT, MAP_WIDTH } from '../utils/layout';

export class ZoneBackground {
  private readonly scene: Phaser.Scene;
  private readonly bgImage: Phaser.GameObjects.Image;
  private ambientEmitter: Phaser.GameObjects.Particles.ParticleEmitter | null = null;
  private dustEmitter: Phaser.GameObjects.Particles.ParticleEmitter | null = null;

  constructor(scene: Phaser.Scene) {
    this.scene = scene;

    this.bgImage = scene.add.image(0, 0, 'world-bg');
    this.bgImage.setOrigin(0.5, 0.5);
    this.bgImage.setDepth(0);

    const w = scene.scale.width;
    const h = scene.scale.height;
    this.applyCoverFit(w, h);
    this.createAmbientParticles(w, h);
  }

  resize(w: number, h: number): void {
    this.applyCoverFit(w, h);
    this.destroyEmitters();
    this.createAmbientParticles(w, h);
  }

  destroy(): void {
    this.destroyEmitters();
    this.bgImage.destroy();
  }

  private applyCoverFit(w: number, h: number): void {
    const scaleX = w / MAP_WIDTH;
    const scaleY = h / MAP_HEIGHT;
    const coverScale = Math.max(scaleX, scaleY);
    const displayW = MAP_WIDTH * coverScale;
    const displayH = MAP_HEIGHT * coverScale;
    this.bgImage.setDisplaySize(displayW, displayH);
    const yAnchor = h > w ? h * 0.58 : h / 2;
    this.bgImage.setPosition(w / 2, yAnchor);
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
