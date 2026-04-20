import * as THREE from "three";
import type { GridBundle } from "./grid.js";
import type { SceneBundle } from "./scene.js";

export interface GridClickEvent {
  x: number;
  y: number;
}

export function attachGridInput(
  canvas: HTMLCanvasElement,
  sceneBundle: SceneBundle,
  grid: GridBundle,
  onTileClick: (e: GridClickEvent) => void,
): () => void {
  const pointer = new THREE.Vector2();

  const toNdc = (ev: PointerEvent): THREE.Vector2 => {
    const rect = canvas.getBoundingClientRect();
    pointer.x = ((ev.clientX - rect.left) / rect.width) * 2 - 1;
    pointer.y = -((ev.clientY - rect.top) / rect.height) * 2 + 1;
    return pointer;
  };

  const onPointerDown = (ev: PointerEvent): void => {
    if (ev.button !== 0) return;
    const ndc = toNdc(ev);
    sceneBundle.raycaster.setFromCamera(ndc, sceneBundle.camera);
    const hits = sceneBundle.raycaster.intersectObjects(grid.group.children, false);
    for (const hit of hits) {
      const cell = grid.tileAtHit(hit);
      if (cell) {
        onTileClick(cell);
        return;
      }
    }
  };

  canvas.addEventListener("pointerdown", onPointerDown);
  return () => canvas.removeEventListener("pointerdown", onPointerDown);
}
