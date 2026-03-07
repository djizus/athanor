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

export function dojoConfig() {
  const toriiUrl = import.meta.env.VITE_PUBLIC_TORII_URL
  const rpcUrl = import.meta.env.VITE_PUBLIC_NODE_URL
  const worldAddress = import.meta.env.VITE_PUBLIC_WORLD_ADDRESS
  const playAddress = import.meta.env.VITE_PUBLIC_PLAY_ADDRESS

  if (!toriiUrl || !rpcUrl || !worldAddress || !playAddress) {
    throw new Error(
      'Missing required env vars: VITE_PUBLIC_TORII_URL, VITE_PUBLIC_NODE_URL, VITE_PUBLIC_WORLD_ADDRESS, VITE_PUBLIC_PLAY_ADDRESS',
    )
  }

  const manifest: DojoManifest = {
    world: {
      address: worldAddress,
    },
    contracts: [
      { tag: 'ATHANOR-Play', address: playAddress },
      { tag: 'ATHANOR-Setup', address: worldAddress },
    ],
  }

  return {
    toriiUrl,
    rpcUrl,
    manifest,
  }
}
