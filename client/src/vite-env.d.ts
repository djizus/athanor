/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_RPC_URL?: string;
  readonly VITE_WORLD_ADDRESS?: string;
  readonly VITE_ACTIONS_ADDRESS?: string;
  readonly VITE_LORDS_ADDRESS?: string;
  readonly VITE_BURNER_FUNDING_ACCOUNT?: string;
  readonly VITE_BURNER_FUNDING_KEY?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
