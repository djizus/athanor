import "./lib/shims.js";
import { mkdir, writeFile, access } from "fs/promises";
import { constants } from "fs";
import { dirname, resolve } from "path";
import { fileURLToPath } from "url";
import sharp from "sharp";
import { REQUEST_DELAY_MS } from "./lib/env.js";
import { generateImage, generateSpriteSheet, removeBackgroundAI, downloadImage } from "./lib/fal-client.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ASSETS_DIR = resolve(__dirname, "..", "..", "client", "assets");
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function exists(filePath: string): Promise<boolean> {
  try { await access(filePath, constants.F_OK); return true; } catch { return false; }
}

// ─── ZONE BACKGROUNDS (2K, painted, full scene) ──────────────────────────────

const ZONE_BACKGROUNDS: Array<{ id: string; prompt: string }> = [
  {
    id: "zone_0",
    prompt: "dark dungeon entrance floor seen from above, top-down view, hand-painted style, golden amber and dark grey palette, crumbling archway stones, torch sconces with warm glow, ancient carved stone tiles, atmospheric volumetric lighting, Hades Supergiant game art style, dark fantasy, moody atmosphere, richly detailed ground texture filling entire frame",
  },
  {
    id: "zone_1",
    prompt: "volcanic cavern floor seen from above, top-down perspective, hand-painted, deep red and burnt orange palette, lava cracks with glowing embers seeping through obsidian stone tiles, smoldering coals scattered across cracked basalt ground, Hades Supergiant art style, dark fantasy, intense heat atmosphere, richly detailed ground texture filling entire frame",
  },
  {
    id: "zone_2",
    prompt: "arcane passage floor seen from above, top-down view, hand-painted, purple and dark mauve palette, runic inscriptions glowing faintly etched into dark violet flagstones, small crystal formations embedded in stone, mystical energy wisps, Hades Supergiant art style, dark fantasy, magical atmosphere, richly detailed ground texture filling entire frame",
  },
  {
    id: "zone_3",
    prompt: "underwater temple floor seen from above, top-down, hand-painted, dark blue and teal palette, wet stone covered with barnacles and coral growth, bioluminescent teal accents in cracks, shallow puddles reflecting dim light, Hades Supergiant art style, dark fantasy, deep ocean atmosphere, richly detailed ground texture filling entire frame",
  },
  {
    id: "zone_4",
    prompt: "dark ritual chamber floor seen from above, top-down, hand-painted, deep green and black palette, cracked obsidian with glowing emerald energy veins, ritual circle patterns, crystal formations erupting from floor, Hades Supergiant art style, dark fantasy, ominous final boss arena atmosphere, richly detailed ground texture filling entire frame",
  },
];

// ─── VFX TEXTURES (transparent bg, particle effects) ────────────────────────

const VFX_ASSETS: Array<{ id: string; prompt: string; needsBgRemoval: boolean }> = [
  {
    id: "slash",
    prompt: "white energy slash arc VFX effect, bright glowing crescent sword swing trail, stylized game particle effect, clean sharp edges, luminous white and pale gold, painted game art style, single effect centered on plain solid background",
    needsBgRemoval: true,
  },
  {
    id: "fire_burst",
    prompt: "orange flame burst explosion VFX effect, fiery eruption with ember sparks, stylized game particle effect, vibrant orange and red flames, painted game art style, single effect centered on plain solid background",
    needsBgRemoval: true,
  },
  {
    id: "shield_glow",
    prompt: "golden protective shield aura VFX effect, circular defensive barrier with glowing runes, stylized game particle effect, warm gold and white light, painted game art style, single effect centered on plain solid background",
    needsBgRemoval: true,
  },
  {
    id: "sparks",
    prompt: "white impact sparks VFX effect, bright collision burst with radiating spark particles, stylized game particle effect, luminous white and pale blue, painted game art style, single effect centered on plain solid background",
    needsBgRemoval: true,
  },
];

// ─── UI TEXTURES ─────────────────────────────────────────────────────────────

