import Phaser from 'phaser';
import { COLORS, ZONE_TINTS } from '../utils/colors';
import {
  BASE_CAMP_X,
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
  private readonly labOverlay: Phaser.GameObjects.Image;
  private readonly ambientLayers: AmbientLayer[] = [];

  constructor(scene: Phaser.Scene) {
    this.scene = scene;
    this.container = scene.add.container(0, 0);

    this.mapImage = scene.add.image(WORLD_WIDTH / 2, GAME_HEIGHT / 2, 'world-map');
    this.mapImage.setDisplaySize(WORLD_WIDTH, GAME_HEIGHT);
    this.mapImage.setDepth(0);

    this.labOverlay = scene.add.image(BASE_CAMP_X + 180, GAME_HEIGHT / 2, 'lab-bg');
    this.labOverlay.setDisplaySize(460, GAME_HEIGHT);
    this.labOverlay.setAlpha(0.18);
    this.labOverlay.setDepth(1);

    this.container.add([this.mapImage, this.labOverlay]);
    this.createAmbientEmitters();
  }

  destroy(): void {
    for (const layer of this.ambientLayers) layer.emitter.destroy();
    this.mapImage.destroy();
    this.labOverlay.destroy();
    this.container.destroy();
  }

  private createAmbientEmitters(): void {
    this.ambientLayers.push(this.createLabDust());
    this.ambientLayers.push(this.createMeadowSparkles());
    this.ambientLayers.push(this.createCavernSparks());
    this.ambientLayers.push(this.createSpireArcane());
  }

  private createLabDust(): AmbientLayer {
    const emitter = this.scene.add.particles(0, 0, 'particle-dust', {
      x: { min: 0, max: 480 },
      y: { min: 0, max: GAME_HEIGHT },
      quantity: 1,
      frequency: 420,
      lifespan: 8000,
      speedX: { min: -4, max: 4 },
      speedY: { min: -8, max: -2 },
      scale: { start: 0.55, end: 0.1 },
      alpha: { start: 0.2, end: 0 },
      tint: COLORS.white,
    });
    emitter.setDepth(2);
    this.container.add(emitter);
    return { emitter };
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
