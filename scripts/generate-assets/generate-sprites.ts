import "./lib/shims.js";
import { mkdir, readFile, writeFile, access } from "fs/promises";
import { constants } from "fs";
import { dirname, resolve } from "path";
import { fileURLToPath } from "url";
import sharp from "sharp";
import { generateSpriteSheet, removeBackgroundAI, downloadImage } from "./lib/fal-client.js";

interface AnimationDef {
  name: string;
  row: number;
  choreography: string;
}

interface CharacterDef {
  id: string;
  gridSize: number;
  basePrompt: string;
  animations: AnimationDef[];
}

interface SpriteManifest {
  outputDir: string;
  resolution: string;
  characters: CharacterDef[];
}

interface CliOptions {
  dryRun: boolean;
  character?: string;
  force: boolean;
  skipBgRemoval: boolean;
}

const NUM_WORDS: Record<number, string> = { 2: "two", 3: "three", 4: "four", 5: "five", 6: "six" };

function parseArgs(argv: string[]): CliOptions {
  const opts: CliOptions = { dryRun: false, force: false, skipBgRemoval: false };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--dry-run") { opts.dryRun = true; continue; }
    if (arg === "--force") { opts.force = true; continue; }
    if (arg === "--no-rembg") { opts.skipBgRemoval = true; continue; }
    if (arg === "--character") { opts.character = argv[++i]; continue; }
    throw new Error(`Unknown argument: ${arg}`);
  }
  return opts;
}

async function exists(filePath: string): Promise<boolean> {
  try { await access(filePath, constants.F_OK); return true; } catch { return false; }
}

function buildGridPrompt(character: CharacterDef): string {
  const g = character.gridSize;
  const w = NUM_WORDS[g] || String(g);
  const animRows = character.animations
    .reduce((acc, a) => {
      if (!acc[a.row]) acc[a.row] = [];
      acc[a.row].push(a);
      return acc;
    }, {} as Record<number, AnimationDef[]>);

  const rowDescriptions: string[] = [];
  for (let r = 0; r < g; r++) {
    const anims = animRows[r] || [];
    const desc = anims.map(a => `${a.name}: ${a.choreography}`).join(". ");
    rowDescriptions.push(`Row ${r + 1}: ${desc}`);
  }

  return [
    "STRICT TECHNICAL REQUIREMENTS FOR THIS IMAGE:",
    "",
    `FORMAT: A single image containing a ${w}-by-${w} grid of equally sized cells.`,
    "Every cell must be the exact same dimensions, perfectly aligned, with no gaps or overlap.",
    "",
    "FORBIDDEN: Absolutely no text, no numbers, no letters, no digits, no labels,",
    "no watermarks, no signatures, no UI elements anywhere in the image. The image must",
    "contain ONLY the character illustrations in the grid cells and nothing else.",
    "",
    "CONSISTENCY: The exact same single character must appear in every cell.",
    "Same proportions, same art style, same level of detail, same camera angle throughout.",
    "Isometric three-quarter view. Full body visible head to toe in every cell.",
    "Strong clean silhouette against a plain solid white background.",
    "",
    "ANIMATION FLOW: The cells read left-to-right, top-to-bottom.",
    "Each row is a distinct animation sequence for the same character.",
    rowDescriptions.join("\n"),
    "",
    "MOTION QUALITY: Show real weight and physics. Bodies shift weight between feet.",
    "Arms counterbalance legs. Torsos rotate into actions. Follow-through on every movement.",
    "No stiff poses. Every cell must feel like a freeze-frame of fluid motion.",
    "",
    "CHARACTER:",
    character.basePrompt,
  ].join("\n");
}

function getExpectedFrames(character: CharacterDef): Array<{ animation: string; frame: number; col: number; row: number }> {
  const g = character.gridSize;
  const frames: Array<{ animation: string; frame: number; col: number; row: number }> = [];

  const rowAnims: Record<number, AnimationDef[]> = {};
  for (const a of character.animations) {
    if (!rowAnims[a.row]) rowAnims[a.row] = [];
    rowAnims[a.row].push(a);
  }

  for (let r = 0; r < g; r++) {
    const anims = rowAnims[r] || [];
    if (anims.length === 0) continue;
    const colsPerAnim = Math.floor(g / anims.length);
    let col = 0;
    for (const anim of anims) {
      for (let f = 0; f < colsPerAnim; f++) {
        frames.push({ animation: anim.name, frame: f, col, row: r });
        col++;
      }
    }
  }

  return frames;
}

async function sliceGrid(imageBuffer: Buffer, gridSize: number): Promise<Buffer[]> {
  const meta = await sharp(imageBuffer).metadata();
  const w = meta.width!;
  const h = meta.height!;
  const cellW = Math.floor(w / gridSize);
  const cellH = Math.floor(h / gridSize);

  const cells: Buffer[] = [];
  for (let r = 0; r < gridSize; r++) {
    for (let c = 0; c < gridSize; c++) {
      const cell = await sharp(imageBuffer)
        .extract({ left: c * cellW, top: r * cellH, width: cellW, height: cellH })
        .png()
        .toBuffer();
      cells.push(cell);
    }
  }
  return cells;
}

