import * as THREE from "three";
import { GRID_HEIGHT, GRID_WIDTH } from "../state/constants.js";
import type { Position } from "../state/combat.js";
import { TILE_SIZE } from "./scene.js";

export interface GridBundle {
  group: THREE.Group;
  tiles: THREE.Mesh[][];
  setMoveRange: (tiles: Position[]) => void;
  setAbilityRange: (tiles: Position[]) => void;
  setDanger: (tiles: Position[]) => void;
  setSelected: (tiles: Position[]) => void;
  flash: (tiles: Position[], color: number, durationMs?: number) => void;
  clearOverlays: () => void;
  tileAtHit: (intersect: THREE.Intersection) => Position | null;
}

const TILE_BASE_COLOR = 0x2a2a36;
const TILE_ALT_COLOR = 0x32323f;
const TILE_MOVE_RANGE_COLOR = 0x2f8f49;
const TILE_ABILITY_RANGE_COLOR = 0x6e3fcc;
const TILE_SELECTED_COLOR = 0xc89a2f;
const TILE_DANGER_COLOR = 0xa62929;
const TILE_DANGER_MOVE_COLOR = 0x6f4e1f;
const TILE_DANGER_ABILITY_COLOR = 0x8d2e6b;
export const TILE_FLASH_HIT_COLOR = 0xb5d94c;
export const TILE_FLASH_BAD_COLOR = 0xbe3131;

const tileKey = (x: number, y: number): string => `${x},${y}`;

export function createGrid(scene: THREE.Scene): GridBundle {
  const group = new THREE.Group();
  scene.add(group);

  const geometry = new THREE.BoxGeometry(TILE_SIZE * 0.96, 0.1, TILE_SIZE * 0.96);
  const tiles: THREE.Mesh[][] = [];
  const baseColors = new Map<string, number>();

  for (let y = 0; y < GRID_HEIGHT; y++) {
    const row: THREE.Mesh[] = [];
    for (let x = 0; x < GRID_WIDTH; x++) {
      const alt = (x + y) % 2 === 0;
      const color = alt ? TILE_BASE_COLOR : TILE_ALT_COLOR;
      const material = new THREE.MeshStandardMaterial({ color, roughness: 0.9 });
      const mesh = new THREE.Mesh(geometry, material);
      mesh.position.set(x * TILE_SIZE, 0, y * TILE_SIZE);
      mesh.userData = { gridX: x, gridY: y };
      group.add(mesh);
      row.push(mesh);
      baseColors.set(tileKey(x, y), color);
    }
    tiles.push(row);
  }

  let moveRange = new Set<string>();
  let abilityRange = new Set<string>();
  let danger = new Set<string>();
  let selected = new Set<string>();
  const flashes = new Map<string, { color: number; expiresAt: number }>();

  const tileAt = (x: number, y: number): THREE.Mesh | null => tiles[y]?.[x] ?? null;

  const colorFor = (x: number, y: number, now: number): number => {
    const k = tileKey(x, y);
    const flash = flashes.get(k);
    if (flash && flash.expiresAt > now) return flash.color;
    const isMove = moveRange.has(k);
    const isAbility = abilityRange.has(k);
    const isDanger = danger.has(k);
    const isSelected = selected.has(k);
    if (isSelected) return TILE_SELECTED_COLOR;
    if (isDanger && isAbility) return TILE_DANGER_ABILITY_COLOR;
    if (isDanger && isMove) return TILE_DANGER_MOVE_COLOR;
    if (isDanger) return TILE_DANGER_COLOR;
    if (isAbility) return TILE_ABILITY_RANGE_COLOR;
    if (isMove) return TILE_MOVE_RANGE_COLOR;
    return baseColors.get(k) ?? TILE_BASE_COLOR;
  };

  const redraw = (): void => {
    const now = performance.now();
    for (let y = 0; y < GRID_HEIGHT; y++) {
      for (let x = 0; x < GRID_WIDTH; x++) {
        const mesh = tileAt(x, y);
        if (!mesh) continue;
        (mesh.material as THREE.MeshStandardMaterial).color.setHex(colorFor(x, y, now));
      }
    }
  };

  const setMoveRange = (positions: Position[]): void => {
    moveRange = new Set(positions.map((p) => tileKey(p.x, p.y)));
    redraw();
  };

  const setAbilityRange = (positions: Position[]): void => {
    abilityRange = new Set(positions.map((p) => tileKey(p.x, p.y)));
    redraw();
  };

  const setDanger = (positions: Position[]): void => {
    danger = new Set(positions.map((p) => tileKey(p.x, p.y)));
    redraw();
  };

  const setSelected = (positions: Position[]): void => {
    selected = new Set(positions.map((p) => tileKey(p.x, p.y)));
    redraw();
  };

  const flash = (positions: Position[], color: number, durationMs: number = 200): void => {
    const expiresAt = performance.now() + durationMs;
    for (const p of positions) {
      flashes.set(tileKey(p.x, p.y), { color, expiresAt });
    }
    redraw();
    window.setTimeout(() => {
      const now = performance.now();
      for (const [k, entry] of flashes) {
        if (entry.expiresAt <= now) flashes.delete(k);
      }
      redraw();
    }, durationMs + 10);
  };

  const clearOverlays = (): void => {
    moveRange.clear();
    abilityRange.clear();
    danger.clear();
    selected.clear();
    flashes.clear();
    redraw();
  };

  const tileAtHit = (intersect: THREE.Intersection): Position | null => {
    const obj = intersect.object as THREE.Mesh;
    if (typeof obj.userData.gridX !== "number" || typeof obj.userData.gridY !== "number") {
      return null;
    }
    return { x: obj.userData.gridX, y: obj.userData.gridY };
  };

  return {
    group,
    tiles,
    setMoveRange,
    setAbilityRange,
    setDanger,
    setSelected,
    flash,
    clearOverlays,
    tileAtHit,
  };
}
