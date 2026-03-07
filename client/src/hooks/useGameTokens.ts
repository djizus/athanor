import { useEffect, useState, useCallback } from 'react'
import { Has, getComponentValue, runQuery } from '@dojoengine/recs'
import { useDojo } from '@/dojo/useDojo'
import { bitmapPopcount } from '@/game/packer'
import { padAddress } from '@/dojo/entityId'

const { VITE_PUBLIC_TORII_URL, VITE_PUBLIC_TOKEN_ADDRESS } = import.meta.env

const TOKEN_BALANCES_QUERY = `
  query GetTokenBalances($accountAddress: String!, $limit: Int) {
    tokenBalances(accountAddress: $accountAddress, limit: $limit) {
      edges {
        node {
          tokenMetadata {
            __typename
            ... on ERC721__Token {
              tokenId
              contractAddress
            }
          }
        }
      }
    }
  }
`

interface ERC721TokenMeta {
  __typename: 'ERC721__Token'
  tokenId: string
  contractAddress: string
}

interface TokenBalanceNode {
  tokenMetadata: ERC721TokenMeta | { __typename: string }
}

export type GameToken = {
  game_id: number
  discovered_count: number
  game_over: boolean
  started_at: number
}

export function useGameTokens(playerAddress: string | undefined) {
  const { contractComponents } = useDojo()
  const [games, setGames] = useState<GameToken[]>([])
  const [loading, setLoading] = useState(true)
  const [refreshTrigger, setRefreshTrigger] = useState(0)

  const refetch = useCallback(() => setRefreshTrigger((n) => n + 1), [])

  useEffect(() => {
    if (!playerAddress) {
      setGames([])
      setLoading(false)
      return
    }

    const fetchGames = async () => {
      setLoading(true)
      try {
        const toriiUrl = VITE_PUBLIC_TORII_URL
        const tokenAddress = VITE_PUBLIC_TOKEN_ADDRESS?.toLowerCase()

        if (!toriiUrl) {
          setGames([])
          return
        }

        const paddedOwner = padAddress(playerAddress)
        const response = await fetch(`${toriiUrl}/graphql`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            query: TOKEN_BALANCES_QUERY,
            variables: { accountAddress: paddedOwner, limit: 100 },
          }),
        })

        if (!response.ok) {
          throw new Error(`Torii GraphQL failed: ${response.status}`)
        }

        const result = await response.json()
        const edges = result.data?.tokenBalances?.edges ?? []

        const erc721Tokens = edges
          .map((edge: { node: TokenBalanceNode }) => edge.node.tokenMetadata)
          .filter((meta: ERC721TokenMeta | { __typename: string }): meta is ERC721TokenMeta => {
            if (meta.__typename !== 'ERC721__Token') return false
            if (tokenAddress) {
              const addr = (meta as ERC721TokenMeta).contractAddress?.toLowerCase()
              return addr?.includes(tokenAddress.replace('0x', ''))
            }
            return true
          })

        const ownedTokenIds = new Set(
          erc721Tokens.map((t: ERC721TokenMeta) => Number(BigInt(t.tokenId))),
        )

        const gameEntities = runQuery([Has(contractComponents.Game)])
        const gameList: GameToken[] = []
        const seen = new Set<number>()

        for (const entity of gameEntities) {
          const game = getComponentValue(contractComponents.Game, entity)
          if (!game || game.id === 0) continue
          if (!ownedTokenIds.has(game.id)) continue
          if (seen.has(game.id)) continue
          seen.add(game.id)

          gameList.push({
            game_id: game.id,
            discovered_count: bitmapPopcount(game.grimoire),
            game_over: game.ended_at > 0,
            started_at: game.started_at,
          })
        }

        gameList.sort((a, b) => b.game_id - a.game_id)
        setGames(gameList)
      } catch (error) {
        console.error('[useGameTokens] Error:', error)
        setGames([])
      } finally {
        setLoading(false)
      }
    }

    fetchGames()
  }, [contractComponents.Game, playerAddress, refreshTrigger])

  return { games, loading, refetch }
}
