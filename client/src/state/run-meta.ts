export type RunChain = "mainnet" | "katana";

export type RunStatus = "active" | "ended_pending_oracle" | "settled" | "claimed";

export interface RunMeta {
  tokenId: number;
  chain: RunChain;
  status: RunStatus;
  finalScore?: number;
  settledAt?: number;
  reward?: bigint;
  roomId?: number;
  turnIndex?: number;
  startedAt?: bigint;
  endedAt?: bigint;
}

export function isActiveRun(run: RunMeta): boolean {
  return run.status === "active";
}

export function isPendingSettlement(run: RunMeta): boolean {
  return run.status === "ended_pending_oracle";
}
