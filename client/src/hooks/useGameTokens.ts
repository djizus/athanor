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
  game_id: bigint
  discovered_count: number
  game_over: boolean
  started_at: number
  ended_at: number
  gold: number
  hero_count: number
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
          erc721Tokens.map((t: ERC721TokenMeta) => BigInt(t.tokenId)),
        )

        const gameEntities = runQuery([Has(contractComponents.Game)])
        const gameList: GameToken[] = []
        const seen = new Set<bigint>()

        for (const entity of gameEntities) {
          const game = getComponentValue(contractComponents.Game, entity)
          if (!game || BigInt(game.id) === 0n) continue
          const gid = BigInt(game.id)
          if (!ownedTokenIds.has(gid)) continue
          if (seen.has(gid)) continue
          seen.add(gid)

          gameList.push({
            game_id: gid,
            discovered_count: bitmapPopcount(game.grimoire),
            game_over: game.ended_at > 0,
            started_at: game.started_at,
            ended_at: game.ended_at,
            gold: game.gold,
            hero_count: bitmapPopcount(game.heroes),
          })
        }

        gameList.sort((a, b) => (b.game_id > a.game_id ? 1 : b.game_id < a.game_id ? -1 : 0))
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
