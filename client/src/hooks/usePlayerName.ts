import { useEffect, useState } from 'react'
import { useConnect } from '@starknet-react/core'

function truncateAddress(hex: string): string {
  if (hex.length <= 12) return hex
  return `${hex.slice(0, 6)}...${hex.slice(-4)}`
}

export function usePlayerName(address: string | undefined): {
  displayName: string
  isUsername: boolean
} {
  const { connectors } = useConnect()
  const [username, setUsername] = useState<string | undefined>()

  useEffect(() => {
    if (!address) {
      setUsername(undefined)
      return
    }

    const connector = connectors[0] as unknown as { username?: () => Promise<string | undefined> } | undefined
    const usernameFn = connector?.username

    if (typeof usernameFn === 'function') {
      usernameFn()
        .then((name) => setUsername(name ?? undefined))
        .catch(() => setUsername(undefined))
    }
  }, [address, connectors])

  if (!address) return { displayName: '', isUsername: false }

  if (username) return { displayName: username, isUsername: true }

  return { displayName: truncateAddress(address), isUsername: false }
}
