// Dojo / Starknet client for Athanor:Ascend dev.
// Wraps raw transactions against the deployed actions contract and the mock
// LORDS ERC20. Address selection is driven by src/dojo/config.ts.

import { CallData, cairo, type Call, type RpcProvider } from "starknet";
import type { Signer } from "./burner.js";
import type { DojoConfig } from "./config.js";
import { fetchCombatState } from "./rpc.js";
import { createMainnetRunRegistry, type MainnetRunRegistry } from "./mainnet.js";
import type { CombatState } from "../state/combat.js";
import type { RunMeta } from "../state/run-meta.js";
import type { Tier } from "../state/tiers.js";

// Action type IDs mirror contracts/src/systems/actions.cairo.
export const ACTION_TYPE_MOVE = 0;
export const ACTION_TYPE_ABILITY = 1;

export interface DojoSession {
  address: string;
  disconnect: () => Promise<void>;
}

export interface LordsBalance {
  raw: bigint;
  wholeTokens: bigint;
}

export interface DojoClient {
  connected: boolean;
  address: string;
  runRegistry: MainnetRunRegistry;
  connect: () => Promise<DojoSession>;
  lordsBalance: () => Promise<LordsBalance>;
  mintLords: (wholeAmount: bigint) => Promise<string>;
  approveLords: (amountRaw: bigint) => Promise<string>;
  spawn: (gameId: number, settingsId: number) => Promise<string>;
  enterRoom: (gameId: number, roomId: number) => Promise<string>;
  confirmTurn: (gameId: number, actionsPacked: number[]) => Promise<string>;
  listRuns: () => Promise<RunMeta[]>;
  loadRun: (gameId: number, tier: Tier) => Promise<CombatState | null>;
  nextGameId: () => Promise<number>;
}

const DECIMALS = 10n ** 18n;
const TX_POLL_ATTEMPTS = 45;
const TX_POLL_DELAY_MS = 1500;

export function createDojoClient(cfg: DojoConfig, signer: Signer): DojoClient {
  const { account } = signer;
  const runRegistry = createMainnetRunRegistry({ provider: signer.provider, cfg });

  const callData = CallData.compile;

  const api: DojoClient = {
    connected: true,
    address: account.address,
    runRegistry,

    async connect() {
      return {
        address: account.address,
        async disconnect() {
          /* no-op for burner */
        },
      };
    },

    async lordsBalance() {
      const res = await signer.provider.callContract({
        contractAddress: cfg.lordsAddress,
        entrypoint: "balance_of",
        calldata: callData([account.address]),
      });
      // u256 is returned as [low, high]
      const low = BigInt(res[0] ?? "0x0");
      const high = BigInt(res[1] ?? "0x0");
      const raw = (high << 128n) | low;
      return { raw, wholeTokens: raw / DECIMALS };
    },

    async mintLords(wholeAmount) {
      const raw = wholeAmount * DECIMALS;
      const amount = cairo.uint256(raw);
      const call: Call = {
        contractAddress: cfg.lordsAddress,
        entrypoint: "mint",
        calldata: callData([account.address, amount]),
      };
      const tx = await account.execute(call);
      await waitForAcceptedTransaction(signer.provider, tx.transaction_hash);
      return tx.transaction_hash;
    },

    async approveLords(amountRaw) {
      const amount = cairo.uint256(amountRaw);
      const call: Call = {
        contractAddress: cfg.lordsAddress,
        entrypoint: "approve",
        calldata: callData([cfg.actionsAddress, amount]),
      };
      const tx = await account.execute(call);
      await waitForAcceptedTransaction(signer.provider, tx.transaction_hash);
      return tx.transaction_hash;
    },

    async spawn(gameId, settingsId) {
      const call: Call = {
        contractAddress: cfg.actionsAddress,
        entrypoint: "spawn",
        calldata: callData([gameId, settingsId]),
      };
      const tx = await account.execute(call);
      await waitForAcceptedTransaction(signer.provider, tx.transaction_hash);
      return tx.transaction_hash;
    },

    async enterRoom(gameId, roomId) {
      const call: Call = {
        contractAddress: cfg.actionsAddress,
        entrypoint: "enter_room",
        calldata: callData([gameId, roomId]),
      };
      const tx = await account.execute(call);
      await waitForAcceptedTransaction(signer.provider, tx.transaction_hash);
      return tx.transaction_hash;
    },

    async confirmTurn(gameId, actionsPacked) {
      const call: Call = {
        contractAddress: cfg.actionsAddress,
        entrypoint: "confirm_turn",
        calldata: callData([gameId, actionsPacked]),
      };
      const tx = await account.execute(call);
      await waitForAcceptedTransaction(signer.provider, tx.transaction_hash);
      return tx.transaction_hash;
    },

    async listRuns() {
      return runRegistry.listOwnedRuns(account.address);
    },

    async loadRun(gameId, tier) {
      for (let attempt = 0; attempt < 8; attempt++) {
        const snapshot = await fetchCombatState(
          signer.provider,
          cfg,
          account.address,
          gameId,
          tier,
        );
        if (snapshot) return snapshot;
        await new Promise((resolve) => window.setTimeout(resolve, 400));
      }
      return null;
    },

    async nextGameId() {
      try {
        const runs = await api.listRuns();
        return runs.reduce((max, run) => Math.max(max, run.tokenId), 0) + 1;
      } catch {
        return 1;
      }
    },
  };

  return api;
}

// Helpers for composing the `actions_packed` array consumed by confirm_turn.
export function packMove(targetX: number, targetY: number): number[] {
  return [ACTION_TYPE_MOVE, targetX, targetY];
}

export function packAbility(
  abilityId: number,
  targetMode: number,
  targetA: number,
  targetB: number,
): number[] {
  return [ACTION_TYPE_ABILITY, abilityId, targetMode, targetA, targetB];
}

async function waitForAcceptedTransaction(provider: RpcProvider, txHash: string): Promise<void> {
  for (let attempt = 0; attempt < TX_POLL_ATTEMPTS; attempt++) {
    try {
      const receipt = await provider.getTransactionReceipt(txHash);
      const finalityStatus = readReceiptField(receipt, "finality_status", "finalityStatus");
      const executionStatus = readReceiptField(receipt, "execution_status", "executionStatus");
      if (executionStatus === "REVERTED") {
        const revertReason = readReceiptField(receipt, "revert_reason", "revertReason");
        throw new Error(revertReason || `Transaction ${txHash} reverted`);
      }
      if (
        executionStatus === "SUCCEEDED" ||
        finalityStatus === "ACCEPTED_ON_L2" ||
        finalityStatus === "ACCEPTED_ON_L1"
      ) {
        return;
      }
    } catch (err) {
      if (attempt === TX_POLL_ATTEMPTS - 1 || !isPendingReceiptError(err)) {
        throw err;
      }
    }

    await new Promise((resolve) => window.setTimeout(resolve, TX_POLL_DELAY_MS));
  }

  throw new Error(`Transaction ${txHash} was not accepted in time`);
}

function readReceiptField(receipt: object, ...keys: string[]): string {
  for (const key of keys) {
    const value = Reflect.get(receipt, key);
    if (typeof value === "string") return value;
  }
  return "";
}

function isPendingReceiptError(err: unknown): boolean {
  const message = err instanceof Error ? err.message : String(err);
  return (
    message.includes("Transaction hash not found") ||
    message.includes("TRANSACTION_HASH_NOT_FOUND") ||
    message.includes("29: Transaction hash not found")
  );
}
