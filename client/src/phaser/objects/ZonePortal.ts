import Phaser from 'phaser';
import { ZONE_TINTS } from '../utils/colors';
import { FONTS } from '../utils/layout';

function randomZone(geom: Phaser.Geom.Rectangle | Phaser.Geom.Circle): Phaser.GameObjects.Particles.Zones.RandomZone {
  return new Phaser.GameObjects.Particles.Zones.RandomZone(
    geom as unknown as Phaser.Types.GameObjects.Particles.RandomZoneSource,
  );
}

const PORTAL_RADIUS = 52;
const RING_WIDTH = 3;
const GLOW_RADIUS = PORTAL_RADIUS + 8;

const ZONE_BG_KEYS = [
  'zone-hollows',
  'zone-cavern',
  'zone-spire',
  'zone-abyss',
  'zone-crystalveil',
];

const ZONE_NAMES = [
  'Amber Hollows',
  'Ember Cavern',
  'Aether Spire',
  'Sunken Abyss',
  'Crystalveil Reach',
];

export class ZonePortal extends Phaser.GameObjects.Container {
  readonly zoneIndex: number;
  private readonly tint: number;
  private readonly ringGfx: Phaser.GameObjects.Graphics;
  private readonly glowCircle: Phaser.GameObjects.Arc;
  private readonly label: Phaser.GameObjects.Text;
  private readonly maskGfx: Phaser.GameObjects.Graphics;
  private readonly bgImage: Phaser.GameObjects.Image | null = null;
  private readonly innerDark: Phaser.GameObjects.Arc;
  private readonly ambientEmitter: Phaser.GameObjects.Particles.ParticleEmitter;

  private glowTween: Phaser.Tweens.Tween;
  private bgScrollTween: Phaser.Tweens.Tween | null = null;
  private _active = false;

  constructor(scene: Phaser.Scene, zoneIndex: number, x: number, y: number) {
    super(scene, x, y);
    this.zoneIndex = zoneIndex;
    this.tint = ZONE_TINTS[zoneIndex] ?? 0xc8a040;

    this.glowCircle = scene.add.circle(0, 0, GLOW_RADIUS, this.tint, 0.06);
    this.glowCircle.setBlendMode(Phaser.BlendModes.ADD);

    this.innerDark = scene.add.circle(0, 0, PORTAL_RADIUS, 0x0a0a14, 0.92);

    const bgKey = ZONE_BG_KEYS[zoneIndex];
    if (bgKey && scene.textures.exists(bgKey)) {
      this.bgImage = scene.add.image(0, 0, bgKey);
      const srcW = this.bgImage.width;
      const srcH = this.bgImage.height;
      const targetSize = PORTAL_RADIUS * 2;
      const scale = Math.max(targetSize / srcW, targetSize / srcH) * 1.3;
      this.bgImage.setScale(scale);
      this.bgImage.setAlpha(0.4);
    }

    this.maskGfx = scene.make.graphics({ x: 0, y: 0 });
    this.maskGfx.fillCircle(0, 0, PORTAL_RADIUS - 2);
    const mask = new Phaser.Display.Masks.GeometryMask(scene, this.maskGfx);

    if (this.bgImage) this.bgImage.setMask(mask);
    this.innerDark.setMask(mask);

    this.ringGfx = scene.add.graphics();
    this.drawRing(false);

    this.label = scene.add.text(0, PORTAL_RADIUS + 10, ZONE_NAMES[zoneIndex] ?? '', {
      ...FONTS.bodySmall,
      fontSize: '11px',
      color: Phaser.Display.Color.IntegerToColor(this.tint).rgba,
    });
    this.label.setOrigin(0.5, 0);

    this.ambientEmitter = scene.add.particles(0, 0, 'particle-ember', {
      quantity: 1,
      frequency: 600,
      lifespan: 1400,
      speed: { min: 6, max: 18 },
      angle: { min: 0, max: 360 },
      scale: { start: 0.35, end: 0 },
      alpha: { start: 0.4, end: 0 },
      tint: [this.tint],
      blendMode: Phaser.BlendModes.ADD,
      emitZone: randomZone(new Phaser.Geom.Circle(0, 0, PORTAL_RADIUS * 0.6)),
    });

    const children: Phaser.GameObjects.GameObject[] = [
      this.glowCircle,
      this.innerDark,
    ];
    if (this.bgImage) children.push(this.bgImage);
    children.push(this.ringGfx, this.ambientEmitter, this.label);
    this.add(children);

    scene.add.existing(this);

    this.glowTween = scene.tweens.add({
      targets: this.glowCircle,
      alpha: 0.12,
      scale: 1.08,
      yoyo: true,
      repeat: -1,
      duration: 2400,
      ease: 'Sine.InOut',
    });

    scene.events.on(Phaser.Scenes.Events.PRE_UPDATE, this.updateMaskPosition, this);
  }

