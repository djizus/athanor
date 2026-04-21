// RPC-only data layer for in-run combat state. No Torii required here: we
// call view_* functions on the actions contract and decode the packed fields
// client-side. Keep in sync with contracts/src/systems/actions.cairo view
// helpers.
import { CallData, type ProviderInterface } from "starknet";
import type { DojoConfig } from "./config.js";
import type { CombatState, Intent, Position } from "../state/combat.js";
import type { Tier } from "../state/tiers.js";
import { GRID_HEIGHT, GRID_WIDTH, type AbilityId } from "../state/constants.js";

const MAX_TELEGRAPH_ID = 32;
const MAX_ACTOR_ID = 8;
const ABILITY_SLOT_COUNT = 5;

export async function fetchCombatState(
  provider: ProviderInterface,
  cfg: DojoConfig,
  player: string,
  gameId: number,
  tier: Tier,
): Promise<CombatState | null> {
  const runNode = await readRunState(provider, cfg, player, gameId);
  if (!runNode) return null;
  const roomId = runNode.roomId;

  const [roomNode, actors, abilityCooldowns, telegraphs] = await Promise.all([
    readRoomState(provider, cfg, player, gameId, roomId),
    readAllActors(provider, cfg, player, gameId, roomId),
    readAbilityCooldowns(provider, cfg, player, gameId),
    readTelegraphs(provider, cfg, player, gameId, roomId, runNode.statusFlags),
  ]);

  if (!roomNode) return null;

  const playerActor = actors.find((actor) => actor.actorId === 0);
  if (!playerActor) return null;

  const intentsByActorId = buildIntents(telegraphs);

  return {
    run: {
      tier,
      stamina: playerActor.stamina,
      maxStamina: playerActor.maxStamina,
      score: runNode.score,
      roomsCleared: runNode.roomsCleared,
      phase: runNode.phase,
      roomId,
      turnIndex: runNode.turnIndex,
      pendingRoomClear: false,
      gameOver: runNode.endedAt !== 0n,
    },
    player: {
      id: playerActor.actorId,
      faction: playerActor.faction,
      archetype: playerActor.archetype,
      x: playerActor.posX,
      y: playerActor.posY,
      hp: playerActor.hp,
      maxHp: playerActor.maxHp,
      offense: playerActor.offense,
      defense: playerActor.defense,
      speed: playerActor.speed,
      moveCost: playerActor.moveCost,
      alive: playerActor.alive,
      isImmovable: playerActor.isImmovable,
      roomId: playerActor.roomId,
    },
    enemies: actors
      .filter((actor) => actor.actorId !== 0 && actor.faction === 1 && actor.roomId === roomId)
      .map((actor) => ({
        id: actor.actorId,
        faction: actor.faction,
        archetype: actor.archetype,
        x: actor.posX,
        y: actor.posY,
        hp: actor.hp,
        maxHp: actor.maxHp,
        offense: actor.offense,
        defense: actor.defense,
        speed: actor.speed,
        moveCost: actor.moveCost,
        alive: actor.alive,
        isImmovable: actor.isImmovable,
        roomId: actor.roomId,
        intent: intentsByActorId.get(actor.actorId),
      })),
    obstacles: decodeBitmap(roomNode.blocked),
    orbs: [
      ...decodeBitmap(roomNode.orbsFresh).map((orb) => ({ ...orb, kind: "stamina" as const })),
      ...decodeBitmap(roomNode.orbsAged).map((orb) => ({ ...orb, kind: "stamina" as const })),
      ...decodeBitmap(roomNode.hpOrbsFresh).map((orb) => ({ ...orb, kind: "hp" as const })),
      ...decodeBitmap(roomNode.hpOrbsAged).map((orb) => ({ ...orb, kind: "hp" as const })),
    ],
    abilityCooldowns,
  };
}

export function decodeActorPacked(resources: bigint, stats: bigint) {
  return {
    hp: Number(resources & 0xffffn),
    maxHp: Number((resources >> 16n) & 0xffffn),
    stamina: Number((resources >> 32n) & 0xffffn),
    maxStamina: Number((resources >> 48n) & 0xffffn),
    alive: (stats & 1n) === 1n,
    faction: Number((stats >> 3n) & 1n),
    archetype: Number((stats >> 4n) & 0x7n),
    offense: Number((stats >> 7n) & 0xffn),
    defense: Number((stats >> 15n) & 0xffn),
    speed: Number((stats >> 23n) & 0xffn),
    moveCost: Number((stats >> 31n) & 0xffn),
    posX: Number((stats >> 39n) & 0x7n),
    posY: Number((stats >> 42n) & 0x7n),
    isImmovable: ((stats >> 2n) & 1n) === 1n,
    roomId: Number((stats >> 45n) & 0xffn),
  };
}

interface RunStateNode {
  phase: number;
  roomId: number;
  turnIndex: number;
  statusFlags: number;
  score: number;
  roomsCleared: number;
  startedAt: bigint;
  endedAt: bigint;
}

