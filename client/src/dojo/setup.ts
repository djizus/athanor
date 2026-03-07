import { getSyncEntities } from '@dojoengine/state'
import { KeysClause } from '@dojoengine/sdk'
import { ToriiClient } from '@dojoengine/torii-client'
import { dojoConfig } from '../../dojo.config'
import { defineContractComponents } from './contractModels'
import { createSystemCalls } from './systems'
import { world } from './world'

export type SetupResult = Awaited<ReturnType<typeof setupDojo>>

const { VITE_PUBLIC_NAMESPACE } = import.meta.env
const namespace = VITE_PUBLIC_NAMESPACE || 'ATHANOR'

async function withTimeout<T>(promise: Promise<T>, ms: number, label: string): Promise<T> {
  let timeoutId: ReturnType<typeof setTimeout> | undefined
  const timeoutPromise = new Promise<never>((_, reject) => {
    timeoutId = setTimeout(() => {
      reject(new Error(`${label} timed out after ${ms}ms`))
    }, ms)
  })

  try {
    return await Promise.race([promise, timeoutPromise])
  } finally {
    if (timeoutId) clearTimeout(timeoutId)
  }
}

async function probeConnectivity(rpcUrl: string, toriiUrl: string): Promise<void> {
  const [rpcResponse, toriiResponse] = await Promise.allSettled([
    withTimeout(
      fetch(rpcUrl, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'starknet_chainId', params: [] }),
      }),
      7000,
      'RPC probe',
    ),
    withTimeout(
      fetch(`${toriiUrl}/graphql`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ query: '{ __typename }' }),
      }),
      7000,
      'Torii probe',
    ),
  ])

  if (rpcResponse.status === 'rejected') {
    throw new Error(`RPC unreachable (${rpcUrl}): ${String(rpcResponse.reason)}`)
  }
  if (!rpcResponse.value.ok) {
    throw new Error(`RPC error (${rpcUrl}): HTTP ${rpcResponse.value.status}`)
  }
  if (toriiResponse.status === 'rejected') {
    throw new Error(`Torii unreachable (${toriiUrl}): ${String(toriiResponse.reason)}`)
  }
  if (!toriiResponse.value.ok) {
    throw new Error(`Torii error (${toriiUrl}): HTTP ${toriiResponse.value.status}`)
  }
}

export async function setupDojo(onStatus?: (status: string) => void) {
  const config = dojoConfig()
  const worldAddress = config.manifest.world.address

  if (!worldAddress || worldAddress === '0x0') {
    throw new Error('Invalid world address. Check client/.env.')
  }

  onStatus?.('Connecting to RPC and Torii...')
  await probeConnectivity(config.rpcUrl, config.toriiUrl)

  onStatus?.('Initializing indexer...')
  const toriiClient = await new ToriiClient({
    toriiUrl: config.toriiUrl,
    worldAddress,
  })

  const contractComponents = defineContractComponents(world)

  const modelsToSync = [
    `${namespace}-Game`,
    `${namespace}-Character`,
    `${namespace}-Discovery`,
    `${namespace}-Hint`,
    `${namespace}-GameSession`,
    `${namespace}-GameSeed`,
  ] as `${string}-${string}`[]

  const modelsToWatch = [
    `${namespace}-Game`,
    `${namespace}-Character`,
    `${namespace}-Discovery`,
    `${namespace}-Hint`,
    `${namespace}-GameSession`,
    `${namespace}-GameSeed`,
    `${namespace}-GameSettings`,
    `${namespace}-GameSettingsMetadata`,
    `${namespace}-Config`,
  ]

  onStatus?.('Syncing game state...')
  const sync = await withTimeout(
    getSyncEntities(
      toriiClient,
      contractComponents as any,
      KeysClause(modelsToSync, [undefined], 'VariableLen').build(),
      [],
      modelsToWatch,
      10000,
      false,
    ),
    30000,
    'Entity sync',
  )

  onStatus?.('Preparing game systems...')
  const client = createSystemCalls(config.manifest)

  return {
    client,
    contractComponents,
    config,
    world,
    sync,
    toriiClient,
  }
}
