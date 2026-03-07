import Phaser from 'phaser';
import { ZONE_TINTS } from '../utils/colors';
import { FONTS, getHeroSlotX, HERO_SLOT_Y_OFFSET } from '../utils/layout';

const LABEL_OFFSET_Y = -8;
const GLOW_ALPHA = 0.18;
const GLOW_SCALE_PULSE = 1.08;
const GLOW_DURATION = 1400;

export class ZoneNode extends Phaser.GameObjects.Container {
  readonly zoneIndex: number;
  private readonly nodeImage: Phaser.GameObjects.Image;
  private readonly label: Phaser.GameObjects.Text;
  private readonly glow: Phaser.GameObjects.Rectangle;
  private glowTween: Phaser.Tweens.Tween | null = null;
  private nodeHeight: number;

  constructor(
    scene: Phaser.Scene,
    zoneIndex: number,
    zoneName: string,
    textureKey: string,
    x: number,
    y: number,
    displayWidth: number,
    displayHeight: number,
  ) {
    super(scene, x, y);
    this.zoneIndex = zoneIndex;
    this.nodeHeight = displayHeight;

    const tint = ZONE_TINTS[zoneIndex] ?? 0xffffff;

    this.glow = scene.add.rectangle(0, 0, displayWidth + 16, displayHeight + 16, tint, GLOW_ALPHA);
    this.glow.setBlendMode(Phaser.BlendModes.ADD);

    this.nodeImage = scene.add.image(0, 0, textureKey);
    this.nodeImage.setDisplaySize(displayWidth, displayHeight);

    this.label = scene.add.text(0, -displayHeight / 2 + LABEL_OFFSET_Y, zoneName, {
      ...FONTS.title,
      fontSize: '14px',
    });
    this.label.setOrigin(0.5, 1);

    this.add([this.glow, this.nodeImage, this.label]);
    scene.add.existing(this);

    this.startGlowPulse(tint);
  }

  getHeroSlotWorldPosition(slotIndex: number, heroCount: number): { x: number; y: number } {
    const localX = getHeroSlotX(slotIndex, heroCount);
    const localY = this.nodeHeight / 2 - HERO_SLOT_Y_OFFSET;
    return { x: this.x + localX, y: this.y + localY };
  }

  getTopAnchor(): { x: number; y: number } {
    return { x: this.x, y: this.y - this.nodeHeight / 2 };
  }

  getBottomAnchor(): { x: number; y: number } {
    return { x: this.x, y: this.y + this.nodeHeight / 2 };
  }

  resize(x: number, y: number, displayWidth: number, displayHeight: number): void {
    this.setPosition(x, y);
    this.nodeHeight = displayHeight;
    this.nodeImage.setDisplaySize(displayWidth, displayHeight);
    this.glow.setSize(displayWidth + 16, displayHeight + 16);
    this.label.setPosition(0, -displayHeight / 2 + LABEL_OFFSET_Y);
  }

  private startGlowPulse(tint: number): void {
    this.glow.setFillStyle(tint, GLOW_ALPHA);
    this.glowTween?.stop();
    this.glowTween = this.scene.tweens.add({
      targets: this.glow,
      alpha: GLOW_ALPHA * 0.4,
      scaleX: GLOW_SCALE_PULSE,
      scaleY: GLOW_SCALE_PULSE,
      yoyo: true,
      repeat: -1,
      duration: GLOW_DURATION,
      ease: 'Sine.InOut',
    });
  }

  override destroy(fromScene?: boolean): void {
    this.glowTween?.stop();
    this.glowTween = null;
    super.destroy(fromScene);
  }
}
