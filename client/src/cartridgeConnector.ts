import ControllerConnector from '@cartridge/connector/controller'
import type { SessionPolicies } from '@cartridge/presets'
import { dojoConfig } from '../dojo.config'

function buildPolicies(): SessionPolicies {
  const config = dojoConfig()
  const findAddress = (tag: string) => {
    const contract = config.manifest.contracts.find((item) => item.tag === tag)
    return contract?.address ?? '0x0'
  }

  const game = findAddress('athanor-game_system')
  const exploration = findAddress('athanor-exploration_system')
  const crafting = findAddress('athanor-crafting_system')
  const hero = findAddress('athanor-hero_system')

  return {
    contracts: {
      [game]: {
        methods: [
          { name: 'create', entrypoint: 'create' },
          { name: 'glean', entrypoint: 'glean' },
          { name: 'craft', entrypoint: 'craft' },
          { name: 'surrender', entrypoint: 'surrender' },
        ],
      },
      [exploration]: {
        methods: [
          { name: 'send_expedition', entrypoint: 'send_expedition' },
          { name: 'claim_loot', entrypoint: 'claim_loot' },
        ],
      },
      [crafting]: {
        methods: [
          { name: 'craft', entrypoint: 'craft' },
          { name: 'craft_recipe', entrypoint: 'craft_recipe' },
          { name: 'buy_hint', entrypoint: 'buy_hint' },
        ],
      },
      [hero]: {
        methods: [
          { name: 'recruit_hero', entrypoint: 'recruit_hero' },
          { name: 'apply_potion', entrypoint: 'apply_potion' },
        ],
      },
    },
  }
}

export const cartridgeConnector = new ControllerConnector({
  chains: [{ rpcUrl: dojoConfig().rpcUrl }],
  policies: buildPolicies(),
})

console.info('[athanor:init] cartridgeConnector configured', {
  rpcUrl: dojoConfig().rpcUrl,
})
