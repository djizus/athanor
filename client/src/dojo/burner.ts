// Dev "burner" signer — for local Katana testing only.
//
// Uses the pre-funded Katana seed=0 account (addr + private key read from
// VITE_BURNER_FUNDING_* in .env.local). No keys are generated or persisted
// in localStorage yet — all players in dev share this account. That's fine
// for single-player tactical testing; revisit when multi-account dev flows
// become relevant.

import { Account, RpcProvider } from "starknet";
import type { DojoConfig } from "./config.js";

export interface Signer {
  provider: RpcProvider;
  account: Account;
}

export function createSigner(cfg: DojoConfig): Signer {
  const provider = new RpcProvider({ nodeUrl: cfg.rpcUrl });
  const account = new Account({
    provider,
    address: cfg.fundingAccount,
    signer: cfg.fundingKey,
  });
  return { provider, account };
}
