import * as THREE from "three";
import type { Position } from "../state/combat.js";
import { fitAndGround, instantiateFrom, loadModel } from "./assets.js";
import { TILE_SIZE } from "./scene.js";

const OBSTACLE_COLOR = 0x4a3a2a;
const OBSTACLE_HEIGHT = 0.9;

const OBSTACLE_MODEL_URLS = [
  "/models/obstacles/obstacle-rock.glb",
  "/models/obstacles/obstacle-crystal.glb",
] as const;
const OBSTACLE_MODEL_HEIGHT = 0.85; // world units

export interface ObstacleBundle {
  group: THREE.Group;
  sync: (positions: Position[]) => void;
  dispose: () => void;
}

// Cache loaded GLBs (or mark them as unavailable once we know) so repeated
// sync() calls don't re-request models that already failed.
const modelStatus = new Map<string, "loading" | "ready" | "missing">();
const modelSources = new Map<string, THREE.Group>();

function preloadObstacleModels(): void {
  for (const url of OBSTACLE_MODEL_URLS) {
    if (modelStatus.has(url)) continue;
    modelStatus.set(url, "loading");
    loadModel(url)
      .then((source) => {
        modelSources.set(url, source);
        modelStatus.set(url, "ready");
      })
      .catch(() => {
        modelStatus.set(url, "missing");
      });
  }
}

function pickObstacleUrl(x: number, y: number): string | null {
  // Deterministic pick so obstacle identities stay stable on re-render.
  const readyUrls = OBSTACLE_MODEL_URLS.filter((u) => modelStatus.get(u) === "ready");
  if (readyUrls.length === 0) return null;
  const idx = (x * 13 + y * 7) % readyUrls.length;
  return readyUrls[idx] ?? null;
}

function noopRaycast(): void {}

export function createObstacles(scene: THREE.Scene, positions: Position[]): ObstacleBundle {
  preloadObstacleModels();

  const group = new THREE.Group();
  scene.add(group);

  const cubeGeom = new THREE.BoxGeometry(TILE_SIZE * 0.88, OBSTACLE_HEIGHT, TILE_SIZE * 0.88);
  const cubeMat = new THREE.MeshStandardMaterial({
    color: OBSTACLE_COLOR,
    roughness: 0.95,
    flatShading: true,
  });

  const buildObstacle = (p: Position): THREE.Object3D => {
    const url = pickObstacleUrl(p.x, p.y);
    if (url) {
      const source = modelSources.get(url)!;
      const model = instantiateFrom(source);
      fitAndGround(model, OBSTACLE_MODEL_HEIGHT);
      model.position.x += p.x * TILE_SIZE;
      model.position.z += p.y * TILE_SIZE;
      // Slight yaw variety so placed obstacles don't all face the same way.
      model.rotation.y = ((p.x * 11 + p.y * 5) % 4) * (Math.PI * 0.5);
      model.traverse((obj) => {
        obj.raycast = noopRaycast;
      });
      return model;
    }

    // Fallback cube (also used while GLBs are still loading).
    const mesh = new THREE.Mesh(cubeGeom, cubeMat);
    mesh.position.set(p.x * TILE_SIZE, OBSTACLE_HEIGHT / 2, p.y * TILE_SIZE);
    return mesh;
  };

  const sync = (nextPositions: Position[]): void => {
    group.clear();
    for (const p of nextPositions) {
      group.add(buildObstacle(p));
    }
  };

  sync(positions);

  // Re-sync once the GLBs finish loading so the initial cube placeholders
  // upgrade to painterly meshes the moment they arrive. We snapshot positions
  // so subsequent sync() calls from the caller still drive ground truth.
  const initialPositions = positions.slice();
  const waitForModels = async (): Promise<void> => {
    const total = OBSTACLE_MODEL_URLS.length;
    let attempts = 0;
    while (attempts < 60) {
      const settled = OBSTACLE_MODEL_URLS.filter((u) => {
        const s = modelStatus.get(u);
        return s === "ready" || s === "missing";
      }).length;
      if (settled === total) break;
      await new Promise((r) => setTimeout(r, 250));
      attempts += 1;
    }
    const anyReady = OBSTACLE_MODEL_URLS.some((u) => modelStatus.get(u) === "ready");
    if (anyReady) sync(initialPositions);
  };
  void waitForModels();

  return {
    group,
    sync,
    dispose: () => {
      scene.remove(group);
      cubeGeom.dispose();
      cubeMat.dispose();
    },
  };
}