  get portalRadius(): number {
    return PORTAL_RADIUS;
  }

  get isExploring(): boolean {
    return this._active;
  }

  setExploring(active: boolean): void {
    if (this._active === active) return;
    this._active = active;

    this.drawRing(active);

    if (active) {
      this.glowTween.stop();
      this.glowTween = this.scene.tweens.add({
        targets: this.glowCircle,
        alpha: 0.28,
        scale: 1.18,
        yoyo: true,
        repeat: -1,
        duration: 1000,
        ease: 'Sine.InOut',
      });
      if (this.bgImage) {
        this.bgImage.setAlpha(0.6);
        this.bgScrollTween?.stop();
        this.bgScrollTween = this.scene.tweens.add({
          targets: this.bgImage,
          x: { from: -8, to: 8 },
          yoyo: true,
          repeat: -1,
          duration: 4000,
          ease: 'Sine.InOut',
        });
      }
      this.ambientEmitter.setFrequency(250);
    } else {
      this.glowTween.stop();
      this.glowTween = this.scene.tweens.add({
        targets: this.glowCircle,
        alpha: 0.06,
        scale: 1.08,
        yoyo: true,
        repeat: -1,
        duration: 2400,
        ease: 'Sine.InOut',
      });
      if (this.bgImage) {
        this.bgImage.setAlpha(0.4);
        this.bgScrollTween?.stop();
        this.bgScrollTween = null;
        this.bgImage.setPosition(0, 0);
      }
      this.ambientEmitter.setFrequency(600);
    }
  }

  pulseEvent(color: number): void {
    this.scene.tweens.add({
      targets: this.glowCircle,
      alpha: 0.55,
      scale: 1.35,
      duration: 150,
      yoyo: true,
      ease: 'Sine.Out',
    });

    const flash = this.scene.add.circle(0, 0, PORTAL_RADIUS, color, 0.3);
    flash.setBlendMode(Phaser.BlendModes.ADD);
    this.add(flash);
    this.scene.tweens.add({
      targets: flash,
      alpha: 0,
      scale: 1.2,
      duration: 250,
      ease: 'Sine.Out',
      onComplete: () => {
        this.remove(flash);
        flash.destroy();
      },
    });
  }

  getHeroAnchor(): { x: number; y: number } {
    return { x: this.x, y: this.y };
  }

  reposition(x: number, y: number): void {
    this.setPosition(x, y);
  }

  override destroy(fromScene?: boolean): void {
    this.scene.events.off(Phaser.Scenes.Events.PRE_UPDATE, this.updateMaskPosition, this);
    this.glowTween.stop();
    this.bgScrollTween?.stop();
    this.ambientEmitter.destroy();
    this.maskGfx.destroy();
    this.ringGfx.destroy();
    super.destroy(fromScene);
  }

  private updateMaskPosition = (): void => {
    this.maskGfx.setPosition(this.x, this.y);
  };

  private drawRing(active: boolean): void {
    const g = this.ringGfx;
    g.clear();

    g.lineStyle(RING_WIDTH, this.tint, active ? 0.9 : 0.45);
    g.strokeCircle(0, 0, PORTAL_RADIUS);

    if (active) {
      g.lineStyle(1, this.tint, 0.2);
      g.strokeCircle(0, 0, PORTAL_RADIUS + 5);
    }
  }
}
