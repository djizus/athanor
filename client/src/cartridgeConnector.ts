import { type Connector } from '@starknet-react/core'
import ControllerConnector from '@cartridge/connector/controller'
import type { SessionPolicies } from '@cartridge/presets'
import { shortString } from 'starknet'
import { dojoConfig } from '../dojo.config'

const NAMESPACE = import.meta.env.VITE_PUBLIC_NAMESPACE ?? 'ATHANOR'
const RPC_URL = dojoConfig().rpcUrl

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
          { name: 'Mint Game', entrypoint: 'mint_game' },
          { name: 'Create', entrypoint: 'create' },
          { name: 'Clue', entrypoint: 'clue' },
          { name: 'Craft', entrypoint: 'craft' },
          { name: 'Recruit', entrypoint: 'recruit' },
          { name: 'Buff', entrypoint: 'buff' },
          { name: 'Explore', entrypoint: 'explore' },
          { name: 'Claim', entrypoint: 'claim' },
        ],
      },
    },
  }
}

function createConnector(): Connector | null {
  if (typeof window === 'undefined') return null

  return new ControllerConnector({
    chains: [{ rpcUrl: RPC_URL }],
    defaultChainId: shortString.encodeShortString('SN_SEPOLIA').toString(),
    namespace: NAMESPACE,
    slot: 'athanor-sepolia',
    policies: buildPolicies(),
  }) as unknown as Connector
}

export const cartridgeConnector = createConnector()
