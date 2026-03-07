import Phaser from 'phaser';
import { COLORS } from '../utils/colors';
import { MAP_HEIGHT, MAP_WIDTH } from '../utils/layout';

const FALLBACK_W = 1920;
const FALLBACK_H = 1080;

const SFX_KEYS = [
  'click', 'brew-success', 'brew-fail', 'discovery',
  'trap', 'gold-find', 'heal', 'beast-win', 'beast-lose',
  'expedition-start', 'claim-loot', 'recruit', 'potion-apply',
  'victory', 'notification', 'ambient-lab',
] as const;

const MUSIC_TRACKS = [
  { key: 'menu-theme', file: 'main_theme.mp3' },
] as const;

export class BootScene extends Phaser.Scene {
  constructor() {
    super('BootScene');
  }

  preload(): void {
    this.load.image('lab-bg-file', '/assets/backgrounds/lab-bg.webp');
    this.load.image('world-map-file', '/assets/backgrounds/world-map.webp');
    this.load.image('world-bg', '/assets/backgrounds/world-bg.webp');
    this.load.image('zone-athanor', '/assets/backgrounds/zone-athanor.webp');
    this.load.image('zone-hollows', '/assets/backgrounds/zone-hollows.webp');
    this.load.image('zone-cavern', '/assets/backgrounds/zone-cavern.webp');
    this.load.image('zone-spire', '/assets/backgrounds/zone-spire.webp');
    this.load.image('zone-abyss', '/assets/backgrounds/zone-abyss.webp');
    this.load.image('zone-crystalveil', '/assets/backgrounds/zone-crystalveil.webp');

    const roles = [
      { key: 'role-mage', file: 'role-mage.webp' },
      { key: 'role-rogue', file: 'role-rogue.webp' },
      { key: 'role-warrior', file: 'role-warrior.webp' },
    ];
    for (const role of roles) {
      this.load.image(role.key, `/assets/heroes/${role.file}`);
    }

    for (const key of SFX_KEYS) {
      this.load.audio(key, `/assets/sounds/effects/${key}.mp3`);
    }

    for (const track of MUSIC_TRACKS) {
      this.load.audio(track.key, `/assets/sounds/music/${track.file}`);
    }

    console.info('[BootScene:music] queued music tracks', MUSIC_TRACKS);

    this.load.on(Phaser.Loader.Events.FILE_LOAD_ERROR, (file: Phaser.Loader.File) => {
      console.debug(`[BootScene] optional asset missing: ${file.key}`);
    });
  }

  create(): void {
    const gfx = this.add.graphics();

    this.generateGradient(gfx, 'lab-bg', FALLBACK_W, FALLBACK_H, COLORS.bgPrimary, COLORS.bgSecondary);
    this.generateGradient(gfx, 'world-map', MAP_WIDTH, MAP_HEIGHT, COLORS.bgPrimary, COLORS.bgSecondary);
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

    if (this.textures.exists('world-map-file')) {
      this.textures.remove('world-map');
      this.textures.addImage('world-map', this.textures.get('world-map-file').getSourceImage() as HTMLImageElement);
    }

    const bridge = this.registry.get('bridge') as import('../PhaserBridge').PhaserBridge | undefined;
    bridge?.notifyBootComplete();

    console.info('[BootScene:music] music cache status', MUSIC_TRACKS.map((track) => ({
      key: track.key,
      loaded: this.cache.audio.exists(track.key),
    })));

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


}
