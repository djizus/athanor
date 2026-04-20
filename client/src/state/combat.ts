import { ABILITIES, HERO_HP, MOVE_COST_PER_TILE, type AbilityId } from "./constants.js";
import type { Tier } from "./tiers.js";

export const FACTION_PLAYER = 0;
export const FACTION_ENEMY = 1;

export interface Actor {
  id: number;
  faction: number;
  archetype: number;
  x: number;
  y: number;
  hp: number;
  maxHp: number;
  alive: boolean;
}

export interface RunState {
  tier: Tier;
  stamina: number;
  maxStamina: number;
  score: number;
  roomsCleared: number;
  gameOver: boolean;
}

export interface CombatState {
  run: RunState;
  player: Actor;
  enemies: Actor[];
  abilityCooldowns: Record<AbilityId, number>;
  online: boolean;
}

const DEFAULT_COOLDOWNS: Record<AbilityId, number> = {
  0: 0,
  1: 0,
  2: 0,
  3: 0,
  4: 0,
};

export function newCombatState(tier: Tier, online: boolean): CombatState {
  return {
    run: {
      tier,
      stamina: tier.stamina,
      maxStamina: tier.stamina,
      score: 0,
      roomsCleared: 0,
      gameOver: false,
    },
    player: {
      id: 0,
      faction: FACTION_PLAYER,
      archetype: 0,
      x: 1,
      y: 1,
      hp: HERO_HP,
      maxHp: HERO_HP,
      alive: true,
    },
    enemies: placeholderEnemies(),
    abilityCooldowns: { ...DEFAULT_COOLDOWNS },
    online,
  };
}

function placeholderEnemies(): Actor[] {
  return [
    { id: 1, faction: FACTION_ENEMY, archetype: 1, x: 6, y: 6, hp: 40, maxHp: 40, alive: true },
    { id: 2, faction: FACTION_ENEMY, archetype: 1, x: 5, y: 2, hp: 40, maxHp: 40, alive: true },
    { id: 3, faction: FACTION_ENEMY, archetype: 2, x: 2, y: 6, hp: 25, maxHp: 25, alive: true },
  ];
}

export function manhattan(ax: number, ay: number, bx: number, by: number): number {
  return Math.abs(ax - bx) + Math.abs(ay - by);
}

export interface MoveResult {
  ok: boolean;
  reason?: string;
}

export function tryMove(state: CombatState, targetX: number, targetY: number): MoveResult {
  if (state.run.gameOver) return { ok: false, reason: "Run over" };
  const { player } = state;
  if (targetX === player.x && targetY === player.y) return { ok: true };
  const dist = manhattan(player.x, player.y, targetX, targetY);
  const cost = dist * MOVE_COST_PER_TILE;
  if (state.run.stamina < cost) return { ok: false, reason: "Not enough stamina" };
  const occupied = state.enemies.some((e) => e.alive && e.x === targetX && e.y === targetY);
  if (occupied) return { ok: false, reason: "Tile occupied" };
  player.x = targetX;
  player.y = targetY;
  spendStamina(state, cost);
  return { ok: true };
}

export function spendStamina(state: CombatState, amount: number): void {
  state.run.stamina = Math.max(0, state.run.stamina - amount);
  if (state.run.stamina === 0) {
    state.run.gameOver = true;
  }
}

export function cooldownOf(state: CombatState, abilityId: AbilityId): number {
  return state.abilityCooldowns[abilityId] ?? 0;
}

export function canUseAbility(state: CombatState, abilityId: AbilityId): boolean {
  if (state.run.gameOver) return false;
  const def = ABILITIES[abilityId];
  if (!def) return false;
  if (cooldownOf(state, abilityId) > 0) return false;
  return state.run.stamina >= def.cost;
}
