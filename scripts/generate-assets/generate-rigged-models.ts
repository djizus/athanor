import "./lib/shims.js";
import { mkdir, readFile, writeFile, access } from "fs/promises";
import { constants } from "fs";
import { dirname, resolve } from "path";
import { fileURLToPath } from "url";
import { createFalClient } from "@fal-ai/client";
import { FAL_KEY } from "./lib/env.js";
import {
  rigAndAnimate, downloadToFile, MeshyPoseError,
  createImageTo3D, pollTask, downloadGlb,
} from "./lib/meshy-client.js";
import { mergeAnimationsIntoModel } from "./lib/glb-merge.js";
import { ANIMATION_MAP, RIGGABLE_CHARACTERS, type AnimName } from "./data/animation-map.js";

const fal = createFalClient({ credentials: FAL_KEY });

interface CharacterManifest {
  rigTaskId: string;
  riggedGlbUrl: string;
  walkingGlbUrl: string;
  runningGlbUrl: string;
  animations: Record<string, { taskId: string; glbUrl: string }>;
  mergedGlbPath: string;
  completedAt: string;
}

interface CliOptions {
  dryRun: boolean;
  id?: string;
  force: boolean;
  animsOnly: boolean;
  skipMerge: boolean;
}

function parseArgs(argv: string[]): CliOptions {
  const opts: CliOptions = { dryRun: false, force: false, animsOnly: false, skipMerge: false };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--dry-run") { opts.dryRun = true; continue; }
    if (arg === "--force") { opts.force = true; continue; }
    if (arg === "--anims-only") { opts.animsOnly = true; continue; }
    if (arg === "--skip-merge") { opts.skipMerge = true; continue; }
    if (arg === "--id") { opts.id = argv[++i]; continue; }
    throw new Error(`Unknown argument: ${arg}`);
  }
  return opts;
}

async function exists(p: string): Promise<boolean> {
  try { await access(p, constants.F_OK); return true; } catch { return false; }
}

async function uploadToFalStorage(filePath: string): Promise<string> {
  const buffer = await readFile(filePath);
  const file = new File([buffer], "model.glb", { type: "model/gltf-binary" });
  return fal.storage.upload(file);
}

async function processCharacter(
  char: typeof RIGGABLE_CHARACTERS[number],
  manifest: Record<string, CharacterManifest>,
  dirs: { modelsDir: string; tmpDir: string; conceptsDir: string },
  opts: CliOptions,
): Promise<boolean> {
  const tag = `[${char.id}]`;
  const existing = manifest[char.id];

  if (existing?.completedAt && !opts.force) {
    console.log(`${tag} already completed at ${existing.completedAt}, skipping`);
    return true;
  }

  const sourceGlb = resolve(dirs.modelsDir, char.filename);
  if (!(await exists(sourceGlb))) {
    console.warn(`${tag} source GLB not found: ${sourceGlb}`);
    return false;
  }

  const charTmp = resolve(dirs.tmpDir, char.id);
  await mkdir(charTmp, { recursive: true });

  const animActions = Object.entries(ANIMATION_MAP).map(([name, cfg]) => ({
    name,
    actionId: cfg.actionId,
  }));

  if (opts.dryRun) {
    console.log(`${tag} DRY RUN — would rig + ${animActions.length} animations + walk/run`);
    console.log(`  source: ${sourceGlb}`);
    console.log(`  animations: ${animActions.map(a => `${a.name}(${a.actionId})`).join(", ")}`);
    console.log(`  output: ${sourceGlb} (replaces original)`);
    return true;
  }

  try {
    console.log(`${tag} Uploading GLB to FAL storage...`);
    const publicUrl = await uploadToFalStorage(sourceGlb);
    console.log(`${tag} Public URL: ${publicUrl.substring(0, 80)}...`);

    let result;
    try {
      result = await rigAndAnimate(publicUrl, animActions, char.heightMeters);
    } catch (err) {
      if (err instanceof MeshyPoseError) {
        console.warn(`${tag} Pose estimation failed — regenerating with A-pose...`);
        result = await regenerateAndRig(char, dirs, animActions);
        if (!result) return false;
      } else {
        throw err;
      }
    }

    console.log(`${tag} Downloading rigged GLB + animations...`);
    const riggedPath = resolve(charTmp, "rigged.glb");
    await downloadToFile(result.riggedGlbUrl, riggedPath);

    const animInputs: Array<{ name: string; glbPath: string; loop: boolean }> = [];

    if (result.walkingGlbUrl) {
      const walkPath = resolve(charTmp, "walk.glb");
      await downloadToFile(result.walkingGlbUrl, walkPath);
      animInputs.push({ name: "walk", glbPath: walkPath, loop: true });
    }
    if (result.runningGlbUrl) {
      const runPath = resolve(charTmp, "run.glb");
      await downloadToFile(result.runningGlbUrl, runPath);
      animInputs.push({ name: "run", glbPath: runPath, loop: true });
    }

    for (const [name, data] of Object.entries(result.animations)) {
      const animPath = resolve(charTmp, `${name}.glb`);
      await downloadToFile(data.glbUrl, animPath);
      const cfg = ANIMATION_MAP[name as AnimName];
      animInputs.push({ name, glbPath: animPath, loop: cfg?.loop ?? false });
    }

    if (opts.skipMerge) {
      console.log(`${tag} Skipping merge (--skip-merge). GLBs in ${charTmp}`);
    } else {
      console.log(`${tag} Merging ${animInputs.length} animations into rigged model...`);
      const mergedCount = await mergeAnimationsIntoModel(riggedPath, animInputs, sourceGlb);
      console.log(`${tag} Merged ${mergedCount} animations → ${sourceGlb}`);
    }

    manifest[char.id] = {
      rigTaskId: result.rigTaskId,
      riggedGlbUrl: result.riggedGlbUrl,
      walkingGlbUrl: result.walkingGlbUrl,
      runningGlbUrl: result.runningGlbUrl,
      animations: result.animations,
      mergedGlbPath: sourceGlb,
      completedAt: new Date().toISOString(),
    };

    return true;
  } catch (err: any) {
    console.error(`${tag} FAILED: ${err.message}`);
    return false;
  }
}

