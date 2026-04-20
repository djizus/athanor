import {
  ABILITIES,
  DASH_DAMAGE,
  GRID_HEIGHT,
  GRID_WIDTH,
  HEAL_AMOUNT,
  MOVE_COST_PER_TILE,
  SHOVE_DAMAGE,
  SHOVE_PUSH_DISTANCE,
  SLAM_DAMAGE,
  SLAM_PUSH_DISTANCE,
  STRIKE_DAMAGE,
  type AbilityId,
} from "./constants.js";
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
  /** Current stamina, refilled to `maxStamina` at the start of each player turn. */
  stamina: number;
  /** Per-turn cap (from tier.staminaPerTurn). Hero never holds more than this. */
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
}

const DEFAULT_COOLDOWNS: Record<AbilityId, number> = {
  0: 0,
  1: 0,
  2: 0,
  3: 0,
  4: 0,
};

export function newCombatState(tier: Tier): CombatState {
  const state: CombatState = {
    run: {
      tier,
      stamina: tier.staminaPerTurn,
      maxStamina: tier.staminaPerTurn,
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
      hp: tier.heroHp,
      maxHp: tier.heroHp,
      alive: true,
    },
    enemies: placeholderEnemies(),
    obstacles: placeholderObstacles(),
    abilityCooldowns: { ...DEFAULT_COOLDOWNS },
  };
  // Seed intents so the player sees what enemies will do on their first turn.
  // Replaced by Torii subscription to the contract's telegraph state once the
  // online loop is wired end-to-end.
  computeEnemyIntents(state);
  return state;
}

