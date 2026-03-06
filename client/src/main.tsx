import { StrictMode } from 'react'
import { useEffect, useMemo, useState } from 'react'
import { createRoot } from 'react-dom/client'
import { type Chain } from '@starknet-react/chains'
import { StarknetConfig, jsonRpcProvider, paymasterRpcProvider } from '@starknet-react/core'
import './index.css'
import App from './App.tsx'
import { LoadingScreen } from './ui/LoadingScreen'
import { dojoConfig } from '../dojo.config'
import { cartridgeConnector } from './cartridgeConnector'
import { DojoProvider, type DojoSetup } from './dojo/context'
import { setupDojo } from './dojo/setup'

function createSlotChain(nodeUrl: string): Chain {
  return {
    id: 0x4b4154414e41n,
    network: 'slot-local',
    name: 'Slot Local Katana',
    nativeCurrency: {
      address: '0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7',
      name: 'Ether',
      symbol: 'ETH',
      decimals: 18,
    },
    testnet: true,
    rpcUrls: {
      default: { http: [nodeUrl] },
      public: { http: [nodeUrl] },
    },
    paymasterRpcUrls: {
      avnu: { http: [] },
    },
  }
}

function Root() {
  const [dojo, setDojo] = useState<DojoSetup | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [initStatus, setInitStatus] = useState('Bootstrapping client...')
  const [initError, setInitError] = useState<string | null>(null)

  const chain = useMemo(() => createSlotChain(dojoConfig().rpcUrl), [])
  const provider = useMemo(
    () =>
      jsonRpcProvider({
        rpc: () => ({ nodeUrl: dojoConfig().rpcUrl }),
      }),
    [],
  )
  const paymaster = useMemo(
    () =>
      paymasterRpcProvider({
        rpc: () => ({ nodeUrl: dojoConfig().rpcUrl }),
      }),
    [],
  )

  useEffect(() => {
    let mounted = true

    console.groupCollapsed('[athanor:init] root')
    console.info('[athanor:init] env', {
      rpcUrl: dojoConfig().rpcUrl,
      toriiUrl: dojoConfig().toriiUrl,
      worldAddress: dojoConfig().manifest.world.address,
      deployType: import.meta.env.VITE_PUBLIC_DEPLOY_TYPE ?? 'dev',
    })

    setInitStatus('Connecting to local Katana and Torii...')

    setupDojo()
      .then((result) => {
        console.info('[athanor:init] setupDojo resolved')
        if (mounted) {
          setDojo(result)
          setInitStatus('Initialization complete')
          setIsLoading(false)
        }
      })
      .catch((error: unknown) => {
        console.error('[athanor:init] setupDojo failed', error)
        const message = error instanceof Error ? error.message : String(error)
        if (mounted) {
          setInitError(message)
          setInitStatus('Initialization failed')
          setIsLoading(false)
        }
      })
      .finally(() => {
        console.groupEnd()
      })

    return () => {
      mounted = false
    }
  }, [])

  if (isLoading || !dojo) {
    return <LoadingScreen status={initStatus} error={initError} />
  }

  return (
    <StarknetConfig autoConnect chains={[chain]} provider={provider} paymasterProvider={paymaster} connectors={[cartridgeConnector]}>
      <DojoProvider value={dojo}>
        <App />
      </DojoProvider>
    </StarknetConfig>
  )
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <Root />
  </StrictMode>,
)
