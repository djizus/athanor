import * as THREE from "three";
import { GRID_HEIGHT, GRID_WIDTH } from "../state/constants.js";
import type { Position } from "../state/combat.js";
import { TILE_SIZE } from "./scene.js";

export interface GridBundle {
  group: THREE.Group;
  tiles: THREE.Mesh[][];
  setReachable: (tiles: Position[]) => void;
  setDanger: (tiles: Position[]) => void;
  flash: (tiles: Position[], color: number, durationMs?: number) => void;
  clearOverlays: () => void;
  tileAtHit: (intersect: THREE.Intersection) => Position | null;
}

const TILE_BASE_COLOR = 0x2a2a36;
const TILE_ALT_COLOR = 0x32323f;
const TILE_REACHABLE_COLOR = 0x2e4f6d;
const TILE_DANGER_COLOR = 0x6a2020;
const TILE_DANGER_REACHABLE_COLOR = 0x7a3540; // overlap: both reachable and danger
export const TILE_FLASH_HIT_COLOR = 0x8fbf4f;
export const TILE_FLASH_BAD_COLOR = 0x7a1f1f;

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

  let reachable = new Set<string>();
  let danger = new Set<string>();
  const flashes = new Map<string, { color: number; expiresAt: number }>();

  const tileAt = (x: number, y: number): THREE.Mesh | null => tiles[y]?.[x] ?? null;

  const colorFor = (x: number, y: number, now: number): number => {
    const k = tileKey(x, y);
    const flash = flashes.get(k);
    if (flash && flash.expiresAt > now) return flash.color;
    const isReach = reachable.has(k);
    const isDanger = danger.has(k);
    if (isDanger && isReach) return TILE_DANGER_REACHABLE_COLOR;
    if (isDanger) return TILE_DANGER_COLOR;
    if (isReach) return TILE_REACHABLE_COLOR;
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

  const setReachable = (positions: Position[]): void => {
    reachable = new Set(positions.map((p) => tileKey(p.x, p.y)));
    redraw();
  };

  const setDanger = (positions: Position[]): void => {
    danger = new Set(positions.map((p) => tileKey(p.x, p.y)));
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
    reachable.clear();
    danger.clear();
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

  return { group, tiles, setReachable, setDanger, flash, clearOverlays, tileAtHit };
}