function placeholderEnemies(): Actor[] {
  // POC HP values — mirror helpers::procedural::archetype_base_stats.
  return [
    { id: 1, faction: FACTION_ENEMY, archetype: 1, x: 6, y: 6, hp: 30, maxHp: 30, alive: true },
    { id: 2, faction: FACTION_ENEMY, archetype: 1, x: 5, y: 2, hp: 30, maxHp: 30, alive: true },
    { id: 3, faction: FACTION_ENEMY, archetype: 2, x: 2, y: 6, hp: 20, maxHp: 20, alive: true },
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
      // Enemy tiles are hard blockers (no bump). We still surface them as
      // highlight candidates so the player sees they're in range, but we
      // don't propagate past them — their own tile is excluded above.
      if (state.player.x === nx && state.player.y === ny) continue;
      visited.set(k, ncost);
      if (!isOccupied(state, nx, ny)) {
        out.push({ x: nx, y: ny });
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

export interface AbilityResult {
  ok: boolean;
  reason?: string;
  affectedTiles?: Position[];
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
  // No bump: enemy-occupied tiles are hard blockers. Displacement and any
  // "free" collision damage live only in Shove/Slam abilities.
  const occupied = state.enemies.some((e) => e.alive && e.x === targetX && e.y === targetY);
  if (occupied) return { ok: false, reason: "Tile occupied" };
  player.x = targetX;
  player.y = targetY;
  spendStamina(state, cost);
  // Intents point at the player's new tile — recompute so the HUD stays honest.
  computeEnemyIntents(state);
  return { ok: true };
}

/// Spend stamina. Reaching 0 does NOT end the run — HP ≤ 0 is the only
/// terminal. Callers must guard with `stamina >= cost` before spending.
export function spendStamina(state: CombatState, amount: number): void {
  state.run.stamina = Math.max(0, state.run.stamina - amount);
}

/// Refill stamina to the per-turn cap. Called when the contract's enemy phase
/// completes and the client resyncs; intra-turn bonuses (kill +10, orb +20)
/// are deliberately NOT preserved across turns.
export function refillStamina(state: CombatState): void {
  state.run.stamina = state.run.maxStamina;
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

export function tickCooldowns(state: CombatState): void {
  for (const ability of ABILITIES) {
    const current = state.abilityCooldowns[ability.id] ?? 0;
    state.abilityCooldowns[ability.id] = Math.max(0, current - 1);
  }
}

export function tryUseAbility(
  state: CombatState,
  abilityId: AbilityId,
  targetX: number,
  targetY: number,
): AbilityResult {
  if (!canUseAbility(state, abilityId)) {
    return { ok: false, reason: "Ability unavailable" };
  }

  let affectedTiles: Position[] = [];

  if (abilityId === 0) {
    const enemy = state.enemies.find((actor) => actor.alive && actor.x === targetX && actor.y === targetY);
    if (!enemy) return { ok: false, reason: "No enemy at target" };
    if (manhattan(state.player.x, state.player.y, targetX, targetY) !== 1) {
      return { ok: false, reason: "Target not adjacent" };
    }
    applyDamage(state, enemy, STRIKE_DAMAGE);
    affectedTiles = [{ x: targetX, y: targetY }];
  } else if (abilityId === 1) {
    const dx = Math.sign(targetX - state.player.x);
    const dy = Math.sign(targetY - state.player.y);
    if ((dx === 0 && dy === 0) || (dx !== 0 && dy !== 0)) {
      return { ok: false, reason: "Dash needs a straight line" };
    }

    let curX = state.player.x;
    let curY = state.player.y;
    let finalX = curX;
    let finalY = curY;
    let moved = false;

    for (let step = 0; step < 3; step++) {
      const nextX = curX + dx;
      const nextY = curY + dy;
      if (!inBounds(nextX, nextY) || isObstacle(state, nextX, nextY)) break;
      const enemy = state.enemies.find((actor) => actor.alive && actor.x === nextX && actor.y === nextY);
      if (enemy) {
        applyDamage(state, enemy, DASH_DAMAGE);
        affectedTiles = [{ x: enemy.x, y: enemy.y }];
        break;
      }

      finalX = nextX;
      finalY = nextY;
      curX = nextX;
      curY = nextY;
      moved = true;
    }

    if (!moved && affectedTiles.length === 0) {
      return { ok: false, reason: "Dash has no path" };
    }

    state.player.x = finalX;
    state.player.y = finalY;
    if (affectedTiles.length === 0) {
      affectedTiles = [{ x: finalX, y: finalY }];
    }
  } else if (abilityId === 2) {
    if (targetX !== state.player.x || targetY !== state.player.y) {
      return { ok: false, reason: "Heal targets self" };
    }
    state.player.hp = Math.min(state.player.maxHp, state.player.hp + HEAL_AMOUNT);
    affectedTiles = [{ x: state.player.x, y: state.player.y }];
  } else if (abilityId === 3) {
    const enemy = state.enemies.find((actor) => actor.alive && actor.x === targetX && actor.y === targetY);
    if (!enemy) return { ok: false, reason: "No enemy at target" };
    if (manhattan(state.player.x, state.player.y, targetX, targetY) !== 1) {
      return { ok: false, reason: "Target not adjacent" };
    }
    applyDamage(state, enemy, SHOVE_DAMAGE);
    if (enemy.alive) {
      const dx = Math.sign(enemy.x - state.player.x);
      const dy = Math.sign(enemy.y - state.player.y);
      pushActor(state, enemy, dx, dy, SHOVE_PUSH_DISTANCE);
    }
    affectedTiles = [{ x: targetX, y: targetY }, { x: enemy.x, y: enemy.y }];
  } else {
    if (targetX !== state.player.x || targetY !== state.player.y) {
      return { ok: false, reason: "Slam targets self" };
    }
    const adjacentEnemies = state.enemies.filter(
      (actor) => actor.alive && manhattan(state.player.x, state.player.y, actor.x, actor.y) === 1,
    );
    if (adjacentEnemies.length === 0) {
      return { ok: false, reason: "No adjacent enemies" };
    }
    affectedTiles = [{ x: state.player.x, y: state.player.y }];
    for (const enemy of adjacentEnemies) {
      applyDamage(state, enemy, SLAM_DAMAGE);
      if (enemy.alive) {
        const dx = Math.sign(enemy.x - state.player.x);
        const dy = Math.sign(enemy.y - state.player.y);
        pushActor(state, enemy, dx, dy, SLAM_PUSH_DISTANCE);
      }
      affectedTiles.push({ x: enemy.x, y: enemy.y });
    }
  }

  spendStamina(state, ABILITIES[abilityId].cost);
  state.abilityCooldowns[abilityId] = ABILITIES[abilityId].cooldown;
  computeEnemyIntents(state);
  return { ok: true, affectedTiles };
}

function applyDamage(state: CombatState, actor: Actor, damage: number): void {
  actor.hp = Math.max(0, actor.hp - damage);
  if (actor.hp === 0) {
    actor.alive = false;
    actor.intent = undefined;
    state.run.score += 1;
  }
}

function pushActor(state: CombatState, actor: Actor, dx: number, dy: number, steps: number): void {
  let curX = actor.x;
  let curY = actor.y;
  for (let step = 0; step < steps; step++) {
    const nextX = curX + dx;
    const nextY = curY + dy;
    if (isBlocked(state, nextX, nextY)) break;
    curX = nextX;
    curY = nextY;
  }
  actor.x = curX;
  actor.y = curY;
}
