import { getSyncEntities } from '@dojoengine/state'
import type { Clause } from '@dojoengine/torii-client'
import { ToriiClient } from '@dojoengine/torii-client'
import { dojoConfig } from '../../dojo.config'
import { contractComponents } from './contractModels'
import { createSystemCalls } from './systems'
import { world } from './world'

const modelNames = [
  'Game',
  'Character',
  'Discovery',
  'Hint',
  'GameSession',
  'GameSeed',
  'GameSettings',
  'GameSettingsMetadata',
  'Config',
] as const

type SetupPhase = 'config' | 'connectivity' | 'torii' | 'sync' | 'systems' | 'done'

function logPhase(phase: SetupPhase, details: Record<string, unknown> = {}) {
  const timestamp = new Date().toISOString()
  console.info(`[athanor:init] ${timestamp} phase=${phase}`, details)
}

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
  const rpcCheck = fetch(rpcUrl, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'starknet_chainId', params: [] }),
  })

  const toriiCheck = fetch(`${toriiUrl}/graphql`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ query: '{ __typename }' }),
  })

  const [rpcResponse, toriiResponse] = await Promise.allSettled([
    withTimeout(rpcCheck, 7000, 'RPC probe'),
    withTimeout(toriiCheck, 7000, 'Torii probe'),
  ])

  if (rpcResponse.status === 'rejected') {
    throw new Error(`RPC probe failed (${rpcUrl}): ${String(rpcResponse.reason)}`)
  }
  if (!rpcResponse.value.ok) {
    throw new Error(`RPC probe failed (${rpcUrl}): HTTP ${rpcResponse.value.status}`)
  }

  if (toriiResponse.status === 'rejected') {
    throw new Error(`Torii probe failed (${toriiUrl}): ${String(toriiResponse.reason)}`)
  }
  if (!toriiResponse.value.ok) {
    throw new Error(`Torii probe failed (${toriiUrl}): HTTP ${toriiResponse.value.status}`)
  }
}

export async function setupDojo(onStatus?: (status: string) => void) {
  console.groupCollapsed('[athanor:init] setupDojo')
  try {
    onStatus?.('Validating configuration...')
    const config = dojoConfig()
    const namespace = import.meta.env.VITE_PUBLIC_NAMESPACE ?? 'ATHANOR'
    const entityModels = modelNames.map((name) => `${namespace}-${name}`)

    logPhase('config', {
      rpcUrl: config.rpcUrl,
      toriiUrl: config.toriiUrl,
      worldAddress: config.manifest.world.address,
      modelCount: entityModels.length,
    })

    if (!config.manifest.world.address || config.manifest.world.address === '0x0') {
      throw new Error('Invalid world address (0x0). Check VITE_PUBLIC_WORLD_ADDRESS in client/.env.')
    }

    onStatus?.('Connecting to RPC and Torii...')
    logPhase('connectivity')
    await probeConnectivity(config.rpcUrl, config.toriiUrl)

    onStatus?.('Initializing indexer...')
    logPhase('torii')
    const toriiClient = await new ToriiClient({
      toriiUrl: config.toriiUrl,
      worldAddress: config.manifest.world.address,
    })

    const clause: Clause = {
      Keys: {
        keys: [],
        pattern_matching: 'VariableLen',
        models: entityModels,
      },
    }

    const clientModels = Object.values(contractComponents) as Parameters<typeof getSyncEntities>[1]

    onStatus?.('Syncing game state...')
    logPhase('sync', { entityModels })
    const sync = await withTimeout(
      getSyncEntities(toriiClient, clientModels, clause, undefined, entityModels),
      20000,
      'Entity sync initialization',
    )
    console.info('[athanor:init] sync result:', sync)

    onStatus?.('Preparing game systems...')
    logPhase('systems')
    const client = createSystemCalls(config.manifest)
    console.info('[athanor:init] system calls created, contracts:', config.manifest.contracts.map(c => c.tag))

    logPhase('done')
    return {
      client,
      clientModels,
      contractComponents,
      config,
      world,
      sync,
      toriiClient,
    }
  } finally {
    console.groupEnd()
  }
}
