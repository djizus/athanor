import "./lib/shims.js";
import { mkdir, readFile, writeFile, access, copyFile } from "fs/promises";
import { constants } from "fs";
import { dirname, resolve } from "path";
import { fileURLToPath } from "url";
import { createFalClient } from "@fal-ai/client";
import { FAL_KEY } from "./lib/env.js";
import { generateModel } from "./lib/meshy-client.js";

const fal = createFalClient({ credentials: FAL_KEY });

type AssetCategory = "character" | "prop" | "floor";

interface AssetDef {
  id: string;
  category: AssetCategory;
  zone: number | null;
  filename: string;
  description: string;
  targetTris: number;
}

interface CliOptions {
  dryRun: boolean;
  id?: string;
  category?: AssetCategory;
  force: boolean;
}

function parseArgs(argv: string[]): CliOptions {
  const options: CliOptions = { dryRun: false, force: false };

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--dry-run") {
      options.dryRun = true;
      continue;
    }
    if (arg === "--force") {
      options.force = true;
      continue;
    }
    if (arg === "--id") {
      options.id = argv[++i];
      continue;
    }
    if (arg === "--category") {
      const value = argv[++i] as AssetCategory;
      if (value !== "character" && value !== "prop" && value !== "floor") {
        throw new Error(`Invalid --category value: ${value}`);
      }
      options.category = value;
      continue;
    }
    throw new Error(`Unknown argument: ${arg}`);
  }

  return options;
}

async function exists(filePath: string): Promise<boolean> {
  try {
    await access(filePath, constants.F_OK);
    return true;
  } catch {
    return false;
  }
}

async function main(): Promise<void> {
  const options = parseArgs(process.argv.slice(2));
  const __dirname = dirname(fileURLToPath(import.meta.url));

  const manifestPath = resolve(__dirname, "data", "models-3d.json");
  const conceptsDir = resolve(__dirname, "output", "concepts");
  const rawDir = resolve(__dirname, "output", "raw");
  const finalModelsDir = resolve(__dirname, "..", "..", "client", "assets", "models");

  const raw = await readFile(manifestPath, "utf-8");
  const allAssets = JSON.parse(raw) as AssetDef[];
  const filtered = allAssets.filter((asset) => {
    if (options.id && asset.id !== options.id) return false;
    if (options.category && asset.category !== options.category) return false;
    return true;
  });

  await mkdir(rawDir, { recursive: true });

  console.log(`Generating 3D models for ${filtered.length} assets...`);
  for (let i = 0; i < filtered.length; i++) {
    const asset = filtered[i];
    const conceptPath = resolve(conceptsDir, `${asset.id}.png`);
    const rawGlbPath = resolve(rawDir, `${asset.id}.glb`);
    const finalGlbPath = resolve(finalModelsDir, asset.filename);

    if (!(await exists(conceptPath))) {
      console.warn(`[${i + 1}/${filtered.length}] ${asset.id} -> concept missing, skipping`);
      continue;
    }

    if (!options.force && (await exists(rawGlbPath))) {
      console.log(`[${i + 1}/${filtered.length}] ${asset.id} -> raw GLB exists, skipping`);
      continue;
    }

    if (options.dryRun) {
      console.log(`[${i + 1}/${filtered.length}] DRY RUN ${asset.id}`);
      console.log(`  concept: ${conceptPath}`);
      console.log(`  raw:     ${rawGlbPath}`);
      console.log(`  final:   ${finalGlbPath}`);
      continue;
    }

    console.log(`[${i + 1}/${filtered.length}] Generating model ${asset.id}...`);
    const conceptBuffer = await readFile(conceptPath);
    const uploadedUrl = await fal.storage.upload(new Blob([conceptBuffer], { type: "image/png" }));
    const glbBuffer = await generateModel(uploadedUrl, {
      targetPolycount: asset.targetTris,
      topology: "quad",
    });

    await writeFile(rawGlbPath, glbBuffer);
    await mkdir(dirname(finalGlbPath), { recursive: true });
    await copyFile(rawGlbPath, finalGlbPath);

    console.log(`  Saved raw:   ${rawGlbPath}`);
    console.log(`  Saved final: ${finalGlbPath}`);
  }

  console.log("Model generation complete.");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