const UI_ASSETS: Array<{ id: string; prompt: string; width: number; height: number }> = [
  {
    id: "panel_frame",
    prompt: "dark ornate game UI panel frame, gold and bronze border decoration, dark semi-transparent center area, gothic fantasy style, Hades game interface aesthetic, rectangular horizontal panel, detailed metalwork trim, dark background",
    width: 1024, height: 256,
  },
  {
    id: "button_normal",
    prompt: "dark fantasy game button, gold trim border, rectangular, gothic dark style, game UI element, Hades Supergiant style, small ornate metallic border, dark stone center, ready state",
    width: 512, height: 128,
  },
  {
    id: "button_hover",
    prompt: "dark fantasy game button highlighted, brighter glowing gold edges, rectangular, gothic style, game UI element, Hades Supergiant style, active hover state, warm golden glow emanating from edges",
    width: 512, height: 128,
  },
  {
    id: "button_disabled",
    prompt: "dark fantasy game button disabled grayed out, desaturated dark grey tones, rectangular, gothic style, game UI element, dim and inactive, no glow, muted colors",
    width: 512, height: 128,
  },
  {
    id: "bar_frame",
    prompt: "game UI health bar frame, ornate dark metal border, horizontal bar shape, gothic fantasy game interface element, detailed metalwork, Hades style, dark background",
    width: 512, height: 64,
  },
];

// ─── MAIN ────────────────────────────────────────────────────────────────────

interface CliOptions {
  dryRun: boolean;
  force: boolean;
  only?: "backgrounds" | "vfx" | "ui";
}

function parseArgs(argv: string[]): CliOptions {
  const opts: CliOptions = { dryRun: false, force: false };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--dry-run") { opts.dryRun = true; continue; }
    if (arg === "--force") { opts.force = true; continue; }
    if (arg === "--only") { opts.only = argv[++i] as any; continue; }
    throw new Error(`Unknown argument: ${arg}`);
  }
  return opts;
}

async function generateBackgrounds(opts: CliOptions): Promise<void> {
  const outDir = resolve(ASSETS_DIR, "backgrounds");
  await mkdir(outDir, { recursive: true });

  console.log(`\n🏔  Generating ${ZONE_BACKGROUNDS.length} zone backgrounds (2K via nano-banana-2)...\n`);

  for (let i = 0; i < ZONE_BACKGROUNDS.length; i++) {
    const bg = ZONE_BACKGROUNDS[i];
    const outPath = resolve(outDir, `${bg.id}.png`);

    if (!opts.force && (await exists(outPath))) {
      // Check if existing file is a placeholder (< 50KB = placeholder)
      const { size } = await import("fs").then(fs => fs.promises.stat(outPath));
      if (size > 50_000) {
        console.log(`  [${i + 1}/${ZONE_BACKGROUNDS.length}] ${bg.id} — real asset exists (${(size/1024).toFixed(0)}KB), skipping`);
        continue;
      }
      console.log(`  [${i + 1}/${ZONE_BACKGROUNDS.length}] ${bg.id} — placeholder detected (${size}B), regenerating...`);
    }

    if (opts.dryRun) {
      console.log(`  [${i + 1}/${ZONE_BACKGROUNDS.length}] DRY RUN ${bg.id}`);
      console.log(`    prompt: ${bg.prompt.substring(0, 120)}...`);
      continue;
    }

    console.log(`  [${i + 1}/${ZONE_BACKGROUNDS.length}] Generating ${bg.id}...`);
    try {
      const result = await generateSpriteSheet(bg.prompt, "2K");
      const imgBuffer = await downloadImage(result.url);
      const pngBuffer = await sharp(imgBuffer).png().toBuffer();
      await writeFile(outPath, pngBuffer);
      const kb = (pngBuffer.length / 1024).toFixed(0);
      console.log(`    ✓ Saved ${bg.id}.png (${kb}KB, ${result.width}x${result.height})`);
    } catch (err: any) {
      console.error(`    ✗ FAILED ${bg.id}: ${err.message}`);
    }

    if (i < ZONE_BACKGROUNDS.length - 1) await sleep(REQUEST_DELAY_MS);
  }
}

