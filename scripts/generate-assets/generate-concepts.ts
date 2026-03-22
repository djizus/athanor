import { mkdir, readFile, writeFile, access } from "fs/promises";
import { constants } from "fs";
import { dirname, resolve } from "path";
import { fileURLToPath } from "url";
import sharp from "sharp";
import { REQUEST_DELAY_MS } from "./lib/env.js";
import { downloadImage, generateImage } from "./lib/fal-client.js";

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

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

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

function conceptPrompt(description: string): string {
  return `${description}. Isometric 3/4 view, single object centered on pure white background #FFFFFF.\nLow-poly stylized game asset reference. Clean silhouette, no ground plane, no shadows, no other objects.\nDark fantasy with bioluminescent energy accents.`;
}

async function main(): Promise<void> {
  const options = parseArgs(process.argv.slice(2));
  const __dirname = dirname(fileURLToPath(import.meta.url));

  const manifestPath = resolve(__dirname, "data", "models-3d.json");
  const conceptsDir = resolve(__dirname, "output", "concepts");

  const raw = await readFile(manifestPath, "utf-8");
  const allAssets = JSON.parse(raw) as AssetDef[];

  const filtered = allAssets.filter((asset) => {
    if (options.id && asset.id !== options.id) return false;
    if (options.category && asset.category !== options.category) return false;
    return true;
  });

  await mkdir(conceptsDir, { recursive: true });

  console.log(`Generating concept art for ${filtered.length} assets...`);
  for (let i = 0; i < filtered.length; i++) {
    const asset = filtered[i];
    const outPath = resolve(conceptsDir, `${asset.id}.png`);

    if (!options.force && (await exists(outPath))) {
      console.log(`[${i + 1}/${filtered.length}] ${asset.id} -> exists, skipping`);
      continue;
    }

    const prompt = conceptPrompt(asset.description);
    if (options.dryRun) {
      console.log(`[${i + 1}/${filtered.length}] DRY RUN ${asset.id}`);
      console.log(`  ${prompt}`);
      continue;
    }

    console.log(`[${i + 1}/${filtered.length}] Generating ${asset.id}...`);
    const generated = await generateImage(prompt, 1024, 1024);
    const sourceBuffer = await downloadImage(generated.url);
    const pngBuffer = await sharp(sourceBuffer).png().toBuffer();
    await writeFile(outPath, pngBuffer);
    console.log(`  Saved ${outPath}`);

    if (i < filtered.length - 1) {
      await sleep(REQUEST_DELAY_MS);
    }
  }

  console.log("Concept generation complete.");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
