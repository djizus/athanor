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

const MUSIC_TRACKS = [
  { key: 'menu-theme', file: 'main_theme.mp3' },
  { key: 'game-loop-1', file: 'game_loop_1.mp3' },
  { key: 'game-loop-2', file: 'game_loop_2.mp3' },
] as const;

export class BootScene extends Phaser.Scene {
  constructor() {
    super('BootScene');
  }

  preload(): void {
    this.load.image('lab-bg-file', '/assets/backgrounds/lab-bg.png');

    for (let i = 0; i < ZONE_BG_KEYS.length; i++) {
      this.load.image(`zone-${i}-file`, `/assets/backgrounds/${ZONE_BG_KEYS[i]}.png`);
    }

    const heroNames = ['alaric', 'brynn', 'cassiel'];
    for (const name of heroNames) {
      this.load.image(`hero-${name}`, `/assets/heroes/hero-${name}.png`);
    }

    for (const key of SFX_KEYS) {
      this.load.audio(key, `/assets/sounds/effects/${key}.mp3`);
    }

    for (const track of MUSIC_TRACKS) {
      this.load.audio(track.key, `/assets/sounds/music/${track.file}`);
    }

    this.load.on(Phaser.Loader.Events.FILE_LOAD_ERROR, (file: Phaser.Loader.File) => {
      console.debug(`[BootScene] optional asset missing: ${file.key}`);
    });
  }

  create(): void {
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

    if (this.textures.exists('lab-bg-file')) {
      this.textures.remove('lab-bg');
      this.textures.addImage('lab-bg', this.textures.get('lab-bg-file').getSourceImage() as HTMLImageElement);
    }
    for (let i = 0; i < ZONE_BG_KEYS.length; i++) {
      const fileKey = `zone-${i}-file`;
      if (this.textures.exists(fileKey)) {
        this.textures.remove(`zone-${i}`);
        this.textures.addImage(`zone-${i}`, this.textures.get(fileKey).getSourceImage() as HTMLImageElement);
      }
    }

    const bridge = this.registry.get('bridge') as import('../PhaserBridge').PhaserBridge | undefined;
    bridge?.notifyBootComplete();

    this.scene.start('MainScene');
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
