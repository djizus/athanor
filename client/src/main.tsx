import { StrictMode } from 'react'
import { useEffect, useMemo, useState } from 'react'
import { createRoot } from 'react-dom/client'
import { sepolia } from '@starknet-react/chains'
import { StarknetConfig, jsonRpcProvider, paymasterRpcProvider } from '@starknet-react/core'
import './index.css'
import App from './App.tsx'
import { LoadingScreen } from './ui/LoadingScreen'
import { dojoConfig } from '../dojo.config'
import { cartridgeConnector } from './cartridgeConnector'
import { DojoProvider, type DojoSetup } from './dojo/context'
import { setupDojo } from './dojo/setup'

function Root() {
  const [dojo, setDojo] = useState<DojoSetup | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [initStatus, setInitStatus] = useState('Bootstrapping client...')
  const [initError, setInitError] = useState<string | null>(null)

  const rpcUrl = dojoConfig().rpcUrl
  const chain = useMemo(
    () => ({
      ...sepolia,
      rpcUrls: {
        ...sepolia.rpcUrls,
        default: { http: [rpcUrl] },
        public: { http: [rpcUrl] },
      },
    }),
    [rpcUrl],
  )
  const provider = useMemo(
    () =>
      jsonRpcProvider({
        rpc: () => ({ nodeUrl: rpcUrl }),
      }),
    [rpcUrl],
  )
  const paymaster = useMemo(
    () =>
      paymasterRpcProvider({
        rpc: () => ({ nodeUrl: rpcUrl }),
      }),
    [rpcUrl],
  )

  useEffect(() => {
    let mounted = true

    console.groupCollapsed('[athanor:init] root')
    console.info('[athanor:init] env', {
      rpcUrl: dojoConfig().rpcUrl,
      toriiUrl: dojoConfig().toriiUrl,
      worldAddress: dojoConfig().manifest.world.address,
    })

    setupDojo(setInitStatus)
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

  console.info('[athanor:render] Root render — isLoading:', isLoading, 'dojo:', !!dojo, 'error:', initError)

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
