// Dojo / Starknet client for Athanor:Ascend dev.
// Wraps raw transactions against the deployed actions contract and the mock
// LORDS ERC20. Address selection is driven by src/dojo/config.ts.

import { CallData, cairo, type Call } from "starknet";
import type { Signer } from "./burner.js";
import type { DojoConfig } from "./config.js";

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
  connect: () => Promise<DojoSession>;
  lordsBalance: () => Promise<LordsBalance>;
  mintLords: (wholeAmount: bigint) => Promise<string>;
  approveLords: (amountRaw: bigint) => Promise<string>;
  spawn: (gameId: number, settingsId: number) => Promise<string>;
  enterRoom: (gameId: number, roomId: number) => Promise<string>;
  confirmTurn: (gameId: number, actionsPacked: number[]) => Promise<string>;
}

const DECIMALS = 10n ** 18n;

export function createDojoClient(cfg: DojoConfig, signer: Signer): DojoClient {
  const { account } = signer;

  const callData = CallData.compile;

  const api: DojoClient = {
    connected: true,
    address: account.address,

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
      await signer.provider.waitForTransaction(tx.transaction_hash);
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
      await signer.provider.waitForTransaction(tx.transaction_hash);
      return tx.transaction_hash;
    },

    async spawn(gameId, settingsId) {
      const call: Call = {
        contractAddress: cfg.actionsAddress,
        entrypoint: "spawn",
        calldata: callData([gameId, settingsId]),
      };
      const tx = await account.execute(call);
      await signer.provider.waitForTransaction(tx.transaction_hash);
      return tx.transaction_hash;
    },

    async enterRoom(gameId, roomId) {
      const call: Call = {
        contractAddress: cfg.actionsAddress,
        entrypoint: "enter_room",
        calldata: callData([gameId, roomId]),
      };
      const tx = await account.execute(call);
      await signer.provider.waitForTransaction(tx.transaction_hash);
      return tx.transaction_hash;
    },

    async confirmTurn(gameId, actionsPacked) {
      const call: Call = {
        contractAddress: cfg.actionsAddress,
        entrypoint: "confirm_turn",
        calldata: callData([gameId, actionsPacked]),
      };
      const tx = await account.execute(call);
      await signer.provider.waitForTransaction(tx.transaction_hash);
      return tx.transaction_hash;
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
