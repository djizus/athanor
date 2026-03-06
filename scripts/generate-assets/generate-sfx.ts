// ═══════════════════════════════════════════════
// generate-sfx — CLI for AI SFX asset generation
// ═══════════════════════════════════════════════

import { existsSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
import sfxList from './data/sfx.json';
import { generateSfx, saveFile } from './lib/fal-client';
import { MAX_CONCURRENCY, REQUEST_DELAY_MS } from './lib/env';
import type { SfxAssetDef } from './lib/types';

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUTPUT_DIR = resolve(__dirname, '../../public/assets/sounds/effects');

// ─── CLI Argument Parsing ───

interface CliOptions {
  dryRun: boolean;
  only: string[] | null;
  force: boolean;
}

function parseArgs(): CliOptions {
  const args = process.argv.slice(2);
  const opts: CliOptions = { dryRun: false, only: null, force: false };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--dry-run') {
      opts.dryRun = true;
    } else if (arg === '--force') {
      opts.force = true;
    } else if (arg === '--only' && i + 1 < args.length) {
      opts.only = args[++i].split(',').map((s) => s.trim());
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
  const ids = (sfxList as SfxAssetDef[]).map((s) => s.id).join(', ');
  console.log(`
Usage: npx tsx scripts/generate-assets/generate-sfx.ts [options]

Options:
  --dry-run              Show what would be generated without calling API
  --only <id,id,...>     Generate only specific SFX by ID
  --force                Regenerate even if file already exists
  --help, -h             Show this help

Available SFX IDs:
  ${ids}

Examples:
  npx tsx scripts/generate-assets/generate-sfx.ts
  npx tsx scripts/generate-assets/generate-sfx.ts --dry-run
  npx tsx scripts/generate-assets/generate-sfx.ts --only click,discovery
  npx tsx scripts/generate-assets/generate-sfx.ts --only victory --force
`.trim());
}

// ─── Asset Collection ───

function collectSfx(opts: CliOptions): SfxAssetDef[] {
  const all = sfxList as SfxAssetDef[];

  if (!opts.only) return all;

  const filtered = all.filter((s) => opts.only!.includes(s.id));
  const missing = opts.only.filter((id) => !all.some((s) => s.id === id));
  if (missing.length > 0) {
    console.error(`Unknown SFX IDs: ${missing.join(', ')}`);
    console.error(`Valid IDs: ${all.map((s) => s.id).join(', ')}`);
    process.exit(1);
  }

  return filtered;
}

function outputPath(sfx: SfxAssetDef): string {
  return resolve(OUTPUT_DIR, sfx.filename);
}

// ─── Generation ───

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function processSfx(sfx: SfxAssetDef, opts: CliOptions): Promise<boolean> {
  const out = outputPath(sfx);

  if (!opts.force && existsSync(out)) {
    console.log(`  SKIP  ${sfx.filename} (exists)`);
    return false;
  }

  if (opts.dryRun) {
    console.log(`  PLAN  ${sfx.filename} (${sfx.duration}s)`);
    console.log(`        prompt: ${sfx.prompt.slice(0, 100)}...`);
    return false;
  }

  console.log(`  GEN   ${sfx.filename} (${sfx.duration}s)`);

  const buffer = await generateSfx(sfx.prompt, sfx.duration);
  await saveFile(buffer, out);

  console.log(`  DONE  ${sfx.filename}`);
  return true;
}

async function run(): Promise<void> {
  const opts = parseArgs();
  const sfxAssets = collectSfx(opts);

  if (sfxAssets.length === 0) {
    console.log('No SFX to generate.');
    return;
  }

  console.log(`\n🔊 Alchemist SFX Generator`);
  console.log(`   ${sfxAssets.length} sound(s) queued${opts.dryRun ? ' (DRY RUN)' : ''}`);
  console.log(`   Output: ${OUTPUT_DIR}\n`);

  let generated = 0;
  let skipped = 0;

  for (let i = 0; i < sfxAssets.length; i += MAX_CONCURRENCY) {
    const batch = sfxAssets.slice(i, i + MAX_CONCURRENCY);
    const results = await Promise.allSettled(
      batch.map((sfx) => processSfx(sfx, opts)),
    );

    for (const result of results) {
      if (result.status === 'fulfilled') {
        if (result.value) generated++;
        else skipped++;
      } else {
        console.error(`  FAIL  ${result.reason}`);
      }
    }

    if (!opts.dryRun && i + MAX_CONCURRENCY < sfxAssets.length) {
      await sleep(REQUEST_DELAY_MS);
    }
  }

  console.log(`\n✅ Complete: ${generated} generated, ${skipped} skipped\n`);
}

run().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
