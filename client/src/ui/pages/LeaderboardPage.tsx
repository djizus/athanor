import { useEffect, useMemo, useState } from 'react'
import { useAccount } from '@starknet-react/core'
import { num } from 'starknet'
import { useNavigationStore } from '@/stores/navigationStore'
import { bitmapPopcount } from '@/game/packer'

const { VITE_PUBLIC_TORII_URL, VITE_PUBLIC_NAMESPACE } = import.meta.env
const namespace = VITE_PUBLIC_NAMESPACE || 'ATHANOR'

const PAGE_SIZE = 10

type LeaderboardRow = {
  gameId: bigint
  discoveredCount: number
  duration: number
  player: string
  ownerAddress: string
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

function hexToNumber(hex: string | number): number {
  if (typeof hex === 'number') return hex
  return Number(BigInt(hex))
}

async function fetchLeaderboardSQL(): Promise<LeaderboardRow[]> {
  if (!VITE_PUBLIC_TORII_URL) return []

  const query = `
    SELECT
      g.id AS game_id,
      g.grimoire,
      g.started_at,
      g.ended_at,
      tb.account_address AS player,
      COALESCE(c.username, '') AS username
    FROM "${namespace}-Game" AS g
    JOIN token_balances AS tb
      ON tb.token_id LIKE '%:' || g.id
      AND tb.account_address != '0x0000000000000000000000000000000000000000000000000000000000000000'
    LEFT JOIN controllers AS c ON c.address = tb.account_address
    WHERE g.ended_at != '0x0000000000000000'
  `

  try {
    const res = await fetch(`${VITE_PUBLIC_TORII_URL}/sql?q=${encodeURIComponent(query)}`)
    if (!res.ok) return []
    const data: Record<string, string | number>[] = await res.json()

    return data.map((row) => {
      const grimoire =
        typeof row.grimoire === 'number' ? row.grimoire : hexToNumber(row.grimoire)
      const startedAt = hexToNumber(row.started_at)
      const endedAt = hexToNumber(row.ended_at)
      const playerAddr = String(row.player || '')
      const username = String(row.username || '')

      return {
        gameId: BigInt(String(row.game_id)),
        discoveredCount: bitmapPopcount(grimoire),
        duration: endedAt - startedAt,
        player: username || (playerAddr ? truncateAddress(playerAddr) : '...'),
        ownerAddress: playerAddr,
      }
    })
  } catch {
    return []
  }
}

export function LeaderboardPage() {
  const { navigate } = useNavigationStore()
  const { address } = useAccount()

  const [page, setPage] = useState(0)
  const [rawRows, setRawRows] = useState<LeaderboardRow[]>([])

  useEffect(() => {
    fetchLeaderboardSQL().then(setRawRows)
  }, [])

  const rows = useMemo(() => {
    return [...rawRows].sort((a, b) => {
      if (b.discoveredCount !== a.discoveredCount) return b.discoveredCount - a.discoveredCount
      return a.duration - b.duration
    })
  }, [rawRows])

  const totalPages = Math.max(1, Math.ceil(rows.length / PAGE_SIZE))
  const pageRows = rows.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE)
  const connectedHex = address ? num.toHex(address) : ''

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
            <>
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
                    {pageRows.map((row, i) => {
                      const rank = page * PAGE_SIZE + i + 1
                      const isMe =
                        connectedHex &&
                        row.ownerAddress &&
                        num.toHex(row.ownerAddress) === connectedHex
                      return (
                        <tr
                          key={String(row.gameId)}
                          className={isMe ? 'leaderboard-row-me' : undefined}
                        >
                          <td>{rank}</td>
                          <td>{isMe ? <strong>{row.player}</strong> : row.player}</td>
                          <td>{formatDuration(row.duration)}</td>
                        </tr>
                      )
                    })}
                  </tbody>
                </table>
              </div>
              {totalPages > 1 && (
                <div className="leaderboard-pagination">
                  <button disabled={page === 0} onClick={() => setPage(page - 1)}>
                    &lsaquo; Prev
                  </button>
                  <span className="leaderboard-pagination-info">
                    {page + 1} / {totalPages}
                  </span>
                  <button disabled={page >= totalPages - 1} onClick={() => setPage(page + 1)}>
                    Next &rsaquo;
                  </button>
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  )
}
