import {
  GRID_HEIGHT,
  GRID_WIDTH,
  type AbilityId,
} from "../state/constants.js";
import type { CombatState, Intent, Position } from "../state/combat.js";
import type { Tier } from "../state/tiers.js";

export interface RunSummary {
  gameId: number;
  roomId: number;
  turnIndex: number;
  score: number;
  roomsCleared: number;
  endedAt: bigint;
  startedAt: bigint;
}

interface GraphQLResponse<T> {
  data?: T;
  errors?: Array<{ message: string }>;
}

interface RunStateNode {
  player: string;
  game_id: number;
  phase: number;
  room_id: number;
  turn_index: number;
  player_actor_id: number;
  score: number;
  rooms_cleared: number;
  started_at: string;
  ended_at: string;
}

interface RoomStateNode {
  width: number;
  height: number;
  blocked: string;
  occupancy: string;
  enemy_count: number;
  cleared: boolean;
  orbs_fresh: string;
  orbs_aged: string;
  hp_orbs_fresh: string;
  hp_orbs_aged: string;
}

interface ActorPackedNode {
  actor_id: number;
  resources: string;
  stats: string;
}

interface AbilitySlotPackedNode {
  slot_index: number;
  packed: number;
}

interface TelegraphPackedNode {
  telegraph_id: number;
  packed_a: string;
  packed_b: string;
}

interface Edge<T> {
  node: T;
}

interface Connection<T> {
  edges: Edge<T>[];
}

interface RunStateQuery {
  athanor01RunStateModels: Connection<RunStateNode>;
}

interface RoomStateQuery {
  athanor01RoomStateModels: Connection<RoomStateNode>;
}

interface ActorStateQuery {
  athanor01ActorStatePackedModels: Connection<ActorPackedNode>;
}

interface AbilityStateQuery {
  athanor01AbilitySlotStatePackedModels: Connection<AbilitySlotPackedNode>;
}

interface TelegraphStateQuery {
  athanor01TelegraphStatePackedModels: Connection<TelegraphPackedNode>;
}

export async function fetchRunSummaries(toriiUrl: string, player: string): Promise<RunSummary[]> {
  const data = await toriiQuery<RunStateQuery>(toriiUrl, `
    query Runs($player: ContractAddress!) {
      athanor01RunStateModels(
        where: { playerEQ: $player }
        order: { field: GAME_ID, direction: DESC }
        limit: 20
      ) {
        edges {
          node {
            player
            game_id
            room_id
            turn_index
            score
            rooms_cleared
            started_at
            ended_at
          }
        }
      }
    }
  `, { player });

  return data.athanor01RunStateModels.edges.map(({ node }) => ({
    gameId: node.game_id,
    roomId: node.room_id,
    turnIndex: node.turn_index,
    score: node.score,
    roomsCleared: node.rooms_cleared,
    startedAt: hexishToBigInt(node.started_at),
    endedAt: hexishToBigInt(node.ended_at),
  }));
}

