import Phaser from 'phaser';
import { COLORS } from '../utils/colors';

export class EventEffect {
  private readonly scene: Phaser.Scene;

  constructor(scene: Phaser.Scene) {
    this.scene = scene;
  }

  private get vw(): number { return this.scene.scale.width; }
  private get vh(): number { return this.scene.scale.height; }

  playTrap(x: number, y: number): void {
    this.scene.cameras.main.shake(120, 0.005);
    this.scene.cameras.main.flash(120, 180, 50, 70, false);
    this.burst('particle-damage', x, y, 18, 60, 170, 420);
  }

  playGold(x: number, y: number, value: number): void {
    this.burst('particle-gold', x, y, 16, 40, 100, 780, 0.85, -30);

    const text = this.scene.add.text(x, y - 24, `+${value}`, {
      fontFamily: 'Cinzel, serif',
      fontSize: '18px',
      color: '#f0c040',
      fontStyle: 'bold',
      stroke: '#000000',
      strokeThickness: 2,
    });
    text.setOrigin(0.5);
    this.scene.tweens.add({
      targets: text,
      y: y - 56,
      alpha: 0,
      duration: 750,
      ease: 'Sine.Out',
      onComplete: () => text.destroy(),
    });
  }

  playHeal(x: number, y: number, target?: Phaser.GameObjects.Container): void {
    const emitter = this.scene.add.particles(x, y + 8, 'particle-heal', {
      quantity: 2,
      frequency: 45,
      lifespan: 680,
      speed: { min: 18, max: 48 },
      angle: { min: 0, max: 360 },
      rotate: { min: -200, max: 200 },
      scale: { start: 0.7, end: 0 },
      alpha: { start: 0.8, end: 0 },
      gravityY: -28,
      blendMode: Phaser.BlendModes.ADD,
    });
    this.scene.time.delayedCall(300, () => emitter.stop());
    this.scene.time.delayedCall(780, () => emitter.destroy());

    if (target) this.flashTarget(target, COLORS.green);
  }

  playBeastWin(x: number, y: number, target?: Phaser.GameObjects.Container): void {
    this.burst('particle-gold', x, y, 22, 55, 140, 600);
    if (target) this.flashTarget(target, COLORS.white);
  }

  playBeastLose(x: number, y: number): void {
    this.scene.cameras.main.shake(200, 0.008);
    this.burst('particle-damage', x, y, 28, 80, 220, 540, 1.1);
  }

  playIngredientDrop(x: number, y: number, target?: Phaser.GameObjects.Container): void {
    this.burst('particle-generic', x, y, 10, 24, 72, 360, 0.7);
    if (target) {
      this.scene.tweens.add({
        targets: target,
        scaleX: 1.06,
        scaleY: 1.06,
        yoyo: true,
        duration: 100,
        ease: 'Quad.Out',
      });
    }
  }

  playCraftSuccess(): void {
    const cx = this.vw / 2;
    const emitter = this.scene.add.particles(cx, this.vh - 80, 'particle-arcane', {
      quantity: 4,
      frequency: 35,
      lifespan: 900,
      speedY: { min: -260, max: -140 },
      speedX: { min: -140, max: 140 },
      scale: { start: 0.8, end: 0 },
      alpha: { start: 0.9, end: 0 },
      tint: [COLORS.purple, 0xce95ff],
      blendMode: Phaser.BlendModes.ADD,
    });
    this.scene.time.delayedCall(380, () => emitter.stop());
    this.scene.time.delayedCall(1100, () => emitter.destroy());
    this.scene.cameras.main.flash(200, 136, 70, 170, false);
  }

  playCraftFail(): void {
    const emitter = this.scene.add.particles(this.vw / 2, this.vh - 120, 'particle-smoke', {
      quantity: 3,
      frequency: 50,
      lifespan: 620,
      speedY: { min: -70, max: -25 },
      speedX: { min: -40, max: 40 },
      scale: { start: 0.85, end: 1.3 },
      alpha: { start: 0.32, end: 0 },
      tint: [0x7b6755, 0x5d5750],
    });
    this.scene.time.delayedCall(180, () => emitter.stop());
    this.scene.time.delayedCall(900, () => emitter.destroy());
  }

  playDiscovery(): void {
    const cx = this.vw / 2;
    const cy = this.vh / 2;

    this.burst('particle-gold', cx, cy, 64, 120, 280, 980);
    this.scene.time.delayedCall(120, () =>
      this.burst('particle-arcane', cx, cy, 52, 100, 240, 980, 0.9),
    );
    this.scene.time.delayedCall(240, () =>
      this.burst('particle-gold', cx, cy, 48, 140, 300, 900, 0.85),
    );

    this.scene.cameras.main.flash(300, 240, 190, 70, false);
    this.scene.cameras.main.shake(400, 0.003);
  }

  playGameOver(): void {
    const rain = this.scene.add.particles(0, -20, 'particle-gold', {
      x: { min: 0, max: this.vw },
      quantity: 6,
      frequency: 35,
      lifespan: 2400,
      speedY: { min: 140, max: 260 },
      speedX: { min: -25, max: 25 },
      scale: { start: 0.9, end: 0.35 },
      alpha: { start: 1, end: 0 },
      blendMode: Phaser.BlendModes.ADD,
    });
    this.scene.time.delayedCall(3000, () => rain.stop());
    this.scene.time.delayedCall(5600, () => rain.destroy());
  }

  private burst(
    texture: string, x: number, y: number,
    quantity: number, speedMin: number, speedMax: number,
    lifespan: number, scaleStart = 1, gravityY = 0,
  ): void {
    const emitter = this.scene.add.particles(x, y, texture, {
      quantity,
      lifespan,
      speed: { min: speedMin, max: speedMax },
      alpha: { start: 1, end: 0 },
      scale: { start: scaleStart, end: 0 },
      angle: { min: 0, max: 360 },
      gravityY,
      blendMode: Phaser.BlendModes.ADD,
    });
    this.scene.time.delayedCall(lifespan + 80, () => emitter.destroy());
  }

  private flashTarget(target: Phaser.GameObjects.Container, color: number): void {
    const halo = this.scene.add.circle(0, 0, 40, color, 0.45);
    halo.setBlendMode(Phaser.BlendModes.ADD);
    target.add(halo);
    this.scene.tweens.add({
      targets: halo,
      alpha: 0,
      scale: 1.4,
      duration: 200,
      ease: 'Sine.Out',
      onComplete: () => {
        target.remove(halo);
        halo.destroy();
      },
    });
  }
}
