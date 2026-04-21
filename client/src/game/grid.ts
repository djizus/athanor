import * as THREE from "three";
import { GRID_HEIGHT, GRID_WIDTH } from "../state/constants.js";
import type { Position } from "../state/combat.js";
import { fitAndGround, instantiateFrom, loadModel } from "./assets.js";
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

// Base slab colors (shown before the GLB loads). Darker than before so the
// painterly tile sits proudly in the frame.
const TILE_BASE_COLOR = 0x1f1f2a;
const TILE_ALT_COLOR = 0x262632;

// Overlay colors are written to a transparent quad on top of each tile. They
// read as painted auras on top of the Meshy-generated tile surfaces.
const TILE_MOVE_RANGE_COLOR = 0x2f8f49;
const TILE_ABILITY_RANGE_COLOR = 0x6e3fcc;
const TILE_SELECTED_COLOR = 0xc89a2f;
const TILE_DANGER_COLOR = 0xa62929;
const TILE_DANGER_MOVE_COLOR = 0x6f4e1f;
const TILE_DANGER_ABILITY_COLOR = 0x8d2e6b;
export const TILE_FLASH_HIT_COLOR = 0xb5d94c;
export const TILE_FLASH_BAD_COLOR = 0xbe3131;

const TILE_OVERLAY_ALPHA = 0.55;
const TILE_FLASH_ALPHA = 0.85;
const TILE_OVERLAY_Y = 0.18; // tint quad hovers just above the slab top

const TILE_MODEL_URLS = [
  "/models/tiles/tile-grass-a.glb",
  "/models/tiles/tile-grass-b.glb",
] as const;
const TILE_MODEL_HEIGHT = 0.55; // world units (slab is 0.2; leaves headroom for actors)

const tileKey = (x: number, y: number): string => `${x},${y}`;

interface TileCell {
  base: THREE.Mesh; // raycast + fallback slab
  tint: THREE.Mesh; // flat semi-transparent quad for overlays
  tintMat: THREE.MeshBasicMaterial;
  model: THREE.Group | null;
}

/**
 * Deterministic tile variant picker. Keeps the per-cell distribution stable
 * across renders so we don't reshuffle the world on every re-entry.
 */
function pickTileVariant(x: number, y: number): number {
  return (x * 31 + y * 17) % TILE_MODEL_URLS.length;
}

function noopRaycast(): void {
  // Prevents the GLB visual mesh from being hit by the tile raycaster.
  // The base slab remains the canonical hit target.
}

