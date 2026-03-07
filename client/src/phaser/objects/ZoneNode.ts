import Phaser from 'phaser';
import { ZONE_TINTS } from '../utils/colors';
import { FONTS, getHeroSlotX, HERO_SLOT_Y_OFFSET } from '../utils/layout';

const LABEL_OFFSET_Y = -8;
const BORDER_RADIUS = 12;
const BORDER_WIDTH = 2;
const BG_ALPHA = 0.35;
const BORDER_ALPHA = 0.6;

export class ZoneNode extends Phaser.GameObjects.Container {
  readonly zoneIndex: number;
  private readonly gfx: Phaser.GameObjects.Graphics;
  private readonly label: Phaser.GameObjects.Text;
  private readonly tint: number;
  private nodeWidth: number;
  private nodeHeight: number;

  constructor(
    scene: Phaser.Scene,
    zoneIndex: number,
    zoneName: string,
    x: number,
    y: number,
    displayWidth: number,
    displayHeight: number,
  ) {
    super(scene, x, y);
    this.zoneIndex = zoneIndex;
    this.tint = ZONE_TINTS[zoneIndex] ?? 0xc8a040;
    this.nodeWidth = displayWidth;
    this.nodeHeight = displayHeight;

    this.gfx = scene.add.graphics();
    this.drawNode();

    this.label = scene.add.text(0, -displayHeight / 2 + LABEL_OFFSET_Y, zoneName, {
      ...FONTS.title,
      fontSize: '14px',
    });
    this.label.setOrigin(0.5, 1);

    this.add([this.gfx, this.label]);
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
    this.nodeWidth = displayWidth;
    this.nodeHeight = displayHeight;
    this.drawNode();
    this.label.setPosition(0, -displayHeight / 2 + LABEL_OFFSET_Y);
  }

  override destroy(fromScene?: boolean): void {
    this.gfx.destroy();
    super.destroy(fromScene);
  }

  private drawNode(): void {
    const w = this.nodeWidth;
    const h = this.nodeHeight;
    const hw = w / 2;
    const hh = h / 2;

    this.gfx.clear();

    this.gfx.fillStyle(this.tint, BG_ALPHA);
    this.gfx.fillRoundedRect(-hw, -hh, w, h, BORDER_RADIUS);

    this.gfx.lineStyle(BORDER_WIDTH, this.tint, BORDER_ALPHA);
    this.gfx.strokeRoundedRect(-hw, -hh, w, h, BORDER_RADIUS);
  }
}
