import Phaser from 'phaser';
import { COLORS, ZONE_TINTS } from '../utils/colors';
import {
  MAP_HEIGHT,
  MAP_WIDTH,
  ZONE_FRAC_0,
  ZONE_FRAC_1,
  ZONE_FRAC_2,
  zoneWorldX,
} from '../utils/layout';

interface AmbientLayer {
  emitter: Phaser.GameObjects.Particles.ParticleEmitter;
}

export class ZoneBackground {
  private readonly scene: Phaser.Scene;
  private readonly mapImage: Phaser.GameObjects.Image;
  private ambientLayers: AmbientLayer[] = [];

  constructor(scene: Phaser.Scene) {
    this.scene = scene;

    this.mapImage = scene.add.image(0, 0, 'world-map');
    this.mapImage.setOrigin(0.5, 0.5);
    this.mapImage.setDepth(0);

    const w = scene.scale.width;
    const h = scene.scale.height;
    this.applyCoverFit(w, h);
    this.createAmbientEmitters(w, h);
  }

  resize(w: number, h: number): void {
    this.applyCoverFit(w, h);
    this.destroyEmitters();
    this.createAmbientEmitters(w, h);
  }

  destroy(): void {
    this.destroyEmitters();
    this.mapImage.destroy();
  }

  private applyCoverFit(w: number, h: number): void {
    const scaleX = w / MAP_WIDTH;
    const scaleY = h / MAP_HEIGHT;
    const coverScale = Math.max(scaleX, scaleY);
    this.mapImage.setDisplaySize(MAP_WIDTH * coverScale, MAP_HEIGHT * coverScale);
    this.mapImage.setPosition(w / 2, h / 2);
  }

  private destroyEmitters(): void {
    for (const layer of this.ambientLayers) layer.emitter.destroy();
    this.ambientLayers = [];
  }

  private createAmbientEmitters(w: number, h: number): void {
    this.ambientLayers.push(this.createHollowsSparkles(w, h));
    this.ambientLayers.push(this.createEmberSparks(w, h));
    this.ambientLayers.push(this.createSpireArcane(w, h));
  }

  private createHollowsSparkles(w: number, h: number): AmbientLayer {
    const x0 = zoneWorldX(ZONE_FRAC_0, w);
    const x1 = zoneWorldX(ZONE_FRAC_1, w);
    const emitter = this.scene.add.particles(0, 0, 'particle-gold', {
      x: { min: x0, max: x1 },
      y: { min: h * 0.3, max: h * 0.95 },
      quantity: 1,
      frequency: 180,
      lifespan: 4200,
      speedY: { min: -20, max: -8 },
      speedX: { min: -12, max: 12 },
      scale: { start: 0.45, end: 0.12 },
      alpha: { start: 0.55, end: 0 },
      tint: 0xf6d77f,
      blendMode: Phaser.BlendModes.ADD,
    });
    emitter.setDepth(2);
    return { emitter };
  }

  private createEmberSparks(w: number, h: number): AmbientLayer {
    const x1 = zoneWorldX(ZONE_FRAC_1, w);
    const x2 = zoneWorldX(ZONE_FRAC_2, w);
    const emitter = this.scene.add.particles(0, 0, 'particle-spark', {
      x: { min: x1, max: x2 },
      y: { min: 0, max: h * 0.85 },
      quantity: 1,
      frequency: 120,
      lifespan: 1700,
      speed: { min: 2, max: 10 },
      scale: { start: 0.22, end: 0.02 },
      alpha: { start: 0.95, end: 0 },
      tint: [ZONE_TINTS[1], COLORS.gold],
      blendMode: Phaser.BlendModes.ADD,
    });
    emitter.setDepth(2);
    return { emitter };
  }

  private createSpireArcane(w: number, h: number): AmbientLayer {
    const x2 = zoneWorldX(ZONE_FRAC_2, w);
    const x3 = zoneWorldX(1, w);
    const cx = (x2 + x3) / 2;
    const emitter = this.scene.add.particles(cx, h / 2, 'particle-arcane', {
      emitZone: {
        type: 'edge',
        source: new Phaser.Geom.Circle(0, 0, 180),
        quantity: 32,
      },
      quantity: 1,
      frequency: 90,
      lifespan: 2600,
      speed: { min: 16, max: 36 },
      angle: { min: 0, max: 360 },
      scale: { start: 0.35, end: 0 },
      alpha: { start: 0.8, end: 0 },
      rotate: { min: -180, max: 180 },
      tint: [COLORS.purple, 0xd59dff],
      blendMode: Phaser.BlendModes.ADD,
    });
    emitter.setDepth(2);
    return { emitter };
  }
}