export function createGrid(scene: THREE.Scene): GridBundle {
  const group = new THREE.Group();
  scene.add(group);

  const slabGeometry = new THREE.BoxGeometry(TILE_SIZE * 0.96, 0.16, TILE_SIZE * 0.96);
  const overlayGeometry = new THREE.PlaneGeometry(TILE_SIZE * 0.92, TILE_SIZE * 0.92);

  const tiles: THREE.Mesh[][] = [];
  const cells: TileCell[][] = [];

  for (let y = 0; y < GRID_HEIGHT; y++) {
    const row: THREE.Mesh[] = [];
    const cellRow: TileCell[] = [];
    for (let x = 0; x < GRID_WIDTH; x++) {
      const alt = (x + y) % 2 === 0;
      const color = alt ? TILE_BASE_COLOR : TILE_ALT_COLOR;
      const material = new THREE.MeshStandardMaterial({ color, roughness: 0.95 });
      const slab = new THREE.Mesh(slabGeometry, material);
      slab.position.set(x * TILE_SIZE, 0.08, y * TILE_SIZE);
      slab.userData = { gridX: x, gridY: y };
      group.add(slab);
      row.push(slab);

      const tintMat = new THREE.MeshBasicMaterial({
        color: 0xffffff,
        transparent: true,
        opacity: 0,
        depthWrite: false,
      });
      const tint = new THREE.Mesh(overlayGeometry, tintMat);
      tint.rotation.x = -Math.PI / 2;
      tint.position.set(x * TILE_SIZE, TILE_OVERLAY_Y, y * TILE_SIZE);
      tint.renderOrder = 2;
      tint.raycast = noopRaycast;
      group.add(tint);

      cellRow.push({ base: slab, tint, tintMat, model: null });
    }
    tiles.push(row);
    cells.push(cellRow);
  }

  // Async: swap the slab for a Meshy-generated painterly tile chunk. If the
  // GLB fails to load we just keep the dark slab (still playable).
  const pendingVariants = new Map<number, Promise<THREE.Group>>();
  for (let i = 0; i < TILE_MODEL_URLS.length; i++) {
    const url = TILE_MODEL_URLS[i]!;
    pendingVariants.set(i, loadModel(url));
  }

  for (let y = 0; y < GRID_HEIGHT; y++) {
    for (let x = 0; x < GRID_WIDTH; x++) {
      const variantId = pickTileVariant(x, y);
      const promise = pendingVariants.get(variantId);
      if (!promise) continue;
      const cell = cells[y]![x]!;
      const cx = x;
      const cy = y;
      promise
        .then((source) => {
          const model = instantiateFrom(source);
          fitAndGround(model, TILE_MODEL_HEIGHT);
          // Ground to slab top so the tile visually rests on its slab.
          model.position.x += cx * TILE_SIZE;
          model.position.z += cy * TILE_SIZE;
          // Random 90-degree Y rotation for layout variety.
          const rot = Math.PI * 0.5 * ((cx * 7 + cy * 3) % 4);
          model.rotation.y = rot;
          // Ensure GLB children never steal raycasts from the base slab.
          model.traverse((obj) => {
            (obj as THREE.Object3D).raycast = noopRaycast;
          });
          group.add(model);
          cell.model = model;
          // Once the painterly tile is in, darken the base slab further so it
          // reads as the "void" shadow under the floating chunk, not a tile.
          const mat = cell.base.material as THREE.MeshStandardMaterial;
          mat.color.setHex(0x070711);
          mat.roughness = 1;
        })
        .catch((err) => {
          console.warn(`[grid] tile variant ${variantId} failed to load:`, err);
        });
    }
  }

  let moveRange = new Set<string>();
  let abilityRange = new Set<string>();
  let danger = new Set<string>();
  let selected = new Set<string>();
  const flashes = new Map<string, { color: number; expiresAt: number }>();

  const cellAt = (x: number, y: number): TileCell | null => cells[y]?.[x] ?? null;

  interface Overlay {
    color: number | null;
    alpha: number;
  }

  const overlayFor = (x: number, y: number, now: number): Overlay => {
    const k = tileKey(x, y);
    const flash = flashes.get(k);
    if (flash && flash.expiresAt > now) return { color: flash.color, alpha: TILE_FLASH_ALPHA };
    const isMove = moveRange.has(k);
    const isAbility = abilityRange.has(k);
    const isDanger = danger.has(k);
    const isSelected = selected.has(k);
    if (isSelected) return { color: TILE_SELECTED_COLOR, alpha: TILE_OVERLAY_ALPHA };
    if (isDanger && isAbility) return { color: TILE_DANGER_ABILITY_COLOR, alpha: TILE_OVERLAY_ALPHA };
    if (isDanger && isMove) return { color: TILE_DANGER_MOVE_COLOR, alpha: TILE_OVERLAY_ALPHA };
    if (isDanger) return { color: TILE_DANGER_COLOR, alpha: TILE_OVERLAY_ALPHA };
    if (isAbility) return { color: TILE_ABILITY_RANGE_COLOR, alpha: TILE_OVERLAY_ALPHA };
    if (isMove) return { color: TILE_MOVE_RANGE_COLOR, alpha: TILE_OVERLAY_ALPHA };
    return { color: null, alpha: 0 };
  };

  const redraw = (): void => {
    const now = performance.now();
    for (let y = 0; y < GRID_HEIGHT; y++) {
      for (let x = 0; x < GRID_WIDTH; x++) {
        const cell = cellAt(x, y);
        if (!cell) continue;
        const o = overlayFor(x, y, now);
        if (o.color === null || o.alpha === 0) {
          cell.tintMat.opacity = 0;
        } else {
          cell.tintMat.color.setHex(o.color);
          cell.tintMat.opacity = o.alpha;
        }
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
