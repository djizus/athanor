import { ABILITIES, GRID_HEIGHT, GRID_WIDTH, HERO_HP, MOVE_COST_PER_TILE, type AbilityId } from "./constants.js";
import type { Tier } from "./tiers.js";

export const FACTION_PLAYER = 0;
export const FACTION_ENEMY = 1;

export interface Position {
  x: number;
  y: number;
}

export interface Intent {
  /** Tiles the enemy will strike next enemy phase. */
  tiles: Position[];
  damage: number;
}

export interface Actor {
  id: number;
  faction: number;
  archetype: number;
  x: number;
  y: number;
  hp: number;
  maxHp: number;
  alive: boolean;
  intent?: Intent;
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
  /** Tile positions that block movement. */
  obstacles: Position[];
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
  const state: CombatState = {
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
    obstacles: placeholderObstacles(),
    abilityCooldowns: { ...DEFAULT_COOLDOWNS },
    online,
  };
  // Seed intents so the player sees what enemies will do on their first turn.
  computeEnemyIntents(state);
  return state;
}

function placeholderEnemies(): Actor[] {
  return [
    { id: 1, faction: FACTION_ENEMY, archetype: 1, x: 6, y: 6, hp: 40, maxHp: 40, alive: true },
    { id: 2, faction: FACTION_ENEMY, archetype: 1, x: 5, y: 2, hp: 40, maxHp: 40, alive: true },
    { id: 3, faction: FACTION_ENEMY, archetype: 2, x: 2, y: 6, hp: 25, maxHp: 25, alive: true },
  ];
}

function placeholderObstacles(): Position[] {
  // A handful of fixed obstacles for feel-testing. Procedural room generation
  // (seeded from RunState.seed) replaces this when the chain layer lands.
  return [
    { x: 3, y: 3 },
    { x: 4, y: 4 },
    { x: 5, y: 4 },
    { x: 3, y: 5 },
    { x: 6, y: 2 },
  ];
}

export function manhattan(ax: number, ay: number, bx: number, by: number): number {
  return Math.abs(ax - bx) + Math.abs(ay - by);
}

export function inBounds(x: number, y: number): boolean {
  return x >= 0 && y >= 0 && x < GRID_WIDTH && y < GRID_HEIGHT;
}

export function isObstacle(state: CombatState, x: number, y: number): boolean {
  return state.obstacles.some((o) => o.x === x && o.y === y);
}

export function isOccupied(state: CombatState, x: number, y: number, ignoreId?: number): boolean {
  if (state.player.alive && state.player.id !== ignoreId && state.player.x === x && state.player.y === y)
    return true;
  return state.enemies.some((e) => e.alive && e.id !== ignoreId && e.x === x && e.y === y);
}

export function isBlocked(state: CombatState, x: number, y: number): boolean {
  if (!inBounds(x, y)) return true;
  if (isObstacle(state, x, y)) return true;
  if (isOccupied(state, x, y)) return true;
  return false;
}

/**
 * Tiles the player can reach with their remaining stamina.
 * BFS on Manhattan grid, pruned by obstacles + occupants. Excludes the
 * player's own tile.
 */
export function computeReachable(state: CombatState): Position[] {
  if (state.run.gameOver) return [];
  const { player } = state;
  const budget = Math.floor(state.run.stamina / MOVE_COST_PER_TILE);
  if (budget <= 0) return [];

  const visited = new Map<string, number>();
  const key = (x: number, y: number): string => `${x},${y}`;
  const queue: Array<{ x: number; y: number; cost: number }> = [{ x: player.x, y: player.y, cost: 0 }];
  visited.set(key(player.x, player.y), 0);

  const out: Position[] = [];
  const deltas = [
    { dx: 1, dy: 0 },
    { dx: -1, dy: 0 },
    { dx: 0, dy: 1 },
    { dx: 0, dy: -1 },
  ];

  while (queue.length > 0) {
    const cur = queue.shift()!;
    for (const { dx, dy } of deltas) {
      const nx = cur.x + dx;
      const ny = cur.y + dy;
      const ncost = cur.cost + 1;
      if (!inBounds(nx, ny)) continue;
      if (ncost > budget) continue;
      const k = key(nx, ny);
      if (visited.has(k)) continue;
      if (isObstacle(state, nx, ny)) continue;
      // Enemies can be bumped; we still let the player click their tile as a
      // reachable target, but not the player's own tile.
      if (state.player.x === nx && state.player.y === ny) continue;
      visited.set(k, ncost);
      out.push({ x: nx, y: ny });
      if (!isOccupied(state, nx, ny)) {
        queue.push({ x: nx, y: ny, cost: ncost });
      }
    }
  }
  return out;
}

/**
 * Assign each live enemy a simple "next hit" intent so the player sees danger
 * tiles. This is a placeholder for the real contract-side enemy AI; it just
 * picks one tile adjacent to the enemy in the direction of the player, clamped
 * to the grid and favouring tiles the player occupies.
 */
export function computeEnemyIntents(state: CombatState): void {
  for (const enemy of state.enemies) {
    if (!enemy.alive) {
      enemy.intent = undefined;
      continue;
    }
    const dx = Math.sign(state.player.x - enemy.x);
    const dy = Math.sign(state.player.y - enemy.y);
    let tx = enemy.x;
    let ty = enemy.y;
    // Prefer the axis with the larger delta toward the player.
    if (Math.abs(state.player.x - enemy.x) >= Math.abs(state.player.y - enemy.y) && dx !== 0) {
      tx = enemy.x + dx;
    } else if (dy !== 0) {
      ty = enemy.y + dy;
    } else if (dx !== 0) {
      tx = enemy.x + dx;
    }
    if (!inBounds(tx, ty)) {
      tx = enemy.x;
      ty = enemy.y;
    }
    enemy.intent = { tiles: [{ x: tx, y: ty }], damage: 10 };
  }
}

export interface MoveResult {
  ok: boolean;
  reason?: string;
}

export function tryMove(state: CombatState, targetX: number, targetY: number): MoveResult {
  if (state.run.gameOver) return { ok: false, reason: "Run over" };
  const { player } = state;
  if (targetX === player.x && targetY === player.y) return { ok: true };
  if (!inBounds(targetX, targetY)) return { ok: false, reason: "Out of bounds" };
  if (isObstacle(state, targetX, targetY)) return { ok: false, reason: "Obstacle" };
  const dist = manhattan(player.x, player.y, targetX, targetY);
  const cost = dist * MOVE_COST_PER_TILE;
  if (state.run.stamina < cost) return { ok: false, reason: "Not enough stamina" };
  const occupied = state.enemies.some((e) => e.alive && e.x === targetX && e.y === targetY);
  if (occupied) return { ok: false, reason: "Tile occupied" };
  player.x = targetX;
  player.y = targetY;
  spendStamina(state, cost);
  // Intents point at the player's new tile — recompute so the HUD stays honest.
  computeEnemyIntents(state);
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
