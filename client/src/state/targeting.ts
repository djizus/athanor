import {
  ABILITIES,
  ABILITY_DASH,
  ABILITY_HEAL,
  ABILITY_SLAM,
  ABILITY_STRIKE,
  ABILITY_SHOVE,
  type AbilityId,
} from "./constants.js";
import { inBounds, isObstacle, manhattan, type CombatState, type Position } from "./combat.js";

export const DOJO_TARGET_SINGLE = 0;
export const DOJO_TARGET_DIRECTIONAL = 1;
export const DOJO_TARGET_SELF = 3;

export const DOJO_DIR_NORTH = 0;
export const DOJO_DIR_EAST = 1;
export const DOJO_DIR_SOUTH = 2;
export const DOJO_DIR_WEST = 3;

const CARDINAL_DIRECTIONS = [
  { x: -1, y: 0 },
  { x: 1, y: 0 },
  { x: 0, y: -1 },
  { x: 0, y: 1 },
];

export interface AbilityPayload {
  targetMode: number;
  targetA: number;
  targetB: number;
}

export function getValidAbilityTargets(state: CombatState, abilityId: AbilityId): Position[] {
  const ability = ABILITIES[abilityId];
  if (!ability) return [];

  const player = state.player;
  if (ability.target === "self") {
    return [{ x: player.x, y: player.y }];
  }

  if (ability.target === "adjacent") {
    const targets: Position[] = [];
    for (const dir of CARDINAL_DIRECTIONS) {
      const x = player.x + dir.x;
      const y = player.y + dir.y;
      if (!inBounds(x, y) || isObstacle(state, x, y)) continue;
      if (state.enemies.some((enemy) => enemy.alive && enemy.x === x && enemy.y === y)) {
        targets.push({ x, y });
      }
    }
    return targets;
  }

  const targets: Position[] = [];
  for (const dir of CARDINAL_DIRECTIONS) {
    for (let step = 1; step <= ability.rangeTiles; step++) {
      const x = player.x + dir.x * step;
      const y = player.y + dir.y * step;
      if (!inBounds(x, y) || isObstacle(state, x, y)) break;
      targets.push({ x, y });
    }
  }
  return targets;
}

export function isValidAbilityTarget(state: CombatState, abilityId: AbilityId, target: Position): boolean {
  return getValidAbilityTargets(state, abilityId).some((cell) => cell.x === target.x && cell.y === target.y);
}

export function directionFromPlayer(state: CombatState, target: Position): Position | null {
  const dx = target.x - state.player.x;
  const dy = target.y - state.player.y;
  if (dx !== 0 && dy !== 0) return null;
  if (dx === 0 && dy === 0) return null;
  if (Math.abs(dx) + Math.abs(dy) !== manhattan(state.player.x, state.player.y, target.x, target.y)) {
    return null;
  }
  return { x: Math.sign(dx), y: Math.sign(dy) };
}

export function buildAbilityPayload(
  state: CombatState,
  abilityId: AbilityId,
  target: Position,
): AbilityPayload | null {
  if (abilityId === ABILITY_STRIKE || abilityId === ABILITY_SHOVE) {
    const enemy = state.enemies.find((actor) => actor.alive && actor.x === target.x && actor.y === target.y);
    if (!enemy) return null;
    return { targetMode: DOJO_TARGET_SINGLE, targetA: enemy.id, targetB: 0 };
  }

  if (abilityId === ABILITY_DASH) {
    const direction = directionFromPlayer(state, target);
    if (!direction) return null;
    return { targetMode: DOJO_TARGET_DIRECTIONAL, targetA: vecToDojoDirection(direction), targetB: 0 };
  }

  if (abilityId === ABILITY_HEAL || abilityId === ABILITY_SLAM) {
    return { targetMode: DOJO_TARGET_SELF, targetA: 0, targetB: 0 };
  }

  return null;
}

export function abilityPrompt(abilityId: AbilityId | null): string {
  if (abilityId === null) return "Move on green tiles. Red tiles are enemy danger.";
  const ability = ABILITIES[abilityId];
  if (!ability) return "";
  if (ability.target === "adjacent") return `${ability.name}: select an adjacent enemy.`;
  if (ability.target === "line") return `${ability.name}: select a tile in a straight line.`;
  return `${ability.name}: select yourself to confirm.`;
}

function vecToDojoDirection(direction: Position): number {
  if (direction.x > 0) return DOJO_DIR_EAST;
  if (direction.x < 0) return DOJO_DIR_WEST;
  if (direction.y > 0) return DOJO_DIR_SOUTH;
  return DOJO_DIR_NORTH;
}
