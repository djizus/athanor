import { getSyncEntities } from '@dojoengine/state'
import type { Clause } from '@dojoengine/torii-client'
import { ToriiClient } from '@dojoengine/torii-client'
import { dojoConfig } from '../../dojo.config'
import { contractComponents } from './contractModels'
import { createSystemCalls } from './systems'
import { world } from './world'

const modelNames = [
  'GameSession',
  'GameSeed',
  'Hero',
  'HeroPendingIngredient',
  'Recipe',
  'IngredientBalance',
  'PotionItem',
  'FailedCombo',
  'GameSettings',
  'GameSettingsMetadata',
  'PlayerMeta',
] as const

export async function setupDojo() {
  const config = dojoConfig()
  const namespace = import.meta.env.VITE_PUBLIC_NAMESPACE ?? 'athanor'
  const entityModels = modelNames.map((name) => `${namespace}-${name}`)

  const toriiClient = new ToriiClient({
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

  // Cast to expected type — all components share the same RECS Component shape
  const clientModels = Object.values(contractComponents) as Parameters<typeof getSyncEntities>[1]
  const sync = await getSyncEntities(toriiClient, clientModels, clause, undefined, entityModels)
  const client = createSystemCalls(config.manifest)

  return {
    client,
    clientModels,
    contractComponents,
    config,
    world,
    sync,
    toriiClient,
  }
}
