import * as THREE from "three";
import type { CombatState } from "../state/combat.js";
import { TILE_SIZE } from "./scene.js";

export interface OrbBundle {
  sync: (state: CombatState) => void;
  dispose: () => void;
}

const STAMINA_COLOR = 0x71d978;
const HP_COLOR = 0xe6b14a;

export function createOrbs(scene: THREE.Scene, state: CombatState): OrbBundle {
  const group = new THREE.Group();
  scene.add(group);

  const geometry = new THREE.OctahedronGeometry(TILE_SIZE * 0.18, 0);
  const staminaMaterial = new THREE.MeshStandardMaterial({ color: STAMINA_COLOR, emissive: 0x1a4d22, roughness: 0.25 });
  const hpMaterial = new THREE.MeshStandardMaterial({ color: HP_COLOR, emissive: 0x5a3610, roughness: 0.2 });

  const sync = (next: CombatState): void => {
    group.clear();
    for (const orb of next.orbs) {
      const mesh = new THREE.Mesh(geometry, orb.kind === "stamina" ? staminaMaterial : hpMaterial);
      mesh.position.set(orb.x * TILE_SIZE, 0.28, orb.y * TILE_SIZE);
      mesh.rotation.y = Math.PI / 4;
      group.add(mesh);
    }
  };

  sync(state);

  return {
    sync,
    dispose: () => {
      scene.remove(group);
      group.clear();
      geometry.dispose();
      staminaMaterial.dispose();
      hpMaterial.dispose();
    },
  };
}