async function readRunState(
  provider: ProviderInterface,
  cfg: DojoConfig,
  player: string,
  gameId: number,
): Promise<RunStateNode | null> {
  const fields = await callView(provider, cfg, "view_run_state", [player, `${gameId}`], 11);
  if (!fields) return null;
  return {
    phase: Number(fields[0]),
    roomId: Number(fields[1]),
    turnIndex: Number(fields[2]),
    // fields[3] = player_actor_id
    statusFlags: Number(fields[4]),
    // fields[5] = last_player_direction
    // fields[6] = seed
    score: Number(fields[7]),
    roomsCleared: Number(fields[8]),
    startedAt: fields[9],
    endedAt: fields[10],
  };
}

interface RoomStateNode {
  blocked: bigint;
  occupancy: bigint;
  enemyCount: number;
  cleared: boolean;
  orbsFresh: bigint;
  orbsAged: bigint;
  hpOrbsFresh: bigint;
  hpOrbsAged: bigint;
}

async function readRoomState(
  provider: ProviderInterface,
  cfg: DojoConfig,
  player: string,
  gameId: number,
  roomId: number,
): Promise<RoomStateNode | null> {
  const fields = await callView(
    provider,
    cfg,
    "view_room_state",
    [player, `${gameId}`, `${roomId}`],
    10,
  );
  if (!fields) return null;

  // If the room has no width, it's uninitialized.
  if (fields[0] === 0n) return null;

  return {
    // fields[0] = width, fields[1] = height
    blocked: fields[2],
    occupancy: fields[3],
    enemyCount: Number(fields[4]),
    cleared: fields[5] !== 0n,
    orbsFresh: fields[6],
    orbsAged: fields[7],
    hpOrbsFresh: fields[8],
    hpOrbsAged: fields[9],
  };
}

interface ActorPackedNode {
  actorId: number;
  hp: number;
  maxHp: number;
  stamina: number;
  maxStamina: number;
  alive: boolean;
  faction: number;
  archetype: number;
  offense: number;
  defense: number;
  speed: number;
  moveCost: number;
  posX: number;
  posY: number;
  isImmovable: boolean;
  roomId: number;
}

async function readAllActors(
  provider: ProviderInterface,
  cfg: DojoConfig,
  player: string,
  gameId: number,
  roomId: number,
): Promise<ActorPackedNode[]> {
  const actorIds = Array.from({ length: MAX_ACTOR_ID + 1 }, (_, i) => i);
  const results = await Promise.all(
    actorIds.map((actorId) =>
      callView(provider, cfg, "view_actor_state", [player, `${gameId}`, `${actorId}`], 2),
    ),
  );

  const out: ActorPackedNode[] = [];
  for (let i = 0; i < actorIds.length; i++) {
    const fields = results[i];
    if (!fields) continue;
    const [resources, stats] = fields;
    if (resources === 0n && stats === 0n) continue;
    const decoded = decodeActorPacked(resources, stats);
    if (decoded.maxHp === 0) continue;
    // Keep the player actor (id 0) even if room doesn't match, so we can read
    // player stats before entering a room.
    if (actorIds[i] !== 0 && decoded.roomId !== roomId) continue;
    out.push({ actorId: actorIds[i], ...decoded });
  }
  return out;
}

async function readAbilityCooldowns(
  provider: ProviderInterface,
  cfg: DojoConfig,
  player: string,
  gameId: number,
): Promise<Record<AbilityId, number>> {
  const cooldowns: Record<AbilityId, number> = { 0: 0, 1: 0, 2: 0, 3: 0, 4: 0 };
  const slotIndices = Array.from({ length: ABILITY_SLOT_COUNT }, (_, i) => i);
  const results = await Promise.all(
    slotIndices.map((slot) =>
      callView(
        provider,
        cfg,
        "view_ability_slot",
        [player, `${gameId}`, "0", `${slot}`],
        1,
      ),
    ),
  );
  for (let i = 0; i < slotIndices.length; i++) {
    const fields = results[i];
    if (!fields) continue;
    const packed = Number(fields[0]);
    const abilityId = packed & 0xff;
    const cooldown = (packed >> 8) & 0xff;
    if (abilityId in cooldowns) {
      cooldowns[abilityId as AbilityId] = cooldown;
    }
  }
  return cooldowns;
}

interface TelegraphNode {
  telegraphId: number;
  sourceActorId: number;
  shapeType: number;
  telegraphType: number;
  resolved: boolean;
  paramA: number;
  paramB: number;
  paramC: number;
  roomId: number;
  damage: number;
}