async function processCharacter(
  character: CharacterDef,
  assetsDir: string,
  rawDir: string,
  manifest: SpriteManifest,
  opts: CliOptions,
): Promise<{ generated: number; skipped: number; failed: number }> {
  const tag = `[${character.id}]`;
  const outDir = resolve(assetsDir, manifest.outputDir, character.id);
  const expectedFrames = getExpectedFrames(character);

  const allExist = !opts.force && (await Promise.all(
    expectedFrames.map(f => exists(resolve(outDir, `${character.id}_${f.animation}_${f.frame}.png`)))
  )).every(Boolean);

  if (allExist) {
    console.log(`${tag} all ${expectedFrames.length} frames exist, skipping`);
    return { generated: 0, skipped: expectedFrames.length, failed: 0 };
  }

  const prompt = buildGridPrompt(character);

  if (opts.dryRun) {
    console.log(`${tag} DRY RUN — ${character.gridSize}x${character.gridSize} grid (${expectedFrames.length} frames)`);
    console.log(`  prompt: ${prompt.substring(0, 200)}...`);
    console.log(`  frames: ${expectedFrames.map(f => `${f.animation}_${f.frame}`).join(", ")}`);
    return { generated: 0, skipped: expectedFrames.length, failed: 0 };
  }

  try {
    console.log(`${tag} generating ${character.gridSize}x${character.gridSize} sprite sheet...`);
    const sheetResult = await generateSpriteSheet(prompt, manifest.resolution as any);
    console.log(`${tag} sheet generated: ${sheetResult.url.substring(0, 80)}...`);

    let sheetUrl = sheetResult.url;

    if (!opts.skipBgRemoval) {
      console.log(`${tag} removing background via BiRefNet...`);
      sheetUrl = await removeBackgroundAI(sheetUrl);
      console.log(`${tag} background removed`);
    }

    const sheetBuffer = await downloadImage(sheetUrl);

    const rawPath = resolve(rawDir, `${character.id}_sheet.png`);
    await mkdir(dirname(rawPath), { recursive: true });
    await writeFile(rawPath, sheetBuffer);
    console.log(`${tag} raw sheet saved: ${rawPath}`);

    console.log(`${tag} slicing ${character.gridSize}x${character.gridSize} grid into ${expectedFrames.length} frames...`);
    const cells = await sliceGrid(sheetBuffer, character.gridSize);

    await mkdir(outDir, { recursive: true });
    let saved = 0;
    for (const frame of expectedFrames) {
      const cellIndex = frame.row * character.gridSize + frame.col;
      if (cellIndex >= cells.length) {
        console.warn(`${tag} cell ${cellIndex} out of range for ${frame.animation}_${frame.frame}`);
        continue;
      }
      const outPath = resolve(outDir, `${character.id}_${frame.animation}_${frame.frame}.png`);
      await writeFile(outPath, cells[cellIndex]);
      saved++;
    }
    console.log(`${tag} saved ${saved} frames to ${outDir}`);

    return { generated: saved, skipped: 0, failed: 0 };
  } catch (err: any) {
    console.error(`${tag} FAILED: ${err.message}`);
    return { generated: 0, skipped: 0, failed: expectedFrames.length };
  }
}

async function main(): Promise<void> {
  const opts = parseArgs(process.argv.slice(2));
  const __dirname = dirname(fileURLToPath(import.meta.url));

  const manifestPath = resolve(__dirname, "data", "sprites-2d.json");
  const assetsDir = resolve(__dirname, "..", "..", "client", "assets");
  const rawDir = resolve(__dirname, "output", "sprites-raw");

  const manifest = JSON.parse(await readFile(manifestPath, "utf-8")) as SpriteManifest;

  const characters = manifest.characters.filter(c => !opts.character || c.id === opts.character);
  const totalFrames = characters.reduce((sum, c) => sum + getExpectedFrames(c).length, 0);

  console.log(`\n🎨 Sprite sheet pipeline: ${characters.length} characters, ${totalFrames} total frames\n`);
  console.log(`   Model: fal-ai/nano-banana-2 (grid sheet) + fal-ai/birefnet/v2 (bg removal)`);
  console.log(`   Resolution: ${manifest.resolution}`);
  console.log(`   Background removal: ${opts.skipBgRemoval ? "DISABLED" : "ENABLED (BiRefNet)"}\n`);

  let totalGen = 0, totalSkip = 0, totalFail = 0;

  for (const character of characters) {
    const result = await processCharacter(character, assetsDir, rawDir, manifest, opts);
    totalGen += result.generated;
    totalSkip += result.skipped;
    totalFail += result.failed;
  }

  console.log(`\nDone: ${totalGen} generated, ${totalSkip} skipped, ${totalFail} failed`);
}

main().catch((err) => { console.error(err); process.exit(1); });