export async function fetchCombatState(
  toriiUrl: string,
  player: string,
  gameId: number,
  tier: Tier,
): Promise<CombatState | null> {
  const runData = await toriiQuery<RunStateQuery>(toriiUrl, `
    query Run($player: ContractAddress!, $gameId: u32!) {
      athanor01RunStateModels(where: { playerEQ: $player, game_idEQ: $gameId }, limit: 1) {
        edges {
          node {
            player
            game_id
            phase
            room_id
            turn_index
            player_actor_id
            score
            rooms_cleared
            started_at
            ended_at
          }
        }
      }
    }
  `, { player, gameId });

  const runNode = runData.athanor01RunStateModels.edges[0]?.node;
  if (!runNode) return null;
  const roomId = runNode.room_id;

  const [roomData, actorData, abilityData, telegraphData] = await Promise.all([
    toriiQuery<RoomStateQuery>(toriiUrl, `
      query Room($player: ContractAddress!, $gameId: u32!, $roomId: u8!) {
        athanor01RoomStateModels(
          where: { playerEQ: $player, game_idEQ: $gameId, room_idEQ: $roomId }
          limit: 1
        ) {
          edges { node { width height blocked occupancy enemy_count cleared orbs_fresh orbs_aged hp_orbs_fresh hp_orbs_aged } }
        }
      }
    `, { player, gameId, roomId }),
    toriiQuery<ActorStateQuery>(toriiUrl, `
      query Actors($player: ContractAddress!, $gameId: u32!) {
        athanor01ActorStatePackedModels(
          where: { playerEQ: $player, game_idEQ: $gameId }
          order: { field: ACTOR_ID, direction: ASC }
          limit: 16
        ) {
          edges { node { actor_id resources stats } }
        }
      }
    `, { player, gameId }),
    toriiQuery<AbilityStateQuery>(toriiUrl, `
      query AbilitySlots($player: ContractAddress!, $gameId: u32!) {
        athanor01AbilitySlotStatePackedModels(
          where: { playerEQ: $player, game_idEQ: $gameId, actor_idEQ: 0 }
          order: { field: SLOT_INDEX, direction: ASC }
          limit: 8
        ) {
          edges { node { slot_index packed } }
        }
      }
    `, { player, gameId }),
    toriiQuery<TelegraphStateQuery>(toriiUrl, `
      query Telegraphs($player: ContractAddress!, $gameId: u32!) {
        athanor01TelegraphStatePackedModels(
          where: { playerEQ: $player, game_idEQ: $gameId }
          order: { field: TELEGRAPH_ID, direction: ASC }
          limit: 32
        ) {
          edges { node { telegraph_id packed_a packed_b } }
        }
      }
    `, { player, gameId }),
  ]);

  const roomNode = roomData.athanor01RoomStateModels.edges[0]?.node;
  if (!roomNode) return null;

  const actors = actorData.athanor01ActorStatePackedModels.edges
    .map(({ node }) => unpackActor(node))
    .filter((actor) => actor.roomId === roomId || actor.actorId === 0);

  const playerActor = actors.find((actor) => actor.actorId === 0);
  if (!playerActor) return null;

  const abilityCooldowns = buildAbilityCooldowns(abilityData.athanor01AbilitySlotStatePackedModels.edges);
  const telegraphs = telegraphData.athanor01TelegraphStatePackedModels.edges
    .map(({ node }) => unpackTelegraph(node))
    .filter((telegraph) => !telegraph.resolved && telegraph.roomId === roomId);
  const intentsByActorId = buildIntents(telegraphs);

  return {
    run: {
      tier,
      stamina: playerActor.stamina,
      maxStamina: playerActor.maxStamina,
      score: runNode.score,
      roomsCleared: runNode.rooms_cleared,
      phase: runNode.phase,
      roomId,
      turnIndex: runNode.turn_index,
      pendingRoomClear: false,
      gameOver: hexishToBigInt(runNode.ended_at) !== 0n,
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
      .filter((actor) => actor.actorId !== 0 && actor.faction === 1)
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
    obstacles: decodeBitmap(hexishToBigInt(roomNode.blocked)),
    orbs: [
      ...decodeBitmap(hexishToBigInt(roomNode.orbs_fresh)).map((orb) => ({ ...orb, kind: "stamina" as const })),
      ...decodeBitmap(hexishToBigInt(roomNode.orbs_aged)).map((orb) => ({ ...orb, kind: "stamina" as const })),
      ...decodeBitmap(hexishToBigInt(roomNode.hp_orbs_fresh)).map((orb) => ({ ...orb, kind: "hp" as const })),
      ...decodeBitmap(hexishToBigInt(roomNode.hp_orbs_aged)).map((orb) => ({ ...orb, kind: "hp" as const })),
    ],
    abilityCooldowns,
  };
}

async function toriiQuery<T>(toriiUrl: string, query: string, variables: Record<string, unknown>): Promise<T> {
  const response = await fetch(`${toriiUrl}/graphql`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ query, variables }),
  });

  if (!response.ok) {
    throw new Error(`Torii query failed (${response.status})`);
  }

  const payload = (await response.json()) as GraphQLResponse<T>;
  if (payload.errors?.length) {
    throw new Error(payload.errors.map((error) => error.message).join("; "));
  }
  if (!payload.data) {
    throw new Error("Torii query returned no data");
  }
  return payload.data;
}

function buildAbilityCooldowns(edges: Edge<AbilitySlotPackedNode>[]): Record<AbilityId, number> {
  const cooldowns: Record<AbilityId, number> = { 0: 0, 1: 0, 2: 0, 3: 0, 4: 0 };
  for (const { node } of edges) {
    const packed = Number(node.packed);
    const abilityId = packed & 0xff;
    const cooldownRemaining = (packed >> 8) & 0xff;
    if (abilityId in cooldowns) {
      cooldowns[abilityId as AbilityId] = cooldownRemaining;
    }
  }
  return cooldowns;
}

function buildIntents(telegraphs: Array<ReturnType<typeof unpackTelegraph>>): Map<number, Intent> {
  const intents = new Map<number, Intent>();
  for (const telegraph of telegraphs) {
    intents.set(telegraph.sourceActorId, {
      tiles: telegraphTiles(telegraph),
      damage: telegraph.damage,
    });
  }
  return intents;
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

function telegraphTiles(telegraph: ReturnType<typeof unpackTelegraph>): Position[] {
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

function tileInShape(shapeType: number, paramA: number, paramB: number, paramC: number, x: number, y: number): boolean {
  if (shapeType === 0) return x === paramA && y === paramB;
  if (shapeType === 1) return tileInLine(paramA, paramB, paramC, 3, x, y);
  if (shapeType === 2) return tileInCone(paramA, paramB, paramC, x, y);
  if (shapeType === 3) return Math.abs(x - paramA) <= 1 && Math.abs(y - paramB) <= 1;
  if (shapeType === 4) {
    return (x === paramA && Math.abs(y - paramB) <= 1) || (y === paramB && Math.abs(x - paramA) <= 1);
  }
  return false;
}

function tileInLine(originX: number, originY: number, direction: number, maxLen: number, x: number, y: number): boolean {
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

function tileInCone(originX: number, originY: number, direction: number, x: number, y: number): boolean {
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

function unpackActor(node: ActorPackedNode) {
  const resources = hexishToBigInt(node.resources);
  const stats = hexishToBigInt(node.stats);
  return {
    actorId: node.actor_id,
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

function unpackTelegraph(node: TelegraphPackedNode) {
  const packedA = hexishToBigInt(node.packed_a);
  const packedB = hexishToBigInt(node.packed_b);
  return {
    telegraphId: node.telegraph_id,
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
}

function hexishToBigInt(value: string | number): bigint {
  if (typeof value === "number") return BigInt(value);
  return value.startsWith("0x") ? BigInt(value) : BigInt(value || "0");
}
