import { useCallback, useEffect, useState } from 'react'
import { useAccount } from '@starknet-react/core'
import type ControllerConnector from '@cartridge/connector/controller'

function truncateAddress(hex: string): string {
  if (hex.length <= 12) return hex
  return `${hex.slice(0, 6)}...${hex.slice(-4)}`
}

export function usePlayerName(address: string | undefined): {
  displayName: string
  isUsername: boolean
} {
  const { connector } = useAccount()
  const [username, setUsername] = useState<string | undefined>()

  const getUsername = useCallback(async () => {
    if (!connector || connector.id !== 'controller') return

    try {
      const ctrl = connector as unknown as ControllerConnector
      const name = await ctrl.username()
      setUsername(name || undefined)
    } catch {
      setUsername(undefined)
    }
  }, [connector])

  useEffect(() => {
    getUsername()
  }, [getUsername, address])

  if (!address) return { displayName: '', isUsername: false }

  if (username) return { displayName: username, isUsername: true }

  return { displayName: truncateAddress(address), isUsername: false }
}
