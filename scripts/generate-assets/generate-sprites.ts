import "./lib/shims.js";
import { mkdir, readFile, writeFile, access } from "fs/promises";
import { constants } from "fs";
import { dirname, resolve } from "path";
import { fileURLToPath } from "url";
import sharp from "sharp";
import { generateImage, downloadImage } from "./lib/fal-client.js";

interface AnimationDef {
  name: string;
  frames: number;
  poseHints: string[];
}

interface CharacterDef {
  id: string;
  basePrompt: string;
  animations: AnimationDef[];
}

interface SpriteManifest {
  outputDir: string;
  imageSize: { width: number; height: number };
  style: string;
  characters: CharacterDef[];
}

interface CliOptions {
  dryRun: boolean;
  character?: string;
  animation?: string;
  force: boolean;
  removeBackground: boolean;
}

function parseArgs(argv: string[]): CliOptions {
  const opts: CliOptions = { dryRun: false, force: false, removeBackground: true };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--dry-run") { opts.dryRun = true; continue; }
    if (arg === "--force") { opts.force = true; continue; }
    if (arg === "--no-rembg") { opts.removeBackground = false; continue; }
    if (arg === "--character") { opts.character = argv[++i]; continue; }
    if (arg === "--animation") { opts.animation = argv[++i]; continue; }
    throw new Error(`Unknown argument: ${arg}`);
  }
  return opts;
}

async function exists(filePath: string): Promise<boolean> {
  try { await access(filePath, constants.F_OK); return true; } catch { return false; }
}

async function removeBackground(input: Buffer): Promise<Buffer> {
  const image = sharp(input).ensureAlpha();
  const { data, info } = await image.raw().toBuffer({ resolveWithObject: true });
  const { width, height, channels } = info;

  const corners = [
    0,
    (width - 1) * channels,
    (height - 1) * width * channels,
    ((height - 1) * width + (width - 1)) * channels,
  ];
  let bgR = 0, bgG = 0, bgB = 0, samples = 0;
  for (const offset of corners) {
    bgR += data[offset]; bgG += data[offset + 1]; bgB += data[offset + 2];
    samples++;
  }
  bgR = Math.round(bgR / samples);
  bgG = Math.round(bgG / samples);
  bgB = Math.round(bgB / samples);

  const tolerance = 40;
  for (let i = 0; i < data.length; i += channels) {
    const dr = Math.abs(data[i] - bgR);
    const dg = Math.abs(data[i + 1] - bgG);
    const db = Math.abs(data[i + 2] - bgB);
    if (dr < tolerance && dg < tolerance && db < tolerance) {
      data[i + 3] = 0;
    }
  }

  return sharp(data, { raw: { width, height, channels: channels as 4 } })
    .png()
    .toBuffer();
}

function buildPrompt(manifest: SpriteManifest, character: CharacterDef, poseHint: string): string {
  return `${manifest.style}, ${character.basePrompt}, ${poseHint}`;
}

interface SpriteBatch {
  character: string;
  animation: string;
  frame: number;
  prompt: string;
  outputPath: string;
}

function flattenManifest(manifest: SpriteManifest, assetsDir: string, opts: CliOptions): SpriteBatch[] {
  const batches: SpriteBatch[] = [];
  for (const char of manifest.characters) {
    if (opts.character && char.id !== opts.character) continue;
    for (const anim of char.animations) {
      if (opts.animation && anim.name !== opts.animation) continue;
      for (let f = 0; f < anim.frames; f++) {
        const hint = anim.poseHints[f] || anim.poseHints[0] || anim.name;
        batches.push({
          character: char.id,
          animation: anim.name,
          frame: f,
          prompt: buildPrompt(manifest, char, hint),
          outputPath: resolve(assetsDir, manifest.outputDir, char.id, `${char.id}_${anim.name}_${f}.png`),
        });
      }
    }
  }
  return batches;
}

async function main(): Promise<void> {
  const opts = parseArgs(process.argv.slice(2));
  const __dirname = dirname(fileURLToPath(import.meta.url));

  const manifestPath = resolve(__dirname, "data", "sprites-2d.json");
  const assetsDir = resolve(__dirname, "..", "..", "client", "assets");
  const rawDir = resolve(__dirname, "output", "sprites-raw");

  const manifest = JSON.parse(await readFile(manifestPath, "utf-8")) as SpriteManifest;
  const batches = flattenManifest(manifest, assetsDir, opts);

  console.log(`\n🎨 Sprite generation: ${batches.length} sprites to process\n`);

  let generated = 0, skipped = 0, failed = 0;

  for (let i = 0; i < batches.length; i++) {
    const batch = batches[i];
    const tag = `[${i + 1}/${batches.length}] ${batch.character}/${batch.animation}_${batch.frame}`;

    if (!opts.force && (await exists(batch.outputPath))) {
      console.log(`${tag} -> exists, skipping`);
      skipped++;
      continue;
    }

    if (opts.dryRun) {
      console.log(`${tag} -> DRY RUN`);
      console.log(`  prompt: ${batch.prompt.substring(0, 120)}...`);
      console.log(`  output: ${batch.outputPath}`);
      skipped++;
      continue;
    }

    try {
      console.log(`${tag} -> generating...`);
      const result = await generateImage(batch.prompt, manifest.imageSize.width, manifest.imageSize.height);
      const imageBuffer = await downloadImage(result.url);

      const rawPath = resolve(rawDir, batch.character, `${batch.character}_${batch.animation}_${batch.frame}.png`);
      await mkdir(dirname(rawPath), { recursive: true });
      await writeFile(rawPath, imageBuffer);

      let finalBuffer = imageBuffer;
      if (opts.removeBackground) {
        console.log(`  removing background...`);
        finalBuffer = await removeBackground(imageBuffer);
      }

      await mkdir(dirname(batch.outputPath), { recursive: true });
      await writeFile(batch.outputPath, finalBuffer);
      console.log(`  saved: ${batch.outputPath}`);
      generated++;
    } catch (err: any) {
      console.error(`  FAILED: ${err.message}`);
      failed++;
    }
  }

  console.log(`\nDone: ${generated} generated, ${skipped} skipped, ${failed} failed`);
}

main().catch((err) => { console.error(err); process.exit(1); });
