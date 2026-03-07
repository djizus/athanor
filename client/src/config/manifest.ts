import dev from "../../../contracts/manifest_dev.json";
import sepolia from "../../../contracts/manifest_sepolia.json";

const deployType = import.meta.env.VITE_PUBLIC_DEPLOY_TYPE;

const manifests: Record<string, typeof dev> = {
  sepolia: sepolia as typeof dev,
  dev,
};

export const manifest = deployType in manifests ? manifests[deployType] : dev;

export type Manifest = typeof manifest;
