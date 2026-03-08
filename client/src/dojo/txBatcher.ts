import type { AccountInterface, Call, InvokeFunctionResponse } from 'starknet'

const DEBOUNCE_MS = 500

type QueueEntry = {
  calls: Call[]
  resolve: (value: InvokeFunctionResponse) => void
  reject: (reason: unknown) => void
}

let queue: QueueEntry[] = []
let timer: number | null = null
let currentAccount: AccountInterface | null = null

export function setTxBatcherAccount(account: AccountInterface | null) {
  currentAccount = account
}

export function enqueueTx(calls: Call[]): Promise<InvokeFunctionResponse> {
  return new Promise((resolve, reject) => {
    queue.push({ calls, resolve, reject })
    if (timer != null) window.clearTimeout(timer)
    timer = window.setTimeout(flushTxQueue, DEBOUNCE_MS)
  })
}

export async function flushTxQueue(): Promise<void> {
  if (timer != null) {
    window.clearTimeout(timer)
    timer = null
  }
  if (!currentAccount || queue.length === 0) return

  const batch = queue.splice(0)
  const allCalls = batch.flatMap(e => e.calls)

  try {
    const result = await currentAccount.execute(allCalls)
    for (const entry of batch) entry.resolve(result)
  } catch (error) {
    for (const entry of batch) entry.reject(error)
  }
}

export function getTxQueueSize(): number {
  return queue.length
}
