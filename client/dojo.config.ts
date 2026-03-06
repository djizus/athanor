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
  const toriiUrl = import.meta.env.VITE_PUBLIC_TORII_URL ?? 'http://localhost:8080'
  const rpcUrl = import.meta.env.VITE_PUBLIC_NODE_URL ?? 'http://localhost:5050'
  const worldAddress = import.meta.env.VITE_PUBLIC_WORLD_ADDRESS ?? '0x0'

  const manifest: DojoManifest = {
    world: {
      address: worldAddress,
    },
    contracts: [
      { tag: 'athanor-game_system', address: worldAddress },
      { tag: 'athanor-exploration_system', address: worldAddress },
      { tag: 'athanor-crafting_system', address: worldAddress },
      { tag: 'athanor-hero_system', address: worldAddress },
      { tag: 'athanor-config_system', address: worldAddress },
    ],
  }

  return {
    toriiUrl,
    rpcUrl,
    manifest,
  }
}