async function readTelegraphs(
  provider: ProviderInterface,
  cfg: DojoConfig,
  player: string,
  gameId: number,
  roomId: number,
  statusFlags: number,
): Promise<TelegraphNode[]> {
  // status_flags is the telegraph count counter; cap our iteration.
  const count = Math.min(statusFlags, MAX_TELEGRAPH_ID);
  if (count === 0) return [];

  const ids = Array.from({ length: count }, (_, i) => i);
  const results = await Promise.all(
    ids.map((id) =>
      callView(
        provider,
        cfg,
        "view_telegraph_state",
        [player, `${gameId}`, `${id}`],
        2,
      ),
    ),
  );

  const out: TelegraphNode[] = [];
  for (let i = 0; i < ids.length; i++) {
    const fields = results[i];
    if (!fields) continue;
    const [packedA, packedB] = fields;
    if (packedA === 0n && packedB === 0n) continue;
    const node: TelegraphNode = {
      telegraphId: ids[i],
      sourceActorId: Number(packedA & 0xffn),
      shapeType: Number((packedA >> 8n) & 0xfn),
      telegraphType: Number((packedA >> 12n) & 0x3n),
      resolved: ((packedA >> 14n) & 1n) === 1n,
      paramA: Number((packedA >> 15n) & 0xffn),
      paramB: Number((packedA >> 23n) & 0xffn),
      paramC: Number((packedA >> 31n) & 0xffn),
      roomId: Number((packedA >> 55n) & 0xffn),
      damage: Number((packedB >> 8n) & 0xffffn),
    };
    if (node.resolved || node.roomId !== roomId) continue;
    out.push(node);
  }
  return out;
}

async function callView(
  provider: ProviderInterface,
  cfg: DojoConfig,
  entrypoint: string,
  calldata: string[],
  expectedLen: number,
): Promise<bigint[] | null> {
  try {
    const result = await provider.callContract({
      contractAddress: cfg.actionsAddress,
      entrypoint,
      calldata: CallData.compile(calldata),
    });
    if (!result || result.length < expectedLen) return null;
    return result.slice(0, expectedLen).map((v) => BigInt(v));
  } catch (err) {
    console.debug("[rpc] view call failed", { entrypoint, calldata, err });
    return null;
  }
}

function buildIntents(telegraphs: TelegraphNode[]): Map<number, Intent> {
  const intents = new Map<number, Intent>();
  for (const telegraph of telegraphs) {
    intents.set(telegraph.sourceActorId, {
      tiles: telegraphTiles(telegraph),
      damage: telegraph.damage,
    });
  }
  return intents;
}

function telegraphTiles(telegraph: TelegraphNode): Position[] {
  const { shapeType, paramA, paramB, paramC } = telegraph;
  const tiles: Position[] = [];
  for (let y = 0; y < GRID_HEIGHT; y++) {
    for (let x = 0; x < GRID_WIDTH; x++) {
      if (tileInShape(shapeType, paramA, paramB, paramC, x, y)) {
        tiles.push({ x, y });
      }
    }
  }
  return tiles;
}

function tileInShape(
  shapeType: number,
  paramA: number,
  paramB: number,
  paramC: number,
  x: number,
  y: number,
): boolean {
  if (shapeType === 0) return x === paramA && y === paramB;
  if (shapeType === 1) return tileInLine(paramA, paramB, paramC, 3, x, y);
  if (shapeType === 2) return tileInCone(paramA, paramB, paramC, x, y);
  if (shapeType === 3) return Math.abs(x - paramA) <= 1 && Math.abs(y - paramB) <= 1;
  if (shapeType === 4) {
    return (x === paramA && Math.abs(y - paramB) <= 1) || (y === paramB && Math.abs(x - paramA) <= 1);
  }
  return false;
}

function tileInLine(
  originX: number,
  originY: number,
  direction: number,
  maxLen: number,
  x: number,
  y: number,
): boolean {
  let curX = originX;
  let curY = originY;
  for (let step = 0; step < maxLen; step++) {
    const next = stepInDirection(curX, curY, direction);
    if (!next) break;
    if (next.x === x && next.y === y) return true;
    curX = next.x;
    curY = next.y;
  }
  return false;
}

function tileInCone(
  originX: number,
  originY: number,
  direction: number,
  x: number,
  y: number,
): boolean {
  if (direction === 0) return y === originY - 1 && Math.abs(x - originX) <= 1;
  if (direction === 1) return x === originX + 1 && Math.abs(y - originY) <= 1;
  if (direction === 2) return y === originY + 1 && Math.abs(x - originX) <= 1;
  return x === originX - 1 && Math.abs(y - originY) <= 1;
}

function stepInDirection(x: number, y: number, direction: number): Position | null {
  if (direction === 0) return y > 0 ? { x, y: y - 1 } : null;
  if (direction === 1) return x < GRID_WIDTH - 1 ? { x: x + 1, y } : null;
  if (direction === 2) return y < GRID_HEIGHT - 1 ? { x, y: y + 1 } : null;
  return x > 0 ? { x: x - 1, y } : null;
}

function decodeBitmap(bits: bigint): Position[] {
  const out: Position[] = [];
  for (let y = 0; y < GRID_HEIGHT; y++) {
    for (let x = 0; x < GRID_WIDTH; x++) {
      const index = BigInt(y * GRID_WIDTH + x);
      if (((bits >> index) & 1n) === 1n) {
        out.push({ x, y });
      }
    }
  }
  return out;
}
