// ═══════════════════════════════════════════════
// generate-layers — CLI for parallax layer decomposition
// ═══════════════════════════════════════════════

import { existsSync, readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
import layerJobs from './data/layers.json';
import { uploadToFalStorage, decomposeImageLayers, resizeImage, savePng } from './lib/fal-client';
import { MAX_CONCURRENCY, REQUEST_DELAY_MS } from './lib/env';
import type { LayerJobDef } from './lib/types';

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUTPUT_ROOT = resolve(__dirname, '../../client/public/assets');

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
  const ids = (layerJobs as LayerJobDef[]).map((j) => j.id).join(', ');
  console.log(`
Usage: npx tsx scripts/generate-assets/generate-layers.ts [options]

Options:
  --dry-run              Show what would be generated without calling API
  --only <id,id,...>     Generate only specific jobs by ID
  --force                Regenerate even if files already exist
  --help, -h             Show this help

Available layer job IDs:
  ${ids}

Examples:
  npx tsx scripts/generate-assets/generate-layers.ts
  npx tsx scripts/generate-assets/generate-layers.ts --dry-run
  npx tsx scripts/generate-assets/generate-layers.ts --only menu-bg
  npx tsx scripts/generate-assets/generate-layers.ts --only menu-bg --force
`.trim());
}

// ─── Job Collection ───

function collectJobs(opts: CliOptions): LayerJobDef[] {
  const all = layerJobs as LayerJobDef[];

  if (!opts.only) return all;

  const filtered = all.filter((j) => opts.only!.includes(j.id));
  const missing = opts.only.filter((id) => !all.some((j) => j.id === id));
  if (missing.length > 0) {
    console.error(`Unknown layer job IDs: ${missing.join(', ')}`);
    console.error(`Valid IDs: ${all.map((j) => j.id).join(', ')}`);
    process.exit(1);
  }

  return filtered;
}

function layerOutputPaths(job: LayerJobDef): string[] {
  const paths: string[] = [];
  for (let i = 0; i < job.numLayers; i++) {
    paths.push(resolve(OUTPUT_ROOT, job.outputDir, `${job.outputPrefix}-${i}.png`));
  }
  return paths;
}

function allLayersExist(job: LayerJobDef): boolean {
  return layerOutputPaths(job).every((p) => existsSync(p));
}

// ─── Generation ───

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function processJob(job: LayerJobDef, opts: CliOptions): Promise<boolean> {
  const outLabel = `${job.outputDir}/${job.outputPrefix}-*.png`;

  if (!opts.force && allLayersExist(job)) {
    console.log(`  SKIP  ${outLabel} (all ${job.numLayers} layers exist)`);
    return false;
  }

  const sourcePath = resolve(OUTPUT_ROOT, job.source);
  if (!existsSync(sourcePath)) {
    console.error(`  FAIL  ${job.id}: source not found: ${sourcePath}`);
    return false;
  }

  if (opts.dryRun) {
    console.log(`  PLAN  ${outLabel}`);
    console.log(`        source: ${job.source}`);
    console.log(`        layers: ${job.numLayers}, size: ${job.width}x${job.height}`);
    return false;
  }

  console.log(`  GEN   ${outLabel} (${job.numLayers} layers, ${job.width}x${job.height})`);

  const sourceBuffer = readFileSync(sourcePath);
  const uploadedUrl = await uploadToFalStorage(sourceBuffer);
  const layerBuffers = await decomposeImageLayers(uploadedUrl, job.numLayers);
  const outputPaths = layerOutputPaths(job);

  for (let i = 0; i < layerBuffers.length && i < job.numLayers; i++) {
    const resized = await resizeImage(layerBuffers[i], job.width, job.height);
    await savePng(resized, outputPaths[i]);
  }

  console.log(`  DONE  ${outLabel}`);
  return true;
}

async function run(): Promise<void> {
  const opts = parseArgs();
  const jobs = collectJobs(opts);

  if (jobs.length === 0) {
    console.log('No layer jobs to process.');
    return;
  }

  console.log(`\n🎨 Parallax Layer Decomposer`);
  console.log(`   ${jobs.length} job(s) queued${opts.dryRun ? ' (DRY RUN)' : ''}`);
  console.log(`   Output: ${OUTPUT_ROOT}\n`);

  let generated = 0;
  let skipped = 0;

  for (let i = 0; i < jobs.length; i += MAX_CONCURRENCY) {
    const batch = jobs.slice(i, i + MAX_CONCURRENCY);
    const results = await Promise.allSettled(
      batch.map((job) => processJob(job, opts)),
    );

    for (const result of results) {
      if (result.status === 'fulfilled') {
        if (result.value) generated++;
        else skipped++;
      } else {
        console.error(`  FAIL  ${result.reason}`);
      }
    }

    if (!opts.dryRun && i + MAX_CONCURRENCY < jobs.length) {
      await sleep(REQUEST_DELAY_MS);
    }
  }

  console.log(`\n✅ Complete: ${generated} generated, ${skipped} skipped\n`);
}

run().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
