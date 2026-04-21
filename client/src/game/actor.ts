import * as THREE from "three";
import type { Actor, CombatState } from "../state/combat.js";
import { FACTION_PLAYER } from "../state/combat.js";
import { TILE_SIZE } from "./scene.js";
import { fitAndGround, instantiateFrom, loadModel } from "./assets.js";

export interface ActorMesh {
  actorId: number;
  group: THREE.Group;
  hpForeground: THREE.Sprite;
  bodyPlaceholder: THREE.Mesh | null;
}

const HERO_MODEL_URL = "/models/characters/hero.glb";
const HERO_TARGET_HEIGHT = 0.9;

const ENEMY_TARGET_HEIGHT = 0.85;
const ENEMY_HEAVY_TARGET_HEIGHT = 1.05;

// Map each archetype to the base Meshy character mesh it reuses, plus a tint
// to differentiate reused silhouettes. Until the full roster is generated,
// flanker/drainer borrow the brute mesh and puller/marksman borrow caster.
interface ArchetypeVisual {
  modelUrl: string;
  tint: number;
  targetHeight: number;
}

const ARCHETYPE_VISUAL: Record<number, ArchetypeVisual> = {
  1: { modelUrl: "/models/characters/enemy-brute.glb", tint: 0xffffff, targetHeight: ENEMY_TARGET_HEIGHT }, // Brute
  2: { modelUrl: "/models/characters/enemy-caster.glb", tint: 0xffffff, targetHeight: ENEMY_TARGET_HEIGHT }, // Caster
  3: { modelUrl: "/models/characters/enemy-brute.glb", tint: 0xc070e0, targetHeight: ENEMY_TARGET_HEIGHT }, // Flanker (reused Brute)
  4: { modelUrl: "/models/characters/enemy-heavy.glb", tint: 0xffffff, targetHeight: ENEMY_HEAVY_TARGET_HEIGHT }, // Heavy
  5: { modelUrl: "/models/characters/enemy-caster.glb", tint: 0x60c090, targetHeight: ENEMY_TARGET_HEIGHT }, // Puller (reused Caster)
  6: { modelUrl: "/models/characters/enemy-brute.glb", tint: 0x6fd15a, targetHeight: ENEMY_TARGET_HEIGHT }, // Drainer (reused Brute)
  7: { modelUrl: "/models/characters/enemy-caster.glb", tint: 0xf0e06a, targetHeight: ENEMY_TARGET_HEIGHT }, // Marksman (reused Caster)
};

const PLAYER_COLOR = 0x6ed6ff;
const ENEMY_COLORS: Record<number, number> = {
  1: 0xe06060, // brute
  2: 0xe0a060, // caster
  3: 0xc070e0, // flanker
  4: 0x808080, // heavy
  5: 0x60c090, // puller
  6: 0x6fd15a, // drainer
  7: 0xf0e06a, // marksman
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

  return { actorId: actor.id, group, hpForeground: fg, bodyPlaceholder: body };
}

function removePlaceholder(am: ActorMesh): void {
  if (!am.bodyPlaceholder) return;
  am.group.remove(am.bodyPlaceholder);
  am.bodyPlaceholder.geometry.dispose();
  (am.bodyPlaceholder.material as THREE.Material).dispose();
  am.bodyPlaceholder = null;
}

function applyTint(model: THREE.Group, tintHex: number): void {
  if (tintHex === 0xffffff) return; // neutral tint — leave materials untouched
  const tint = new THREE.Color(tintHex);
  model.traverse((obj) => {
    const mesh = obj as THREE.Mesh;
    if (!(mesh as unknown as { isMesh?: boolean }).isMesh) return;
    const applyToMat = (m: THREE.Material): void => {
      const std = m as THREE.MeshStandardMaterial;
      if (std.color) std.color.multiply(tint);
      if (std.emissive) std.emissive.lerp(tint, 0.25);
    };
    if (Array.isArray(mesh.material)) mesh.material.forEach(applyToMat);
    else if (mesh.material) applyToMat(mesh.material);
  });
}

/**
 * Async-load the hero GLB and swap the placeholder cube once it arrives.
 */
function attachHeroModel(am: ActorMesh): void {
  loadModel(HERO_MODEL_URL)
    .then((source) => {
      if (!am.bodyPlaceholder) return;
      const model = instantiateFrom(source);
      fitAndGround(model, HERO_TARGET_HEIGHT);
      removePlaceholder(am);
      am.group.add(model);
    })
    .catch((err) => {
      console.warn(`[actor] hero model failed to load from ${HERO_MODEL_URL}:`, err);
    });
}

/**
 * Async-load an enemy GLB for the archetype and swap when ready. If the GLB
 * is missing (e.g. hasn't been generated yet), leave the placeholder cube
 * in place so the game stays visually distinguishable.
 */
function attachEnemyModel(am: ActorMesh, archetype: number): void {
  const spec = ARCHETYPE_VISUAL[archetype];
  if (!spec) return;
  loadModel(spec.modelUrl)
    .then((source) => {
      if (!am.bodyPlaceholder) return;
      const model = instantiateFrom(source);
      applyTint(model, spec.tint);
      fitAndGround(model, spec.targetHeight);
      removePlaceholder(am);
      am.group.add(model);
    })
    .catch(() => {
      // Silent: GLB not generated yet. The cube placeholder is already up.
    });
}

export function createActorMeshes(scene: THREE.Scene, state: CombatState): ActorMesh[] {
  const meshes: ActorMesh[] = [];
  const all: Actor[] = [state.player, ...state.enemies];
  for (const actor of all) {
    const am = buildActorGroup(actor);
    scene.add(am.group);
    if (actor.faction === FACTION_PLAYER) {
      attachHeroModel(am);
    } else {
      attachEnemyModel(am, actor.archetype);
    }
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
