import fs from "node:fs";
import path from "node:path";
import {
  CACHE_ROOT,
  CLIENT_MODELS_ROOT,
  CONCURRENCY,
  appendTaskLog,
  formatError,
  loadPLimitFactory,
  relativePath,
} from "./lib/env.js";
import { generateModel } from "./lib/meshy-client.js";
import { postprocessGlb } from "./lib/postprocess.js";
import {
  buildCharacterPrompt,
  buildObstaclePrompt,
  buildTilePrompt,
} from "./lib/prompts.js";
import type {
  AssetJob3D,
  AssetMetadata,
  CharacterDef,
  CliOptions,
  ModelCategory,
  ObstacleDef,
  TileDef,
} from "./lib/types.js";

const DATA_DIR = path.join(path.dirname(new URL(import.meta.url).pathname), "data");

const CATEGORIES: ModelCategory[] = ["tiles", "obstacles", "characters"];

function loadTiles(): Record<string, TileDef> {
  return JSON.parse(fs.readFileSync(path.join(DATA_DIR, "tiles.json"), "utf-8"));
}
function loadObstacles(): Record<string, ObstacleDef> {
  return JSON.parse(fs.readFileSync(path.join(DATA_DIR, "obstacles.json"), "utf-8"));
}
function loadCharacters(): Record<string, CharacterDef> {
  return JSON.parse(fs.readFileSync(path.join(DATA_DIR, "characters.json"), "utf-8"));
}

function buildJobsFor(category: ModelCategory): AssetJob3D[] {
  const outDir = path.join(CLIENT_MODELS_ROOT, category);
  const cacheDir = path.join(CACHE_ROOT, category);
  fs.mkdirSync(outDir, { recursive: true });
  fs.mkdirSync(cacheDir, { recursive: true });

  if (category === "tiles") {
    const tiles = loadTiles();
    return Object.entries(tiles).map(([id, def]) => ({
      id,
      category,
      prompt: buildTilePrompt(def.prompt),
      polycount: def.polycount,
      outputGlbPath: path.join(outDir, `${id}.glb`),
      outputThumbPath: path.join(outDir, `${id}.thumb.png`),
      outputMetaPath: path.join(outDir, `${id}.json`),
      cacheGlbPath: path.join(cacheDir, `${id}.raw.glb`),
    }));
  }

  if (category === "obstacles") {
    const obs = loadObstacles();
    return Object.entries(obs).map(([id, def]) => ({
      id,
      category,
      prompt: buildObstaclePrompt(def.prompt),
      polycount: def.polycount,
      outputGlbPath: path.join(outDir, `${id}.glb`),
      outputThumbPath: path.join(outDir, `${id}.thumb.png`),
      outputMetaPath: path.join(outDir, `${id}.json`),
      cacheGlbPath: path.join(cacheDir, `${id}.raw.glb`),
    }));
  }

  // characters
  const chars = loadCharacters();
  return Object.entries(chars).map(([id, def]) => ({
    id,
    category,
    prompt: buildCharacterPrompt(def.prompt),
    polycount: def.polycount,
    pose: def.pose,
    outputGlbPath: path.join(outDir, `${id}.glb`),
    outputThumbPath: path.join(outDir, `${id}.thumb.png`),
    outputMetaPath: path.join(outDir, `${id}.json`),
    cacheGlbPath: path.join(cacheDir, `${id}.raw.glb`),
  }));
}

function buildAllJobs(options: CliOptions): AssetJob3D[] {
  const categories = options.category ? [options.category] : CATEGORIES;
  let jobs: AssetJob3D[] = [];
  for (const cat of categories) {
    jobs.push(...buildJobsFor(cat));
  }
  if (options.only) {
    const want = new Set(options.only);
    jobs = jobs.filter((j) => want.has(j.id));
  }
  return jobs;
}

function readFlagValue(args: string[], index: number, flag: string): string {
  const value = args[index + 1];
  if (!value || value.startsWith("--")) {
    throw new Error(`Missing value for ${flag}`);
  }
  return value;
}

