import * as THREE from "three";
import { GRID_HEIGHT, GRID_WIDTH } from "../state/constants.js";
import { TILE_SIZE } from "./scene.js";

export interface GridBundle {
  group: THREE.Group;
  tiles: THREE.Mesh[][];
  highlight: (coords: Array<{ x: number; y: number }>, color: number) => void;
  clearHighlight: () => void;
  tileAtHit: (intersect: THREE.Intersection) => { x: number; y: number } | null;
}

const TILE_BASE_COLOR = 0x2a2a36;
const TILE_ALT_COLOR = 0x32323f;
const TILE_HIGHLIGHT_COLOR = 0x3e6b8a;

export function createGrid(scene: THREE.Scene): GridBundle {
  const group = new THREE.Group();
  scene.add(group);

  const geometry = new THREE.BoxGeometry(TILE_SIZE * 0.96, 0.1, TILE_SIZE * 0.96);
  const tiles: THREE.Mesh[][] = [];
  const baseColors = new Map<THREE.Mesh, number>();

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
      baseColors.set(mesh, color);
    }
    tiles.push(row);
  }

  const highlighted = new Set<THREE.Mesh>();

  const highlight = (coords: Array<{ x: number; y: number }>, color: number): void => {
    clearHighlight();
    for (const c of coords) {
      const mesh = tiles[c.y]?.[c.x];
      if (!mesh) continue;
      (mesh.material as THREE.MeshStandardMaterial).color.setHex(color);
      highlighted.add(mesh);
    }
  };

  const clearHighlight = (): void => {
    for (const mesh of highlighted) {
      const base = baseColors.get(mesh);
      if (base !== undefined) {
        (mesh.material as THREE.MeshStandardMaterial).color.setHex(base);
      }
    }
    highlighted.clear();
  };

  const tileAtHit = (intersect: THREE.Intersection): { x: number; y: number } | null => {
    const obj = intersect.object as THREE.Mesh;
    if (typeof obj.userData.gridX !== "number" || typeof obj.userData.gridY !== "number") {
      return null;
    }
    return { x: obj.userData.gridX, y: obj.userData.gridY };
  };

  return { group, tiles, highlight, clearHighlight, tileAtHit };
}

export const GRID_TILE_HIGHLIGHT_COLOR = TILE_HIGHLIGHT_COLOR;
