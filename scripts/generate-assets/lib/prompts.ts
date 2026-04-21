import fs from "node:fs";
import path from "node:path";
import type { StyleData } from "./types.js";

const DATA_DIR = path.join(path.dirname(new URL(import.meta.url).pathname), "..", "data");

let cachedStyle: StyleData | null = null;

export function loadStyle(): StyleData {
  if (cachedStyle) return cachedStyle;
  const stylePath = path.join(DATA_DIR, "style.json");
  cachedStyle = JSON.parse(fs.readFileSync(stylePath, "utf-8")) as StyleData;
  return cachedStyle;
}

function withStyle(basePrompt: string): string {
  const { suffix } = loadStyle();
  return `${basePrompt.trim()}. ${suffix.trim()}`;
}

export function buildTilePrompt(basePrompt: string): string {
  return withStyle(basePrompt);
}

export function buildObstaclePrompt(basePrompt: string): string {
  return withStyle(basePrompt);
}

export function buildCharacterPrompt(basePrompt: string): string {
  return withStyle(basePrompt);
}
