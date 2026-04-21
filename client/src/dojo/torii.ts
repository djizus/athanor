// Torii is used ONLY for cross-run indexing concerns (run discovery, history,
// leaderboards). All in-run combat state comes from direct RPC calls — see
// ./rpc.ts.
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
  game_id: number;
  room_id: number;
  turn_index: number;
  score: number;
  rooms_cleared: number;
  started_at: string;
  ended_at: string;
}

interface RunStateQuery {
  athanor01RunStateModels: { edges: Array<{ node: RunStateNode }> };
}

export async function fetchRunSummaries(toriiUrl: string, player: string): Promise<RunSummary[]> {
  if (!toriiUrl) return [];
  const data = await toriiQuery<RunStateQuery>(
    toriiUrl,
    `
      query Runs($player: ContractAddress!) {
        athanor01RunStateModels(
          where: { playerEQ: $player }
          order: { field: GAME_ID, direction: DESC }
          limit: 20
        ) {
          edges {
            node {
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
    `,
    { player },
  );

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

async function toriiQuery<T>(
  toriiUrl: string,
  query: string,
  variables: Record<string, unknown>,
): Promise<T> {
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

function hexishToBigInt(value: string | number): bigint {
  if (typeof value === "number") return BigInt(value);
  return value.startsWith("0x") ? BigInt(value) : BigInt(value || "0");
}