async function regenerateAndRig(
  char: typeof RIGGABLE_CHARACTERS[number],
  dirs: { modelsDir: string; tmpDir: string; conceptsDir: string },
  animActions: Array<{ name: string; actionId: number }>,
): Promise<ReturnType<typeof rigAndAnimate> extends Promise<infer T> ? T | null : never> {
  const conceptPath = resolve(dirs.conceptsDir, `${char.id}.png`);
  if (!(await exists(conceptPath))) {
    console.error(`  No concept art for regeneration: ${conceptPath}`);
    return null;
  }
  console.log(`  Uploading concept art for A-pose regeneration...`);
  const conceptBuffer = await readFile(conceptPath);
  const conceptUrl = await fal.storage.upload(new Blob([conceptBuffer], { type: "image/png" }));

  console.log(`  Generating new model with A-pose...`);
  const taskId = await createImageTo3D(conceptUrl, { targetPolycount: 10000, poseMode: "a-pose" });
  const modelResult = await pollTask(taskId);
  const newGlbUrl = modelResult.model_urls?.glb;
  if (!newGlbUrl) { console.error("  No GLB from regeneration"); return null; }

  const newGlbBuffer = await downloadGlb(newGlbUrl);
  const newGlbPath = resolve(dirs.tmpDir, char.id, "regenerated.glb");
  await writeFile(newGlbPath, newGlbBuffer);

  const publicUrl = await fal.storage.upload(new File([newGlbBuffer], "model.glb", { type: "model/gltf-binary" }));
  console.log(`  Retrying rigging with A-pose model...`);
  return rigAndAnimate(publicUrl, animActions, char.heightMeters);
}

async function main(): Promise<void> {
  const opts = parseArgs(process.argv.slice(2));
  const __dirname = dirname(fileURLToPath(import.meta.url));

  const manifestPath = resolve(__dirname, "data", "rigging-tasks.json");
  const modelsDir = resolve(__dirname, "..", "..", "client", "assets", "models");
  const tmpDir = resolve(__dirname, "output", "rigging-tmp");
  const conceptsDir = resolve(__dirname, "output", "concepts");

  await mkdir(tmpDir, { recursive: true });

  let manifest: Record<string, CharacterManifest> = {};
  if (await exists(manifestPath)) {
    manifest = JSON.parse(await readFile(manifestPath, "utf-8"));
  }

  const chars = RIGGABLE_CHARACTERS.filter(c => !opts.id || c.id === opts.id);
  const animCount = Object.keys(ANIMATION_MAP).length;

  console.log(`\n⚙️  Rigging pipeline: ${chars.length} characters × (rig + ${animCount} anims + walk + run)\n`);
  console.log(`   Meshy API: rigging + animation library`);
  console.log(`   Merge: @gltf-transform/core`);
  console.log(`   Output: replaces existing GLBs in client/assets/models/characters/\n`);

  let succeeded = 0, failed = 0;

  for (const char of chars) {
    const ok = await processCharacter(char, manifest, { modelsDir, tmpDir, conceptsDir }, opts);
    if (ok) succeeded++; else failed++;
    await writeFile(manifestPath, JSON.stringify(manifest, null, 2));
  }

  console.log(`\nDone: ${succeeded} succeeded, ${failed} failed`);
}

main().catch((err) => { console.error(err); process.exit(1); });
