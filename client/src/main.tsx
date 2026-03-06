import { StrictMode } from 'react'
import { useEffect, useMemo, useState } from 'react'
import { createRoot } from 'react-dom/client'
import { type Chain } from '@starknet-react/chains'
import { StarknetConfig, jsonRpcProvider } from '@starknet-react/core'
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

  const chain = useMemo(() => createSlotChain(dojoConfig().rpcUrl), [])
  const provider = useMemo(
    () =>
      jsonRpcProvider({
        rpc: () => ({ nodeUrl: dojoConfig().rpcUrl }),
      }),
    [],
  )

  useEffect(() => {
    let mounted = true

    setupDojo()
      .then((result) => {
        if (mounted) {
          setDojo(result)
          setIsLoading(false)
        }
      })
      .catch(() => {
        if (mounted) {
          setIsLoading(false)
        }
      })

    return () => {
      mounted = false
    }
  }, [])

  if (isLoading || !dojo) {
    return <LoadingScreen />
  }

  return (
    <StarknetConfig autoConnect chains={[chain]} provider={provider} connectors={[cartridgeConnector]}>
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
