import Phaser from 'phaser';
import { FONTS, getHeroSlotX, HERO_SLOT_Y_OFFSET } from '../utils/layout';

const LABEL_OFFSET_Y = -8;

export class ZoneNode extends Phaser.GameObjects.Container {
  readonly zoneIndex: number;
  private readonly nodeImage: Phaser.GameObjects.Image;
  private readonly label: Phaser.GameObjects.Text;
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

    this.nodeImage = scene.add.image(0, 0, textureKey);
    this.nodeImage.setDisplaySize(displayWidth, displayHeight);

    this.label = scene.add.text(0, -displayHeight / 2 + LABEL_OFFSET_Y, zoneName, {
      ...FONTS.title,
      fontSize: '14px',
    });
    this.label.setOrigin(0.5, 1);

    this.add([this.nodeImage, this.label]);
    scene.add.existing(this);
  }

  getHeroSlotWorldPosition(slotIndex: number, heroCount: number): { x: number; y: number } {
    const localX = getHeroSlotX(slotIndex, heroCount);
    const localY = this.nodeHeight / 2 + HERO_SLOT_Y_OFFSET;
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
    this.label.setPosition(0, -displayHeight / 2 + LABEL_OFFSET_Y);
  }
}
