import Phaser from 'phaser';
import { ZONE_TINTS } from '../utils/colors';

const LINE_WIDTH = 3;
const LINE_ALPHA = 0.5;
const DOT_SPACING = 14;
const DOT_RADIUS = 2;
const PULSE_DURATION = 2200;

export class ZoneConnection extends Phaser.GameObjects.Container {
  private readonly gfx: Phaser.GameObjects.Graphics;
  private readonly tint: number;
  private fromX = 0;
  private fromY = 0;
  private toX = 0;
  private toY = 0;
  private pulsePhase = 0;

  constructor(scene: Phaser.Scene, lowerZoneIndex: number) {
    super(scene, 0, 0);
    this.tint = ZONE_TINTS[lowerZoneIndex] ?? 0xffffff;

    this.gfx = scene.add.graphics();
    this.add(this.gfx);
    scene.add.existing(this);
  }

  setEndpoints(fromX: number, fromY: number, toX: number, toY: number): void {
    this.fromX = fromX;
    this.fromY = fromY;
    this.toX = toX;
    this.toY = toY;
    this.redraw();
  }

  update(_time: number, delta: number): void {
    this.pulsePhase = (this.pulsePhase + delta / PULSE_DURATION) % 1;
    this.redraw();
  }

  private redraw(): void {
    this.gfx.clear();

    const dx = this.toX - this.fromX;
    const dy = this.toY - this.fromY;
    const length = Math.sqrt(dx * dx + dy * dy);
    if (length < 1) return;

    const dotCount = Math.max(2, Math.floor(length / DOT_SPACING));
    const r = Phaser.Display.Color.IntegerToRGB(this.tint);

    for (let i = 0; i < dotCount; i++) {
      const t = i / (dotCount - 1);
      const px = this.fromX + dx * t;
      const py = this.fromY + dy * t;

      const pulse = Math.sin((t + this.pulsePhase) * Math.PI * 2);
      const alpha = LINE_ALPHA + pulse * 0.2;
      const radius = DOT_RADIUS + pulse * 0.8;

      this.gfx.fillStyle(this.tint, Math.max(0.1, alpha));
      this.gfx.fillCircle(px, py, radius);
    }

    this.gfx.lineStyle(LINE_WIDTH, this.tint, LINE_ALPHA * 0.3);
    this.gfx.lineBetween(this.fromX, this.fromY, this.toX, this.toY);

    const glowColor = Phaser.Display.Color.GetColor(
      Math.min(255, r.r + 40),
      Math.min(255, r.g + 40),
      Math.min(255, r.b + 40),
    );
    this.gfx.lineStyle(1, glowColor, LINE_ALPHA * 0.15);
    this.gfx.lineBetween(this.fromX, this.fromY, this.toX, this.toY);
  }

  override destroy(fromScene?: boolean): void {
    this.gfx.destroy();
    super.destroy(fromScene);
  }
}