function printHelp(): void {
  console.log("Usage: npx tsx scripts/generate-assets/generate-models.ts [options]");
  console.log("");
  console.log("Options:");
  console.log("  --category <c>     tiles | obstacles | characters (default: all)");
  console.log("  --only <ids>       Comma-separated asset IDs (e.g. hero,enemy-brute)");
  console.log("  --preview-only     Skip refine stage (geometry only, no textures)");
  console.log("  --no-postprocess   Skip weld/dedup/texture resize");
  console.log("  --force            Overwrite existing GLBs");
  console.log("  --dry-run          Print plan, no API calls");
  console.log("  --help             Show this help");
}

function parseArgs(argv: string[]): CliOptions {
  const opts: CliOptions = {
    previewOnly: false,
    postprocess: true,
    force: false,
    dryRun: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--help" || arg === "-h") {
      printHelp();
      process.exit(0);
    }
    if (arg === "--category") {
      const v = readFlagValue(argv, i, "--category");
      if (!CATEGORIES.includes(v as ModelCategory)) {
        throw new Error(`Invalid --category ${v}. Expected one of ${CATEGORIES.join(", ")}`);
      }
      opts.category = v as ModelCategory;
      i += 1;
      continue;
    }
    if (arg === "--only") {
      const v = readFlagValue(argv, i, "--only");
      opts.only = v.split(",").map((s) => s.trim()).filter(Boolean);
      i += 1;
      continue;
    }
    if (arg === "--preview-only") {
      opts.previewOnly = true;
      continue;
    }
    if (arg === "--no-postprocess") {
      opts.postprocess = false;
      continue;
    }
    if (arg === "--force") {
      opts.force = true;
      continue;
    }
    if (arg === "--dry-run") {
      opts.dryRun = true;
      continue;
    }
    throw new Error(`Unknown argument: ${arg}. Use --help for usage.`);
  }

  return opts;
}

interface JobResult {
  job: AssetJob3D;
  status: "succeeded" | "skipped" | "failed";
  error?: string;
  glbBytes?: number;
  previewTaskId?: string;
  refineTaskId?: string;
  elapsedSeconds?: number;
}

async function runJob(job: AssetJob3D, options: CliOptions): Promise<JobResult> {
  const startedAt = Date.now();
  const label = `${job.category}/${job.id}`;

  if (!options.force && fs.existsSync(job.outputGlbPath)) {
    console.log(`[${label}] skip (already exists; pass --force to regenerate)`);
    return { job, status: "skipped" };
  }

  console.log(`[${label}] start (polycount ${job.polycount}${job.pose ? `, ${job.pose}` : ""})`);

  try {
    const result = await generateModel(job, {
      previewOnly: options.previewOnly,
      cacheGlbPath: job.cacheGlbPath,
    });

    let finalGlb = result.glbBuffer;
    if (options.postprocess) {
      const before = finalGlb.byteLength;
      try {
        finalGlb = await postprocessGlb(finalGlb);
        const after = finalGlb.byteLength;
        const savedPct = ((1 - after / before) * 100).toFixed(1);
        console.log(`[${label}] postprocess ${(before / 1024).toFixed(0)}KB -> ${(after / 1024).toFixed(0)}KB (-${savedPct}%)`);
      } catch (error) {
        console.warn(`[${label}] postprocess failed: ${formatError(error)} — saving raw GLB`);
        finalGlb = result.glbBuffer;
      }
    }

    fs.mkdirSync(path.dirname(job.outputGlbPath), { recursive: true });
    fs.writeFileSync(job.outputGlbPath, finalGlb);

    if (result.thumbBuffer) {
      fs.writeFileSync(job.outputThumbPath, result.thumbBuffer);
    }

    const metadata: AssetMetadata = {
      id: job.id,
      category: job.category,
      prompt: job.prompt,
      polycount_target: job.polycount,
      pose: job.pose,
      provider: "meshy",
      preview_task_id: result.previewTaskId,
      refine_task_id: result.refineTaskId,
      generated_at: new Date().toISOString(),
      glb_bytes: finalGlb.byteLength,
      thumb_path: result.thumbBuffer ? path.basename(job.outputThumbPath) : undefined,
      postprocessed: options.postprocess,
    };
    fs.writeFileSync(job.outputMetaPath, `${JSON.stringify(metadata, null, 2)}\n`);

    const elapsed = ((Date.now() - startedAt) / 1000);
    console.log(`[${label}] done (${elapsed.toFixed(1)}s, ${(finalGlb.byteLength / 1024).toFixed(0)}KB) -> ${relativePath(job.outputGlbPath)}`);

    appendTaskLog({
      event: "asset_saved",
      id: job.id,
      category: job.category,
      bytes: finalGlb.byteLength,
      preview_task_id: result.previewTaskId,
      refine_task_id: result.refineTaskId,
    });

    return {
      job,
      status: "succeeded",
      glbBytes: finalGlb.byteLength,
      previewTaskId: result.previewTaskId,
      refineTaskId: result.refineTaskId,
      elapsedSeconds: elapsed,
    };
  } catch (error) {
    const elapsed = ((Date.now() - startedAt) / 1000);
    const msg = formatError(error);
    console.error(`[${label}] FAILED (${elapsed.toFixed(1)}s): ${msg}`);
    appendTaskLog({ event: "asset_failed", id: job.id, category: job.category, error: msg });
    return { job, status: "failed", error: msg, elapsedSeconds: elapsed };
  }
}

