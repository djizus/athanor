type DojoManifestContract = {
  tag: string
  address: string
}

type DojoManifest = {
  world: {
    address: string
  }
  contracts: DojoManifestContract[]
}

const SYSTEM_TAGS = [
  'ATHANOR-Play',
  'ATHANOR-Setup',
] as const

export function dojoConfig() {
  const toriiUrl = import.meta.env.VITE_PUBLIC_TORII_URL
  const rpcUrl = import.meta.env.VITE_PUBLIC_NODE_URL
  const worldAddress = import.meta.env.VITE_PUBLIC_WORLD_ADDRESS

  if (!toriiUrl || !rpcUrl || !worldAddress) {
    throw new Error(
      'Missing required env vars: VITE_PUBLIC_TORII_URL, VITE_PUBLIC_NODE_URL, VITE_PUBLIC_WORLD_ADDRESS',
    )
  }

  const manifest: DojoManifest = {
    world: {
      address: worldAddress,
    },
    contracts: SYSTEM_TAGS.map((tag) => ({
      tag,
      address: worldAddress,
    })),
  }

  return {
    toriiUrl,
    rpcUrl,
    manifest,
  }
}
