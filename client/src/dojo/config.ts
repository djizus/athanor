// Slot (and future mainnet/sepolia) addresses + RPC read from Vite env.
// `scripts/deploy_slot.sh` writes `client/.env.slot` with the `VITE_PUBLIC_*`
// set used here; `pnpm slot` activates that mode file. The naming matches
// zkube-budokan so future Controller migration is a drop-in.

export interface DojoConfig {
  rpcUrl: string;
  toriiUrl: string;
  worldAddress: string;
  actionsAddress: string;
  lordsAddress: string;
  fundingAccount: string;
  fundingKey: string;
}

export function loadDojoConfig(): DojoConfig {
  const cfg = {
    rpcUrl: import.meta.env.VITE_PUBLIC_NODE_URL ?? "",
    toriiUrl: import.meta.env.VITE_PUBLIC_TORII ?? "",
    worldAddress: import.meta.env.VITE_PUBLIC_WORLD_ADDRESS ?? "",
    actionsAddress: import.meta.env.VITE_PUBLIC_ACTIONS_ADDRESS ?? "",
    lordsAddress: import.meta.env.VITE_PUBLIC_LORDS_ADDRESS ?? "",
    fundingAccount: import.meta.env.VITE_PUBLIC_MASTER_ADDRESS ?? "",
    fundingKey: import.meta.env.VITE_PUBLIC_MASTER_PRIVATE_KEY ?? "",
  };

  console.info("[dojo-config] loaded", {
    mode: import.meta.env.MODE,
    rpcUrl: cfg.rpcUrl,
    toriiUrl: cfg.toriiUrl,
    worldAddress: cfg.worldAddress,
    actionsAddress: cfg.actionsAddress,
    lordsAddress: cfg.lordsAddress,
    fundingAccount: cfg.fundingAccount,
    fundingKeyPresent: Boolean(cfg.fundingKey),
  });

  return cfg;
}

export function isConfigured(cfg: DojoConfig): boolean {
  const configured = Boolean(
    cfg.rpcUrl &&
      cfg.actionsAddress &&
      cfg.actionsAddress !== "0x0" &&
      cfg.lordsAddress &&
      cfg.lordsAddress !== "0x0" &&
      cfg.fundingAccount &&
      cfg.fundingKey,
  );

  if (!configured) {
    console.warn("[dojo-config] missing required values", {
      rpcUrl: Boolean(cfg.rpcUrl),
      actionsAddress: Boolean(cfg.actionsAddress) && cfg.actionsAddress !== "0x0",
      lordsAddress: Boolean(cfg.lordsAddress) && cfg.lordsAddress !== "0x0",
      fundingAccount: Boolean(cfg.fundingAccount),
      fundingKeyPresent: Boolean(cfg.fundingKey),
    });
  }

  return configured;
}
