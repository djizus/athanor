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

type ManifestJson = {
  world: { address: string }
  contracts: Array<{ tag: string; address: string }>
}

const SYSTEM_TAGS = [
  'athanor-game_system',
  'athanor-exploration_system',
  'athanor-crafting_system',
  'athanor-hero_system',
  'athanor-config_system',
  'athanor-play_system',
] as const

function loadManifest(): ManifestJson | null {
  try {
    const modules = import.meta.glob<ManifestJson>('./manifest_*.json', { eager: true })
    const deployType = import.meta.env.VITE_PUBLIC_DEPLOY_TYPE ?? 'dev'
    const key = `./manifest_${deployType}.json`
    return modules[key] ?? Object.values(modules)[0] ?? null
  } catch {
    return null
  }
}

export function dojoConfig() {
  const toriiUrl = import.meta.env.VITE_PUBLIC_TORII_URL ?? 'http://localhost:8080'
  const rpcUrl = import.meta.env.VITE_PUBLIC_NODE_URL ?? 'http://localhost:5050'
  const worldAddress = import.meta.env.VITE_PUBLIC_WORLD_ADDRESS ?? '0x0'

  const manifestJson = loadManifest()
  const contractMap = new Map<string, string>()
  if (manifestJson) {
    for (const c of manifestJson.contracts) {
      contractMap.set(c.tag, c.address)
    }
  }

  const manifest: DojoManifest = {
    world: {
      address: worldAddress,
    },
    contracts: SYSTEM_TAGS.map((tag) => ({
      tag,
      address: contractMap.get(tag) ?? worldAddress,
    })),
  }

  return {
    toriiUrl,
    rpcUrl,
    manifest,
  }
}
