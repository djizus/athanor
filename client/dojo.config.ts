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
  'ATHANOR-Play',
  'ATHANOR-Setup',
] as const

function loadManifest(): ManifestJson | null {
  try {
    const modules = import.meta.glob<ManifestJson>('./manifest_*.json', { eager: true })
    const deployType = import.meta.env.VITE_PUBLIC_DEPLOY_TYPE ?? 'dev'
    const key = `./manifest_${deployType}.json`
    const manifest = modules[key] ?? null
    if (!manifest && Object.keys(modules).length > 0) {
      console.warn(`[dojo:config] No manifest found for deploy type "${deployType}" (expected ${key}). Available: ${Object.keys(modules).join(', ')}. Contract addresses will use VITE_PUBLIC_WORLD_ADDRESS as fallback.`)
    }
    return manifest
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