async function main(): Promise<void> {
  const options = parseArgs(process.argv.slice(2));
  const jobs = buildAllJobs(options);

  console.log("Athanor 3D Asset Generator");
  console.log(`Provider: meshy (lowpoly, preview${options.previewOnly ? "" : "+refine"})`);
  console.log(`Concurrency: ${CONCURRENCY}`);
  console.log(`Postprocess: ${options.postprocess ? "weld+dedup+prune+textureCompress(1024)" : "off"}`);
  console.log(`Force: ${options.force}`);
  if (options.category) console.log(`Category: ${options.category}`);
  if (options.only) console.log(`Only: ${options.only.join(", ")}`);
  console.log(`Jobs: ${jobs.length}`);
  console.log("");

  if (jobs.length === 0) {
    console.log("No jobs matched the filters. Exiting.");
    return;
  }

  if (options.dryRun) {
    for (const job of jobs) {
      const exists = fs.existsSync(job.outputGlbPath);
      console.log(
        `  - [${job.category}/${job.id}] polycount=${job.polycount}${job.pose ? ` pose=${job.pose}` : ""}${exists && !options.force ? "  (would skip: exists)" : ""}`,
      );
      console.log(`      prompt: ${job.prompt}`);
      console.log(`      out: ${relativePath(job.outputGlbPath)}`);
    }
    console.log("");
    console.log(`Dry run: ${jobs.length} job(s) planned. No API calls made.`);
    return;
  }

  const pLimitFactory = await loadPLimitFactory();
  const limit = pLimitFactory(CONCURRENCY);

  const results: JobResult[] = await Promise.all(
    jobs.map((job) => limit(() => runJob(job, options))),
  );

  const succeeded = results.filter((r) => r.status === "succeeded").length;
  const skipped = results.filter((r) => r.status === "skipped").length;
  const failed = results.filter((r) => r.status === "failed");

  console.log("");
  console.log(`Summary: ${succeeded} succeeded, ${skipped} skipped, ${failed.length} failed (of ${results.length})`);
  if (failed.length > 0) {
    console.log("");
    console.log("Failures:");
    for (const f of failed) {
      console.log(`  - ${f.job.category}/${f.job.id}: ${f.error}`);
    }
    process.exitCode = 1;
  }
  console.log(`Output: ${relativePath(CLIENT_MODELS_ROOT)}`);
}

main().catch((error) => {
  console.error(`\nFATAL: ${formatError(error)}`);
  process.exit(1);
});
