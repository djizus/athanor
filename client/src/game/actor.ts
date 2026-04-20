import * as THREE from "three";
import type { Actor, CombatState } from "../state/combat.js";
import { FACTION_PLAYER } from "../state/combat.js";
import { TILE_SIZE } from "./scene.js";

export interface ActorMesh {
  actorId: number;
  mesh: THREE.Mesh;
}

const PLAYER_COLOR = 0x6ed6ff;
const ENEMY_COLORS: Record<number, number> = {
  1: 0xe06060, // brute-ish
  2: 0xe0a060, // caster-ish
  3: 0xc070e0, // flanker-ish
  4: 0x808080, // heavy-ish
  5: 0x60c090, // puller-ish
};

function colorForActor(actor: Actor): number {
  if (actor.faction === FACTION_PLAYER) return PLAYER_COLOR;
  return ENEMY_COLORS[actor.archetype] ?? 0xff3080;
}

export function createActorMeshes(scene: THREE.Scene, state: CombatState): ActorMesh[] {
  const meshes: ActorMesh[] = [];
  const all: Actor[] = [state.player, ...state.enemies];

  for (const actor of all) {
    const geometry = new THREE.BoxGeometry(0.6, 0.8, 0.6);
    const material = new THREE.MeshStandardMaterial({
      color: colorForActor(actor),
      roughness: 0.6,
    });
    const mesh = new THREE.Mesh(geometry, material);
    mesh.position.set(actor.x * TILE_SIZE, 0.45, actor.y * TILE_SIZE);
    mesh.visible = actor.alive;
    scene.add(mesh);
    meshes.push({ actorId: actor.id, mesh });
  }

  return meshes;
}

export function syncActorMeshes(meshes: ActorMesh[], state: CombatState): void {
  const byId = new Map<number, Actor>();
  byId.set(state.player.id, state.player);
  for (const e of state.enemies) byId.set(e.id, e);

  for (const am of meshes) {
    const actor = byId.get(am.actorId);
    if (!actor) {
      am.mesh.visible = false;
      continue;
    }
    am.mesh.position.set(actor.x * TILE_SIZE, 0.45, actor.y * TILE_SIZE);
    am.mesh.visible = actor.alive;
  }
}
