import * as THREE from "three";
import type { Position } from "../state/combat.js";
import { TILE_SIZE } from "./scene.js";

const OBSTACLE_COLOR = 0x4a3a2a;
const OBSTACLE_HEIGHT = 0.9;

export interface ObstacleBundle {
  group: THREE.Group;
  sync: (positions: Position[]) => void;
  dispose: () => void;
}

export function createObstacles(scene: THREE.Scene, positions: Position[]): ObstacleBundle {
  const group = new THREE.Group();
  scene.add(group);

  const geometry = new THREE.BoxGeometry(TILE_SIZE * 0.88, OBSTACLE_HEIGHT, TILE_SIZE * 0.88);
  const material = new THREE.MeshStandardMaterial({
    color: OBSTACLE_COLOR,
    roughness: 0.95,
    flatShading: true,
  });

  const sync = (nextPositions: Position[]): void => {
    group.clear();
    for (const p of nextPositions) {
      const mesh = new THREE.Mesh(geometry, material);
      mesh.position.set(p.x * TILE_SIZE, OBSTACLE_HEIGHT / 2, p.y * TILE_SIZE);
      group.add(mesh);
    }
  };

  sync(positions);

  return {
    group,
    sync,
    dispose: () => {
      scene.remove(group);
      geometry.dispose();
      material.dispose();
    },
  };
}