async function generateVFX(opts: CliOptions): Promise<void> {
  const outDir = resolve(ASSETS_DIR, "vfx");
  await mkdir(outDir, { recursive: true });

  console.log(`\n✨ Generating ${VFX_ASSETS.length} VFX textures (1K + bg removal)...\n`);

  for (let i = 0; i < VFX_ASSETS.length; i++) {
    const vfx = VFX_ASSETS[i];
    const outPath = resolve(outDir, `${vfx.id}.png`);

    if (!opts.force && (await exists(outPath))) {
      const { size } = await import("fs").then(fs => fs.promises.stat(outPath));
      if (size > 10_000) {
        console.log(`  [${i + 1}/${VFX_ASSETS.length}] ${vfx.id} — real asset exists (${(size/1024).toFixed(0)}KB), skipping`);
        continue;
      }
      console.log(`  [${i + 1}/${VFX_ASSETS.length}] ${vfx.id} — placeholder detected, regenerating...`);
    }

    if (opts.dryRun) {
      console.log(`  [${i + 1}/${VFX_ASSETS.length}] DRY RUN ${vfx.id}`);
      continue;
    }

    console.log(`  [${i + 1}/${VFX_ASSETS.length}] Generating ${vfx.id}...`);
    try {
      const result = await generateImage(vfx.prompt, 512, 512);
      let imageUrl = result.url;

      if (vfx.needsBgRemoval) {
        console.log(`    removing background...`);
        imageUrl = await removeBackgroundAI(imageUrl);
      }

      const imgBuffer = await downloadImage(imageUrl);
      const pngBuffer = await sharp(imgBuffer).png().toBuffer();
      await writeFile(outPath, pngBuffer);
      const kb = (pngBuffer.length / 1024).toFixed(0);
      console.log(`    ✓ Saved ${vfx.id}.png (${kb}KB)`);
    } catch (err: any) {
      console.error(`    ✗ FAILED ${vfx.id}: ${err.message}`);
    }

    if (i < VFX_ASSETS.length - 1) await sleep(REQUEST_DELAY_MS);
  }
}

async function generateUI(opts: CliOptions): Promise<void> {
  const outDir = resolve(ASSETS_DIR, "ui");
  await mkdir(outDir, { recursive: true });

  console.log(`\n🎨 Generating ${UI_ASSETS.length} UI textures...\n`);

  for (let i = 0; i < UI_ASSETS.length; i++) {
    const ui = UI_ASSETS[i];
    const outPath = resolve(outDir, `${ui.id}.png`);

    if (!opts.force && (await exists(outPath))) {
      const { size } = await import("fs").then(fs => fs.promises.stat(outPath));
      if (size > 10_000) {
        console.log(`  [${i + 1}/${UI_ASSETS.length}] ${ui.id} — real asset exists (${(size/1024).toFixed(0)}KB), skipping`);
        continue;
      }
      console.log(`  [${i + 1}/${UI_ASSETS.length}] ${ui.id} — placeholder detected, regenerating...`);
    }

    if (opts.dryRun) {
      console.log(`  [${i + 1}/${UI_ASSETS.length}] DRY RUN ${ui.id}`);
      continue;
    }

    console.log(`  [${i + 1}/${UI_ASSETS.length}] Generating ${ui.id}...`);
    try {
      const result = await generateImage(ui.prompt, ui.width, ui.height);
      const imgBuffer = await downloadImage(result.url);
      const pngBuffer = await sharp(imgBuffer).png().toBuffer();
      await writeFile(outPath, pngBuffer);
      const kb = (pngBuffer.length / 1024).toFixed(0);
      console.log(`    ✓ Saved ${ui.id}.png (${kb}KB)`);
    } catch (err: any) {
      console.error(`    ✗ FAILED ${ui.id}: ${err.message}`);
    }

    if (i < UI_ASSETS.length - 1) await sleep(REQUEST_DELAY_MS);
  }
}

async function main(): Promise<void> {
  const opts = parseArgs(process.argv.slice(2));

  console.log("╔══════════════════════════════════════════════════════════════╗");
  console.log("║          ATHANOR — Game Asset Generation Pipeline           ║");
  console.log("╠══════════════════════════════════════════════════════════════╣");
  console.log("║  Backgrounds: fal-ai/nano-banana-2 (2K)                     ║");
  console.log("║  VFX:         fal-ai/flux/schnell (512) + BiRefNet bg rm    ║");
  console.log("║  UI:          fal-ai/flux/schnell (custom sizes)            ║");
  console.log("╚══════════════════════════════════════════════════════════════╝");
  console.log(`\n  Output: ${ASSETS_DIR}`);
  console.log(`  Mode:   ${opts.dryRun ? "DRY RUN" : "LIVE"}`);
  console.log(`  Force:  ${opts.force}\n`);

  if (!opts.only || opts.only === "backgrounds") await generateBackgrounds(opts);
  if (!opts.only || opts.only === "vfx") await generateVFX(opts);
  if (!opts.only || opts.only === "ui") await generateUI(opts);

  console.log("\n✅ Asset generation complete.\n");
}

main().catch((err) => { console.error(err); process.exit(1); });
