import Phaser from 'phaser';
import { COLORS, ZONE_TINTS } from '../utils/colors';
import { GAME_HEIGHT, GAME_WIDTH } from '../utils/layout';

interface AmbientLayer {
  emitter: Phaser.GameObjects.Particles.ParticleEmitter;
  activeZone: number | null;
}

export class ZoneBackground {
  private readonly scene: Phaser.Scene;
  private readonly container: Phaser.GameObjects.Container;
  private readonly currentBg: Phaser.GameObjects.Image;
  private readonly transitionBg: Phaser.GameObjects.Image;
  private targetKey = 'lab-bg';
  private readonly ambientLayers: AmbientLayer[] = [];

  constructor(scene: Phaser.Scene) {
    this.scene = scene;
    this.container = scene.add.container(0, 0);

    this.currentBg = scene.add.image(GAME_WIDTH / 2, GAME_HEIGHT / 2, 'lab-bg');
    this.currentBg.setDisplaySize(GAME_WIDTH, GAME_HEIGHT);
    this.transitionBg = scene.add.image(GAME_WIDTH / 2, GAME_HEIGHT / 2, 'lab-bg');
    this.transitionBg.setDisplaySize(GAME_WIDTH, GAME_HEIGHT);
    this.transitionBg.setAlpha(0);

    this.container.add([this.currentBg, this.transitionBg]);
    this.createAmbientEmitters();
    this.setActiveZone(null);
  }

  setActiveZone(zoneId: number | null): void {
    const nextKey = zoneId === null ? 'lab-bg' : `zone-${zoneId}`;
    this.crossfade(nextKey);

    for (const layer of this.ambientLayers) {
      const active = layer.activeZone === zoneId;
      if (active) layer.emitter.start(); else layer.emitter.stop();
      layer.emitter.setVisible(active);
    }
  }

  destroy(): void {
    this.scene.tweens.killTweensOf(this.currentBg);
    this.scene.tweens.killTweensOf(this.transitionBg);
    for (const layer of this.ambientLayers) layer.emitter.destroy();
    this.currentBg.destroy();
    this.transitionBg.destroy();
    this.container.destroy();
  }

  private crossfade(nextKey: string): void {
    if (this.targetKey === nextKey) return;
    this.targetKey = nextKey;

    this.scene.tweens.killTweensOf(this.currentBg);
    this.scene.tweens.killTweensOf(this.transitionBg);

    this.transitionBg.setTexture(nextKey);
    this.transitionBg.setAlpha(0);

    this.scene.tweens.add({
      targets: this.currentBg,
      alpha: 0,
      duration: 500,
      ease: 'Sine.Out',
    });

    this.scene.tweens.add({
      targets: this.transitionBg,
      alpha: 1,
      duration: 500,
      ease: 'Sine.Out',
      onComplete: () => {
        this.currentBg.setTexture(nextKey);
        this.currentBg.setAlpha(1);
        this.transitionBg.setAlpha(0);
      },
    });
  }

  private createAmbientEmitters(): void {
    this.ambientLayers.push(this.createLabDust());
    this.ambientLayers.push(this.createMeadowSparkles());
    this.ambientLayers.push(this.createCavernSparks());
    this.ambientLayers.push(this.createSpireArcane());
  }

  private createLabDust(): AmbientLayer {
    const emitter = this.scene.add.particles(0, 0, 'particle-dust', {
      x: { min: 0, max: GAME_WIDTH },
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
    return { emitter, activeZone: null };
  }

  private createMeadowSparkles(): AmbientLayer {
    const emitter = this.scene.add.particles(0, 0, 'particle-gold', {
      x: { min: 0, max: GAME_WIDTH },
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
    return { emitter, activeZone: 0 };
  }

  private createCavernSparks(): AmbientLayer {
    const emitter = this.scene.add.particles(0, 0, 'particle-spark', {
      x: { min: 0, max: GAME_WIDTH },
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
    return { emitter, activeZone: 1 };
  }

  private createSpireArcane(): AmbientLayer {
    const emitter = this.scene.add.particles(GAME_WIDTH / 2, GAME_HEIGHT / 2, 'particle-arcane', {
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
    return { emitter, activeZone: 2 };
  }
}
