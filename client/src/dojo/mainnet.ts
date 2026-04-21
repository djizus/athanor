import { CallData, type ProviderInterface } from "starknet";
import type { DojoConfig } from "./config.js";
import { isActiveRun, isPendingSettlement, type RunMeta } from "../state/run-meta.js";

export interface MainnetRunRegistry {
  listOwnedRuns: (address: string) => Promise<RunMeta[]>;
  listActiveRuns: (address: string) => Promise<RunMeta[]>;
  listPendingSettlements: (address: string) => Promise<RunMeta[]>;
  listSettledRuns: (address: string) => Promise<RunMeta[]>;
  getRunSettlement: (tokenId: number) => Promise<RunMeta | null>;
}

interface MainnetRunRegistryOptions {
  provider: ProviderInterface;
  cfg: DojoConfig;
}

interface RunSnapshot {
  roomId: number;
  turnIndex: number;
  score: number;
  startedAt: bigint;
  endedAt: bigint;
}

/**
 * Mainnet-shaped discovery abstraction.
 *
 * Temporary backend uses new RPC views on the gameplay contract:
 * - view_player_run_count
 * - view_player_run_id
 * - view_run_owner
 * - view_run_state
 *
 * This keeps Torii out of correctness paths and lets us swap to true
 * mainnet/Denshokan registry reads later without changing menu consumers.
 */
export function createMainnetRunRegistry(opts: MainnetRunRegistryOptions): MainnetRunRegistry {
  const cache = new Map<number, RunMeta>();

  const loadRuns = async (address: string): Promise<RunMeta[]> => {
    const countRow = await callView(opts, "view_player_run_count", [address], 1);
    const count = Number(countRow?.[0] ?? 0n);
    if (count <= 0) return [];

    const indices = Array.from({ length: count }, (_, i) => count - 1 - i);
    const gameIds = await Promise.all(
      indices.map(async (index) => {
        const row = await callView(opts, "view_player_run_id", [address, `${index}`], 1);
        return Number(row?.[0] ?? 0n);
      }),
    );

    const runs: RunMeta[] = [];
    for (const tokenId of gameIds) {
      if (!tokenId) continue;
      const owner = await callView(opts, "view_run_owner", [`${tokenId}`], 1);
      const ownerAddr = owner?.[0] ?? 0n;
      if (ownerAddr === 0n) continue;

      const snapshot = await readRunSnapshot(opts, address, tokenId);
      if (!snapshot) continue;
      const run: RunMeta = {
        tokenId,
        chain: "mainnet",
        status: snapshot.endedAt === 0n ? "active" : "ended_pending_oracle",
        finalScore: snapshot.endedAt === 0n ? undefined : snapshot.score,
        roomId: snapshot.roomId,
        turnIndex: snapshot.turnIndex,
        startedAt: snapshot.startedAt,
        endedAt: snapshot.endedAt,
      };
      cache.set(run.tokenId, run);
      runs.push(run);
    }

    return runs;
  };

  return {
    async listOwnedRuns(address) {
      return loadRuns(address);
    },

    async listActiveRuns(address) {
      const all = await loadRuns(address);
      return all.filter(isActiveRun);
    },

    async listPendingSettlements(address) {
      const all = await loadRuns(address);
      return all.filter(isPendingSettlement);
    },

    async listSettledRuns(address) {
      const all = await loadRuns(address);
      return all.filter((run) => run.status === "settled" || run.status === "claimed");
    },

    async getRunSettlement(tokenId) {
      const cached = cache.get(tokenId);
      if (cached) return cached;

      const owner = await callView(opts, "view_run_owner", [`${tokenId}`], 1);
      const ownerValue = owner?.[0] ?? 0n;
      if (ownerValue === 0n) return null;
      const ownerAddress = bigintToHex(ownerValue);
      const snapshot = await readRunSnapshot(opts, ownerAddress, tokenId);
      if (!snapshot) return null;

      const run: RunMeta = {
        tokenId,
        chain: "mainnet",
        status: snapshot.endedAt === 0n ? "active" : "ended_pending_oracle",
        finalScore: snapshot.endedAt === 0n ? undefined : snapshot.score,
        roomId: snapshot.roomId,
        turnIndex: snapshot.turnIndex,
        startedAt: snapshot.startedAt,
        endedAt: snapshot.endedAt,
      };
      cache.set(tokenId, run);
      return run;
    },
  };
}

async function readRunSnapshot(
  opts: MainnetRunRegistryOptions,
  player: string,
  gameId: number,
): Promise<RunSnapshot | null> {
  const fields = await callView(opts, "view_run_state", [player, `${gameId}`], 11);
  if (!fields) return null;
  return {
    roomId: Number(fields[1] ?? 0n),
    turnIndex: Number(fields[2] ?? 0n),
    score: Number(fields[7] ?? 0n),
    startedAt: fields[9] ?? 0n,
    endedAt: fields[10] ?? 0n,
  };
}

async function callView(
  opts: MainnetRunRegistryOptions,
  entrypoint: string,
  calldata: string[],
  expectedLen: number,
): Promise<bigint[] | null> {
  try {
    const result = await opts.provider.callContract({
      contractAddress: opts.cfg.actionsAddress,
      entrypoint,
      calldata: CallData.compile(calldata),
    });
    if (!result || result.length < expectedLen) return null;
    return result.slice(0, expectedLen).map((value) => BigInt(value));
  } catch (err) {
    console.debug("[mainnet] view failed", { entrypoint, calldata, err });
    return null;
  }
}

function bigintToHex(value: bigint): string {
  return `0x${value.toString(16)}`;
}
