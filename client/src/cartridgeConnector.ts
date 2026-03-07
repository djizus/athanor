import ControllerConnector from '@cartridge/connector/controller'
import type { SessionPolicies } from '@cartridge/presets'
import { dojoConfig } from '../dojo.config'

function buildPolicies(): SessionPolicies {
  const config = dojoConfig()
  const findAddress = (tag: string) => {
    const contract = config.manifest.contracts.find((item) => item.tag === tag)
    return contract?.address ?? '0x0'
  }

  const play = findAddress('ATHANOR-Play')

  return {
    contracts: {
      [play]: {
        methods: [
          { name: 'mint_game', entrypoint: 'mint_game' },
          { name: 'create', entrypoint: 'create' },
          { name: 'clue', entrypoint: 'clue' },
          { name: 'craft', entrypoint: 'craft' },
          { name: 'recruit', entrypoint: 'recruit' },
          { name: 'buff', entrypoint: 'buff' },
          { name: 'explore', entrypoint: 'explore' },
          { name: 'claim', entrypoint: 'claim' },
        ],
      },
    },
  }
}

export const cartridgeConnector = new ControllerConnector({
  chains: [{ rpcUrl: dojoConfig().rpcUrl }],
  policies: buildPolicies(),
})
