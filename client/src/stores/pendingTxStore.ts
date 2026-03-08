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
  addTx: (tx: PendingTx) => void
  removeTx: (id: string) => void
  clearAll: () => void
  isActionPending: (action: PendingTxAction | PendingTxAction[]) => boolean
  isHeroActionPending: (heroId: number, action: PendingTxAction | PendingTxAction[]) => boolean
  getInventoryDeltas: () => Map<number, number>
  getGoldDelta: () => number
  getEffectsDeltas: () => Map<number, number>
}

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

  addTx: (tx) => set((state) => {
    const next = new Map(state.pending)
    next.set(tx.id, tx)
    return { pending: next }
  }),

  removeTx: (id) => set((state) => {
    if (!state.pending.has(id)) return state
    const next = new Map(state.pending)
    next.delete(id)
    return { pending: next }
  }),

  clearAll: () => set({ pending: new Map() }),

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

  getInventoryDeltas: () => sumMapDeltas(Array.from(get().pending.values(), (tx) => tx.inventoryDelta)),

  getGoldDelta: () => {
    let total = 0
    for (const tx of get().pending.values()) {
      total += tx.goldDelta
    }
    return total
  },

  getEffectsDeltas: () => sumMapDeltas(Array.from(get().pending.values(), (tx) => tx.effectsDelta)),
}))
