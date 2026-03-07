import { type Connector } from '@starknet-react/core'
import ControllerConnector from '@cartridge/connector/controller'
import type { ControllerOptions, SessionPolicies } from '@cartridge/controller'
import { shortString } from 'starknet'
import { dojoConfig } from '../dojo.config'

const NAMESPACE = import.meta.env.VITE_PUBLIC_NAMESPACE ?? 'ATHANOR'
const RPC_URL = dojoConfig().rpcUrl

export const stringToFelt = (v: string) =>
  v ? shortString.encodeShortString(v) : '0x0'

function clearControllerStorage() {
  localStorage.removeItem('sessionSigner')
  localStorage.removeItem('session')
  localStorage.removeItem('sessionPolicies')
  localStorage.removeItem('lastUsedConnector')

  for (let i = localStorage.length - 1; i >= 0; i--) {
    const key = localStorage.key(i)
    if (key?.startsWith('@cartridge/')) {
      localStorage.removeItem(key)
    }
  }

  if (typeof indexedDB !== 'undefined') {
    indexedDB.databases?.().then((dbs) => {
      for (const db of dbs) {
        if (db.name) indexedDB.deleteDatabase(db.name)
      }
    }).catch(() => {
      for (const name of ['@cartridge', 'controller', 'keyval-store']) {
        try { indexedDB.deleteDatabase(name) } catch { /* noop */ }
      }
    })
  }
}

const CONTROLLER_SESSION_VERSION = '1'

function migrateControllerSessions() {
  try {
    const storedVersion = localStorage.getItem('controllerSessionVersion')
    if (storedVersion === CONTROLLER_SESSION_VERSION) return

    console.info('[athanor:controller] Clearing stale Controller sessions', {
      reason: `version: ${storedVersion} → ${CONTROLLER_SESSION_VERSION}`,
    })

    clearControllerStorage()
    localStorage.setItem('controllerSessionVersion', CONTROLLER_SESSION_VERSION)
  } catch (e) {
    console.warn('[athanor:controller] Session migration skipped', e)
  }
}

if (typeof window !== 'undefined') {
  migrateControllerSessions()
}

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

// ── Connector ──────────────────────────────────────────────────────

function createConnector(): Connector | null {
  if (typeof window === 'undefined') return null

  const options: ControllerOptions = {
    chains: [
      { rpcUrl: RPC_URL },
      { rpcUrl: 'https://api.cartridge.gg/x/starknet/mainnet' },
    ],
    defaultChainId: stringToFelt('SN_SEPOLIA').toString(),
    namespace: NAMESPACE,
    slot: 'athanor-sepolia',
    policies: buildPolicies(),
    signupOptions: ['google', 'discord', 'webauthn', 'password'],
  }

  return new ControllerConnector(options) as unknown as Connector
}

export const cartridgeConnector: Connector | null = createConnector()
export default cartridgeConnector
