import { useEffect, useMemo, useState } from 'react'
import { Has, getComponentValue } from '@dojoengine/recs'
import { useEntityQuery } from '@dojoengine/react'
import { RpcProvider, num } from 'starknet'
import { useDojo } from '@/dojo/useDojo'
import { useNavigationStore } from '@/stores/navigationStore'
import { bitmapPopcount } from '@/game/packer'

const { VITE_PUBLIC_NODE_URL, VITE_PUBLIC_TOKEN_ADDRESS } = import.meta.env

type LeaderboardRow = {
  gameId: number
  discoveredCount: number
  duration: number
  player: string
}

function formatDuration(seconds: number): string {
  if (seconds <= 0) return '-'
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  const s = seconds % 60
  if (h > 0) return `${h}h ${m}m ${s}s`
  return `${m}m ${s}s`
}

function truncateAddress(hex: string): string {
  if (hex.length <= 12) return hex
  return `${hex.slice(0, 6)}...${hex.slice(-4)}`
}

async function fetchTokenOwners(gameIds: number[]): Promise<Map<number, string>> {
  const map = new Map<number, string>()
  if (!VITE_PUBLIC_NODE_URL || !VITE_PUBLIC_TOKEN_ADDRESS || gameIds.length === 0) return map

  const provider = new RpcProvider({ nodeUrl: VITE_PUBLIC_NODE_URL })

  const results = await Promise.allSettled(
    gameIds.map(async (gameId) => {
      const result = await provider.callContract({
        contractAddress: VITE_PUBLIC_TOKEN_ADDRESS,
        entrypoint: 'owner_of',
        calldata: [num.toHex(gameId), '0x0'],
      })
      return { gameId, owner: num.toHex(result[0]) }
    }),
  )

  for (const result of results) {
    if (result.status === 'fulfilled') {
      map.set(result.value.gameId, result.value.owner)
    }
  }
  return map
}

async function resolveUsernames(addresses: string[]): Promise<Map<string, string>> {
  const map = new Map<string, string>()
  if (addresses.length === 0) return map

  try {
    const normalized = addresses.map(num.toHex)
    const res = await fetch('https://api.cartridge.gg/lookup', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ addresses: normalized }),
    })
    if (!res.ok) return map
    const data: { results?: { username: string; addresses: string[] }[] } = await res.json()
    for (const result of data.results ?? []) {
      for (const addr of result.addresses) {
        map.set(num.toHex(addr), result.username)
      }
    }
  } catch {
    // Cartridge API unavailable — fallback to truncated addresses
  }
  return map
}

export function LeaderboardPage() {
  const { contractComponents } = useDojo()
  const gameEntities = useEntityQuery([Has(contractComponents.Game)])
  const { navigate } = useNavigationStore()

  const [owners, setOwners] = useState<Map<number, string>>(new Map())
  const [usernames, setUsernames] = useState<Map<string, string>>(new Map())

  const completedGames = useMemo(() => {
    const games: { id: number; discoveredCount: number; duration: number }[] = []
    for (const entity of gameEntities) {
      const game = getComponentValue(contractComponents.Game, entity)
      if (!game || game.ended_at <= 0) continue
      games.push({
        id: game.id,
        discoveredCount: bitmapPopcount(game.grimoire),
        duration: game.ended_at - game.started_at,
      })
    }
    return games
  }, [contractComponents.Game, gameEntities])

  useEffect(() => {
    const ids = completedGames.map((g) => g.id)
    if (ids.length === 0) return
    fetchTokenOwners(ids).then(setOwners)
  }, [completedGames])

  useEffect(() => {
    const addresses = [...new Set(owners.values())]
    if (addresses.length === 0) return
    resolveUsernames(addresses).then(setUsernames)
  }, [owners])

  const rows: LeaderboardRow[] = useMemo(() => {
    return completedGames
      .map((g) => {
        const ownerAddr = owners.get(g.id) ?? ''
        const username = ownerAddr ? usernames.get(num.toHex(ownerAddr)) ?? '' : ''
        return {
          gameId: g.id,
          discoveredCount: g.discoveredCount,
          duration: g.duration,
          player: username || (ownerAddr ? truncateAddress(ownerAddr) : '...'),
        }
      })
      .sort((a, b) => {
        if (b.discoveredCount !== a.discoveredCount) return b.discoveredCount - a.discoveredCount
        return a.duration - b.duration
      })
  }, [completedGames, owners, usernames])

  return (
    <div className="glass-page">
      <div className="glass-page-panel">
        <div className="glass-page-header">
          <h1 className="glass-page-title">Leaderboard</h1>
          <button onClick={() => navigate('home')}>Back</button>
        </div>

        <div className="glass-page-body">
          {rows.length === 0 ? (
            <p style={{ color: 'var(--text-secondary)' }}>No completed games yet.</p>
          ) : (
            <div className="table-scroll">
              <table className="leaderboard-table">
                <thead>
                  <tr>
                    <th>Rank</th>
                    <th>Player</th>
                    <th>Time</th>
                  </tr>
                </thead>
                <tbody>
                  {rows.map((row, index) => (
                    <tr key={row.gameId}>
                      <td>{index + 1}</td>
                      <td>{row.player}</td>
                      <td>{formatDuration(row.duration)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
