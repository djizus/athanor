// Addresses + RPC read from Vite env (written by scripts/deploy_dev.sh into
// client/.env.local). Missing values leave the client in offline-only mode.

export interface DojoConfig {
  rpcUrl: string;
  worldAddress: string;
  actionsAddress: string;
  lordsAddress: string;
  fundingAccount: string;
  fundingKey: string;
}

function readEnv(key: string): string {
  return (import.meta.env[key] as string | undefined) ?? "";
}

export function loadDojoConfig(): DojoConfig {
  return {
    rpcUrl: readEnv("VITE_RPC_URL"),
    worldAddress: readEnv("VITE_WORLD_ADDRESS"),
    actionsAddress: readEnv("VITE_ACTIONS_ADDRESS"),
    lordsAddress: readEnv("VITE_LORDS_ADDRESS"),
    fundingAccount: readEnv("VITE_BURNER_FUNDING_ACCOUNT"),
    fundingKey: readEnv("VITE_BURNER_FUNDING_KEY"),
  };
}

export function isConfigured(cfg: DojoConfig): boolean {
  return Boolean(
    cfg.rpcUrl &&
      cfg.actionsAddress &&
      cfg.actionsAddress !== "0x0" &&
      cfg.lordsAddress &&
      cfg.lordsAddress !== "0x0" &&
      cfg.fundingAccount &&
      cfg.fundingKey,
  );
}
