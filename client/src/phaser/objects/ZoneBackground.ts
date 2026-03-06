import Phaser from 'phaser';
import { COLORS, ZONE_TINTS } from '../utils/colors';
import {
  GAME_HEIGHT,
  WORLD_WIDTH,
  ZONE_0_X,
  ZONE_1_X,
  ZONE_2_X,
} from '../utils/layout';

interface AmbientLayer {
  emitter: Phaser.GameObjects.Particles.ParticleEmitter;
}

export class ZoneBackground {
  private readonly scene: Phaser.Scene;
  private readonly container: Phaser.GameObjects.Container;
  private readonly mapImage: Phaser.GameObjects.Image;
  private readonly ambientLayers: AmbientLayer[] = [];

  constructor(scene: Phaser.Scene) {
    this.scene = scene;
    this.container = scene.add.container(0, 0);

    this.mapImage = scene.add.image(WORLD_WIDTH / 2, GAME_HEIGHT / 2, 'world-map');
    this.mapImage.setDisplaySize(WORLD_WIDTH, GAME_HEIGHT);
    this.mapImage.setDepth(0);

    this.container.add(this.mapImage);
    this.createAmbientEmitters();
  }

  destroy(): void {
    for (const layer of this.ambientLayers) layer.emitter.destroy();
    this.mapImage.destroy();
    this.container.destroy();
  }

  private createAmbientEmitters(): void {
    this.ambientLayers.push(this.createMeadowSparkles());
    this.ambientLayers.push(this.createCavernSparks());
    this.ambientLayers.push(this.createSpireArcane());
  }

  private createMeadowSparkles(): AmbientLayer {
    const emitter = this.scene.add.particles(0, 0, 'particle-gold', {
      x: { min: ZONE_0_X, max: ZONE_1_X },
      y: { min: GAME_HEIGHT * 0.3, max: GAME_HEIGHT * 0.95 },
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
    this.container.add(emitter);
    return { emitter };
  }

  private createCavernSparks(): AmbientLayer {
    const emitter = this.scene.add.particles(0, 0, 'particle-spark', {
      x: { min: ZONE_1_X, max: ZONE_2_X },
      y: { min: 0, max: GAME_HEIGHT * 0.85 },
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
    this.container.add(emitter);
    return { emitter };
  }

  private createSpireArcane(): AmbientLayer {
    const spireWidth = WORLD_WIDTH - ZONE_2_X;
    const emitter = this.scene.add.particles(ZONE_2_X + spireWidth / 2, GAME_HEIGHT / 2, 'particle-arcane', {
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
    this.container.add(emitter);
    return { emitter };
  }
}
