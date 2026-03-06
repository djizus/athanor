import Phaser from 'phaser';
import { COLORS, ZONE_TINTS } from '../utils/colors';
import { GAME_HEIGHT, GAME_WIDTH } from '../utils/layout';

const ZONE_BG_KEYS = ['zone-meadow', 'zone-cavern', 'zone-spire'];

const SFX_KEYS = [
  'click', 'brew-success', 'brew-fail', 'discovery',
  'trap', 'gold-find', 'heal', 'beast-win', 'beast-lose',
  'expedition-start', 'claim-loot', 'recruit', 'potion-apply',
  'victory', 'notification', 'ambient-lab',
] as const;

export class BootScene extends Phaser.Scene {
  constructor() {
    super('BootScene');
  }

  async create(): Promise<void> {
    const gfx = this.add.graphics();

    this.generateGradient(gfx, 'lab-bg', GAME_WIDTH, GAME_HEIGHT, COLORS.bgPrimary, COLORS.bgSecondary);

    for (let i = 0; i < ZONE_TINTS.length; i++) {
      const top = this.blend(ZONE_TINTS[i], COLORS.black, 0.45);
      const bottom = this.blend(ZONE_TINTS[i], COLORS.black, 0.2);
      this.generateGradient(gfx, `zone-${i}`, GAME_WIDTH, GAME_HEIGHT, top, bottom);
    }

    this.generateCircle(gfx, 'hero-sprite', 64, COLORS.white);
    this.generateCircle(gfx, 'particle-gold', 8, COLORS.gold);
    this.generateCircle(gfx, 'particle-heal', 8, COLORS.green);
    this.generateCircle(gfx, 'particle-damage', 8, COLORS.red);
    this.generateCircle(gfx, 'particle-generic', 4, COLORS.white);
    this.generateCircle(gfx, 'particle-ember', 8, 0xff7a3a);
    this.generateCircle(gfx, 'particle-arcane', 8, COLORS.purple);
    this.generateCircle(gfx, 'particle-spark', 6, 0xffd68a);
    this.generateCircle(gfx, 'particle-dust', 4, COLORS.white);
    this.generateCircle(gfx, 'particle-smoke', 14, 0x6e6258);

    gfx.destroy();

    await this.loadAssets();
    this.scene.start('MainScene');
  }

  private async loadAssets(): Promise<void> {
    // Collect all valid URLs first (async), then queue loads synchronously.
    // Phaser's loader nulls its internal list between async yields in create().
    const imageLoads: { key: string; url: string; replace?: boolean }[] = [];
    const audioLoads: { key: string; url: string }[] = [];

    const labUrl = '/assets/backgrounds/lab-bg.png';
    if (await this.urlExists(labUrl)) {
      imageLoads.push({ key: 'lab-bg', url: labUrl, replace: true });
    }

    for (let i = 0; i < ZONE_BG_KEYS.length; i++) {
      const url = `/assets/backgrounds/${ZONE_BG_KEYS[i]}.png`;
      if (await this.urlExists(url)) {
        imageLoads.push({ key: `zone-${i}`, url, replace: true });
      }
    }

    const heroNames = ['alaric', 'brynn', 'cassiel'];
    for (const name of heroNames) {
      const url = `/assets/heroes/hero-${name}.png`;
      if (await this.urlExists(url)) {
        imageLoads.push({ key: `hero-${name}`, url });
      }
    }

    for (const key of SFX_KEYS) {
      const url = `/assets/sounds/effects/${key}.mp3`;
      if (await this.urlExists(url)) {
        audioLoads.push({ key, url });
      }
    }

    if (imageLoads.length === 0 && audioLoads.length === 0) return;

    // Queue all loads synchronously — no awaits between loader calls
    for (const { key, url, replace } of imageLoads) {
      if (replace) this.textures.remove(key);
      this.load.image(key, url);
    }
    for (const { key, url } of audioLoads) {
      this.load.audio(key, url);
    }

    await new Promise<void>((resolve) => {
      this.load.once(Phaser.Loader.Events.COMPLETE, () => resolve());
      this.load.start();
    });
  }

  private async urlExists(url: string): Promise<boolean> {
    try {
      const resp = await fetch(url, { method: 'HEAD' });
      return resp.ok;
    } catch {
      return false;
    }
  }

  private generateGradient(
    gfx: Phaser.GameObjects.Graphics,
    key: string, w: number, h: number,
    topColor: number, bottomColor: number,
  ): void {
    gfx.clear();
    gfx.fillGradientStyle(topColor, topColor, bottomColor, bottomColor, 1);
    gfx.fillRect(0, 0, w, h);
    gfx.generateTexture(key, w, h);
  }

  private generateCircle(
    gfx: Phaser.GameObjects.Graphics,
    key: string, size: number, color: number,
  ): void {
    gfx.clear();
    gfx.fillStyle(color, 1);
    gfx.fillCircle(size / 2, size / 2, size / 2);
    gfx.generateTexture(key, size, size);
  }

  private blend(colorA: number, colorB: number, ratio: number): number {
    const a = Phaser.Display.Color.IntegerToRGB(colorA);
    const b = Phaser.Display.Color.IntegerToRGB(colorB);
    const mix = (from: number, to: number) => Math.round(from + (to - from) * ratio);
    return Phaser.Display.Color.GetColor(mix(a.r, b.r), mix(a.g, b.g), mix(a.b, b.b));
  }
}
