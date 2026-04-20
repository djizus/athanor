import * as THREE from "three";
import type { Actor, CombatState } from "../state/combat.js";
import { FACTION_PLAYER } from "../state/combat.js";
import { TILE_SIZE } from "./scene.js";

export interface ActorMesh {
  actorId: number;
  group: THREE.Group;
  hpForeground: THREE.Sprite;
}

const PLAYER_COLOR = 0x6ed6ff;
const ENEMY_COLORS: Record<number, number> = {
  1: 0xe06060, // brute-ish
  2: 0xe0a060, // caster-ish
  3: 0xc070e0, // flanker-ish
  4: 0x808080, // heavy-ish
  5: 0x60c090, // puller-ish
};

const HP_BAR_WIDTH = 0.8;
const HP_BAR_HEIGHT = 0.12;
const HP_BAR_Y_OFFSET = 1.0;

function colorForActor(actor: Actor): number {
  if (actor.faction === FACTION_PLAYER) return PLAYER_COLOR;
  return ENEMY_COLORS[actor.archetype] ?? 0xff3080;
}

function buildActorGroup(actor: Actor): ActorMesh {
  const group = new THREE.Group();
  group.position.set(actor.x * TILE_SIZE, 0, actor.y * TILE_SIZE);

  const bodyGeom = new THREE.BoxGeometry(0.6, 0.8, 0.6);
  const bodyMat = new THREE.MeshStandardMaterial({ color: colorForActor(actor), roughness: 0.6 });
  const body = new THREE.Mesh(bodyGeom, bodyMat);
  body.position.y = 0.45;
  group.add(body);

  // HP bar: red background + green foreground, both camera-facing sprites.
  const bgMat = new THREE.SpriteMaterial({
    color: 0x3a1414,
    depthTest: false,
    transparent: true,
  });
  const bg = new THREE.Sprite(bgMat);
  bg.scale.set(HP_BAR_WIDTH, HP_BAR_HEIGHT, 1);
  bg.position.set(0, HP_BAR_Y_OFFSET, 0);
  bg.renderOrder = 10;
  group.add(bg);

  const fgMat = new THREE.SpriteMaterial({
    color: actor.faction === FACTION_PLAYER ? 0x3ba45f : 0xd04040,
    depthTest: false,
    transparent: true,
  });
  const fg = new THREE.Sprite(fgMat);
  fg.scale.set(HP_BAR_WIDTH, HP_BAR_HEIGHT, 1);
  fg.position.set(0, HP_BAR_Y_OFFSET, 0);
  fg.renderOrder = 11;
  group.add(fg);

  return { actorId: actor.id, group, hpForeground: fg };
}

export function createActorMeshes(scene: THREE.Scene, state: CombatState): ActorMesh[] {
  const meshes: ActorMesh[] = [];
  const all: Actor[] = [state.player, ...state.enemies];
  for (const actor of all) {
    const am = buildActorGroup(actor);
    scene.add(am.group);
    meshes.push(am);
  }
  syncActorMeshes(meshes, state);
  return meshes;
}

export function syncActorMeshes(meshes: ActorMesh[], state: CombatState): void {
  const byId = new Map<number, Actor>();
  byId.set(state.player.id, state.player);
  for (const e of state.enemies) byId.set(e.id, e);

  for (const am of meshes) {
    const actor = byId.get(am.actorId);
    if (!actor) {
      am.group.visible = false;
      continue;
    }
    am.group.position.set(actor.x * TILE_SIZE, 0, actor.y * TILE_SIZE);
    am.group.visible = actor.alive;

    const ratio = actor.maxHp > 0 ? Math.max(0, Math.min(1, actor.hp / actor.maxHp)) : 0;
    am.hpForeground.scale.x = HP_BAR_WIDTH * ratio;
    // Anchor the bar to the left: center slides by half the removed width.
    am.hpForeground.position.x = -(HP_BAR_WIDTH - HP_BAR_WIDTH * ratio) / 2;
  }
}
