import { create } from 'zustand'

export type PendingTxAction = 'craft' | 'craftBatch' | 'clue' | 'buff' | 'explore' | 'claim' | 'recruit' | 'surrender'

export type PendingTx = {
  id: string
  action: PendingTxAction
  heroId?: number
  inventoryDelta: Map<number, number>
  goldDelta: number
  effectsDelta: Map<number, number>
}

interface PendingTxState {
  pending: Map<string, PendingTx>
  settled: Map<string, PendingTx>
  addTx: (tx: PendingTx) => void
  finalizeTx: (id: string, success: boolean) => void
  clearAll: () => void
  isActionPending: (action: PendingTxAction | PendingTxAction[]) => boolean
  isHeroActionPending: (heroId: number, action: PendingTxAction | PendingTxAction[]) => boolean
  getInventoryDeltas: () => Map<number, number>
  getGoldDelta: () => number
  getEffectsDeltas: () => Map<number, number>
}

const SETTLED_TX_TTL_MS = 4000

function sumMapDeltas(maps: Map<number, number>[]): Map<number, number> {
  const result = new Map<number, number>()
  for (const deltas of maps) {
    for (const [id, delta] of deltas) {
      if (delta === 0) continue
      result.set(id, (result.get(id) ?? 0) + delta)
    }
  }
  for (const [id, delta] of result) {
    if (delta === 0) result.delete(id)
  }
  return result
}

export const usePendingTxStore = create<PendingTxState>((set, get) => ({
  pending: new Map(),
  settled: new Map(),

  addTx: (tx) => set((state) => {
    const next = new Map(state.pending)
    next.set(tx.id, tx)
    return { pending: next }
  }),

  finalizeTx: (id, success) => {
    const tx = get().pending.get(id)
    if (!tx) return

    set((state) => {
      const nextPending = new Map(state.pending)
      nextPending.delete(id)
      if (!success) return { pending: nextPending }

      const nextSettled = new Map(state.settled)
      nextSettled.set(id, tx)
      return { pending: nextPending, settled: nextSettled }
    })

    if (!success) return

    setTimeout(() => {
      set((state) => {
        if (!state.settled.has(id)) return state
        const nextSettled = new Map(state.settled)
        nextSettled.delete(id)
        return { settled: nextSettled }
      })
    }, SETTLED_TX_TTL_MS)
  },

  clearAll: () => set({ pending: new Map(), settled: new Map() }),

  isActionPending: (action) => {
    const actions = Array.isArray(action) ? action : [action]
    const actionSet = new Set(actions)
    for (const tx of get().pending.values()) {
      if (actionSet.has(tx.action)) return true
    }
    return false
  },

  isHeroActionPending: (heroId, action) => {
    const actions = Array.isArray(action) ? action : [action]
    const actionSet = new Set(actions)
    for (const tx of get().pending.values()) {
      if (tx.heroId === heroId && actionSet.has(tx.action)) return true
    }
    return false
  },

  getInventoryDeltas: () => sumMapDeltas([
    ...Array.from(get().pending.values(), (tx) => tx.inventoryDelta),
    ...Array.from(get().settled.values(), (tx) => tx.inventoryDelta),
  ]),

  getGoldDelta: () => {
    let total = 0
    for (const tx of get().pending.values()) {
      total += tx.goldDelta
    }
    for (const tx of get().settled.values()) {
      total += tx.goldDelta
    }
    return total
  },

  getEffectsDeltas: () => sumMapDeltas([
    ...Array.from(get().pending.values(), (tx) => tx.effectsDelta),
    ...Array.from(get().settled.values(), (tx) => tx.effectsDelta),
  ]),
}))
