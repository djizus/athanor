import { manifest } from "./src/config/manifest";

export type Config = ReturnType<typeof dojoConfig>;

export function dojoConfig() {
  const toriiUrl = import.meta.env.VITE_PUBLIC_TORII_URL;
  const rpcUrl = import.meta.env.VITE_PUBLIC_NODE_URL;

  if (!toriiUrl || !rpcUrl) {
    throw new Error(
      "Missing required env vars: VITE_PUBLIC_TORII_URL, VITE_PUBLIC_NODE_URL",
    );
  }

  return {
    toriiUrl,
    rpcUrl,
    manifest,
  };
}
