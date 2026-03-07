import { StrictMode } from 'react'
import { useEffect, useState } from 'react'
import { createRoot } from 'react-dom/client'
import { sepolia, mainnet } from '@starknet-react/chains'
import { StarknetConfig, voyager, jsonRpcProvider, type Connector } from '@starknet-react/core'
import './index.css'
import App from './App.tsx'
import { LoadingScreen } from './ui/LoadingScreen'
import { dojoConfig } from '../dojo.config'
import cartridgeConnector from './cartridgeConnector'
import { DojoProvider, type DojoSetup } from './dojo/context'
import { setupDojo } from './dojo/setup'

const rpcUrl = dojoConfig().rpcUrl
const connectors: Connector[] = cartridgeConnector ? [cartridgeConnector] : []

function rpc() {
  return { nodeUrl: rpcUrl }
}

function Root() {
  const [dojo, setDojo] = useState<DojoSetup | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [initStatus, setInitStatus] = useState('Bootstrapping client...')
  const [initError, setInitError] = useState<string | null>(null)

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

  return (
    <StarknetConfig
      autoConnect
      chains={[sepolia, mainnet]}
      connectors={connectors}
      defaultChainId={sepolia.id}
      explorer={voyager}
      provider={jsonRpcProvider({ rpc })}
    >
      {isLoading || !dojo ? (
        <LoadingScreen status={initStatus} error={initError} />
      ) : (
        <DojoProvider value={dojo}>
          <App />
        </DojoProvider>
      )}
    </StarknetConfig>
  )
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <Root />
  </StrictMode>,
)
