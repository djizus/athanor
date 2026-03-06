// ═══════════════════════════════════════════════
// generate-images — CLI for AI image asset generation
// ═══════════════════════════════════════════════

import { existsSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
import manifest from './data/assets.json';
import { generateImage, resizeImage, savePng } from './lib/fal-client';
import { MAX_CONCURRENCY, REQUEST_DELAY_MS } from './lib/env';
import { buildPrompt } from './lib/prompts';
import type { AssetManifest, ImageAssetDef, ImageCategory } from './lib/types';
import { IMAGE_CATEGORIES } from './lib/types';

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUTPUT_ROOT = resolve(__dirname, '../../public/assets');

// ─── CLI Argument Parsing ───

interface CliOptions {
  dryRun: boolean;
  asset: ImageCategory | null;
  force: boolean;
}

function parseArgs(): CliOptions {
  const args = process.argv.slice(2);
  const opts: CliOptions = { dryRun: false, asset: null, force: false };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--dry-run') {
      opts.dryRun = true;
    } else if (arg === '--force') {
      opts.force = true;
    } else if (arg === '--asset' && i + 1 < args.length) {
      const val = args[++i] as ImageCategory;
      if (!IMAGE_CATEGORIES.includes(val)) {
        console.error(`Unknown asset category: ${val}`);
        console.error(`Valid categories: ${IMAGE_CATEGORIES.join(', ')}`);
        process.exit(1);
      }
      opts.asset = val;
    } else if (arg === '--help' || arg === '-h') {
      printUsage();
      process.exit(0);
    } else {
      console.error(`Unknown argument: ${arg}`);
      printUsage();
      process.exit(1);
    }
  }

  return opts;
}

function printUsage(): void {
  console.log(`
Usage: npx tsx scripts/generate-assets/generate-images.ts [options]

Options:
  --dry-run              Show what would be generated without calling API
  --asset <category>     Generate only one category: ${IMAGE_CATEGORIES.join(', ')}
  --force                Regenerate even if file already exists
  --help, -h             Show this help

Examples:
  npx tsx scripts/generate-assets/generate-images.ts
  npx tsx scripts/generate-assets/generate-images.ts --dry-run
  npx tsx scripts/generate-assets/generate-images.ts --asset backgrounds
  npx tsx scripts/generate-assets/generate-images.ts --asset ingredients --force
`.trim());
}

// ─── Asset Collection ───

function collectAssets(opts: CliOptions): ImageAssetDef[] {
  const typed = manifest as AssetManifest;
  const categories = opts.asset ? [opts.asset] : IMAGE_CATEGORIES;
  const assets: ImageAssetDef[] = [];

  for (const cat of categories) {
    assets.push(...(typed[cat] ?? []));
  }

  return assets;
}

function outputPath(asset: ImageAssetDef): string {
  return resolve(OUTPUT_ROOT, asset.category, asset.filename);
}

// ─── Generation ───

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function processAsset(asset: ImageAssetDef, opts: CliOptions): Promise<boolean> {
  const out = outputPath(asset);

  if (!opts.force && existsSync(out)) {
    console.log(`  SKIP  ${asset.category}/${asset.filename} (exists)`);
    return false;
  }

  const prompt = buildPrompt(asset);

  if (opts.dryRun) {
    console.log(`  PLAN  ${asset.category}/${asset.filename}`);
    console.log(`        ${asset.width}x${asset.height}`);
    console.log(`        prompt: ${prompt.slice(0, 120)}...`);
    return false;
  }

  console.log(`  GEN   ${asset.category}/${asset.filename} (${asset.width}x${asset.height})`);

  const rawBuffer = await generateImage(prompt, asset.width, asset.height);
  const finalBuffer = await resizeImage(rawBuffer, asset.width, asset.height);
  await savePng(finalBuffer, out);

  console.log(`  DONE  ${asset.category}/${asset.filename}`);
  return true;
}

async function run(): Promise<void> {
  const opts = parseArgs();
  const assets = collectAssets(opts);

  if (assets.length === 0) {
    console.log('No assets to generate.');
    return;
  }

  console.log(`\n🎨 Alchemist Asset Generator`);
  console.log(`   ${assets.length} image(s) queued${opts.dryRun ? ' (DRY RUN)' : ''}`);
  console.log(`   Output: ${OUTPUT_ROOT}\n`);

  let generated = 0;
  let skipped = 0;

  for (let i = 0; i < assets.length; i += MAX_CONCURRENCY) {
    const batch = assets.slice(i, i + MAX_CONCURRENCY);
    const results = await Promise.allSettled(
      batch.map((asset) => processAsset(asset, opts)),
    );

    for (const result of results) {
      if (result.status === 'fulfilled') {
        if (result.value) generated++;
        else skipped++;
      } else {
        console.error(`  FAIL  ${result.reason}`);
      }
    }

    if (!opts.dryRun && i + MAX_CONCURRENCY < assets.length) {
      await sleep(REQUEST_DELAY_MS);
    }
  }

  console.log(`\n✅ Complete: ${generated} generated, ${skipped} skipped\n`);
}

run().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
