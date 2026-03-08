import { useMemo } from 'react'
import { unpackEffects } from '@/game/packer'
import { useInventory } from '@/hooks/useInventory'
import { usePendingTxStore } from '@/stores/pendingTxStore'
import type { PendingTx } from '@/stores/pendingTxStore'

type GameType = {
  gold: number
  effects: bigint | number | string
}

function aggregateMapDeltas(
  pending: Map<string, PendingTx>,
  pickDeltas: (tx: PendingTx) => Map<number, number>,
): Map<number, number> {
  const aggregated = new Map<number, number>()
  for (const tx of pending.values()) {
    const deltas = pickDeltas(tx)
    for (const [id, delta] of deltas) {
      if (delta === 0) continue
      aggregated.set(id, (aggregated.get(id) ?? 0) + delta)
    }
  }
  for (const [id, delta] of aggregated) {
    if (delta === 0) aggregated.delete(id)
  }
  return aggregated
}

export function useOptimisticInventory(gameId: number | null) {
  const baseInventory = useInventory(gameId)
  const pending = usePendingTxStore((s) => s.pending)
  const settled = usePendingTxStore((s) => s.settled)

  const deltas = useMemo(
    () => aggregateMapDeltas(new Map([...pending, ...settled]), (tx) => tx.inventoryDelta),
    [pending, settled],
  )

  return useMemo(
    () => baseInventory.map((item) => ({
      ingredient_id: item.ingredient_id,
      quantity: Math.max(0, item.quantity + (deltas.get(item.ingredient_id) ?? 0)),
    })),
    [baseInventory, deltas],
  )
}

export function useOptimisticGold(game: GameType | undefined) {
  const baseGold = game?.gold ?? 0
  const pending = usePendingTxStore((s) => s.pending)
  const settled = usePendingTxStore((s) => s.settled)

  const delta = useMemo(() => {
    let total = 0
    for (const tx of pending.values()) {
      total += tx.goldDelta
    }
    for (const tx of settled.values()) {
      total += tx.goldDelta
    }
    return total
  }, [pending, settled])

  return Math.max(0, baseGold + delta)
}

export function useOptimisticEffects(game: GameType | undefined) {
  const pending = usePendingTxStore((s) => s.pending)
  const settled = usePendingTxStore((s) => s.settled)

  const base = useMemo(
    () => (game ? unpackEffects(BigInt(game.effects)) : Array(30).fill(0) as number[]),
    [game],
  )

  const deltas = useMemo(
    () => aggregateMapDeltas(new Map([...pending, ...settled]), (tx) => tx.effectsDelta),
    [pending, settled],
  )

  return useMemo(
    () => base.map((qty, idx) => Math.max(0, qty + (deltas.get(idx) ?? 0))),
    [base, deltas],
  )
}
