import type { AccountInterface, Call, InvokeFunctionResponse } from 'starknet'
import { txToast } from '@/stores/toastStore'

const DEBOUNCE_MS = 1000

type QueueEntry = {
  calls: Call[]
  label: string
  resolve: (value: InvokeFunctionResponse) => void
  reject: (reason: unknown) => void
}

let queue: QueueEntry[] = []
let timer: number | null = null
let currentAccount: AccountInterface | null = null

export function setTxBatcherAccount(account: AccountInterface | null) {
  currentAccount = account
}

export function enqueueTx(calls: Call[], label: string): Promise<InvokeFunctionResponse> {
  return new Promise((resolve, reject) => {
    queue.push({ calls, label, resolve, reject })
    if (timer != null) window.clearTimeout(timer)
    timer = window.setTimeout(flushTxQueue, DEBOUNCE_MS)
  })
}

function formatBatchToast(labels: string[]): string {
  if (labels.length === 1) return labels[0]
  return `Batch (${labels.length}): ${labels.join(', ')}`
}

export async function flushTxQueue(): Promise<void> {
  if (timer != null) {
    window.clearTimeout(timer)
    timer = null
  }
  if (!currentAccount || queue.length === 0) return

  const batch = queue.splice(0)
  const account = currentAccount

  // VRF entries (contain request_random) must be individual txs —
  // the VRF contract can't fulfil two request_random in one multicall.
  const vrfEntries: QueueEntry[] = []
  const batchable: QueueEntry[] = []

  for (const entry of batch) {
    if (entry.calls.some(c => c.entrypoint === 'request_random')) {
      vrfEntries.push(entry)
    } else {
      batchable.push(entry)
    }
  }

  if (batchable.length > 0) {
    const labels = batchable.map(e => e.label)
    const allCalls = batchable.flatMap(e => e.calls)
    const t = txToast(formatBatchToast(labels))
    try {
      const result = await account.execute(allCalls)
      for (const entry of batchable) entry.resolve(result)
      t.success()
    } catch (error) {
      for (const entry of batchable) entry.reject(error)
      t.error()
    }
  }

  for (const entry of vrfEntries) {
    const t = txToast(entry.label)
    try {
      const result = await account.execute(entry.calls)
      entry.resolve(result)
      t.success()
    } catch (error) {
      entry.reject(error)
      t.error()
    }
  }
}

export function getTxQueueSize(): number {
  return queue.length
}
