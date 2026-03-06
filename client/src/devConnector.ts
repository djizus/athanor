import { Connector } from '@starknet-react/core'
import { Account, type AccountInterface, type ProviderInterface } from 'starknet'

const KATANA_CHAIN_ID = 0x4b4154414e41n

const KATANA_PREDEPLOYED = {
  address: '0x127fd5f1fe78a71f8bcd1fec63e3fe2f0486b6ecd5c86a0466c3a21fa5cfcec',
  privateKey: '0xc5b2fcab997346f3ea1c00b002ecf6f382c5f9c9659a3894eb783c5320f912',
} as const

export class PredeployedConnector extends Connector {
  private _account: AccountInterface | null = null

  get id() {
    return 'katana-predeployed'
  }

  get name() {
    return 'Katana Dev'
  }

  get icon() {
    return { dark: 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg"/>', light: 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg"/>' }
  }

  available(): boolean {
    return true
  }

  async ready(): Promise<boolean> {
    return true
  }

  async connect() {
    this.emit('connect', { account: KATANA_PREDEPLOYED.address, chainId: KATANA_CHAIN_ID })
    return { account: KATANA_PREDEPLOYED.address, chainId: KATANA_CHAIN_ID }
  }

  async disconnect(): Promise<void> {
    this._account = null
    this.emit('disconnect')
  }

  async account(provider: ProviderInterface): Promise<AccountInterface> {
    if (!this._account) {
      this._account = new Account({
        provider,
        address: KATANA_PREDEPLOYED.address,
        signer: KATANA_PREDEPLOYED.privateKey,
        cairoVersion: '1',
      })
    }
    return this._account
  }

  async chainId(): Promise<bigint> {
    return KATANA_CHAIN_ID
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  async request(_call: any): Promise<never> {
    throw new Error('Wallet RPC not supported in dev mode')
  }
}

export const devConnector = new PredeployedConnector()
