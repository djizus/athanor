import { create } from 'zustand'

export type ToastType = 'loading' | 'success' | 'error'

export interface Toast {
  id: string
  message: string
  type: ToastType
  description?: string
  createdAt: number
}

interface ToastState {
  toasts: Toast[]
  addToast: (toast: Omit<Toast, 'createdAt'>) => void
  updateToast: (id: string, updates: Partial<Pick<Toast, 'message' | 'type' | 'description'>>) => void
  dismissToast: (id: string) => void
}

const AUTO_DISMISS_MS: Record<ToastType, number> = {
  loading: 15000,
  success: 3000,
  error: 5000,
}

const MAX_TOASTS = 5

export const useToastStore = create<ToastState>((set) => ({
  toasts: [],

  addToast: (toast) => set((state) => {
    const now = Date.now()
    const newToast: Toast = { ...toast, createdAt: now }
    const existing = state.toasts.find((t) => t.id === toast.id)
    const toasts = existing
      ? state.toasts.map((t) => (t.id === toast.id ? newToast : t))
      : [...state.toasts, newToast].slice(-MAX_TOASTS)

    scheduleAutoDismiss(toast.id, AUTO_DISMISS_MS[toast.type])
    return { toasts }
  }),

  updateToast: (id, updates) => set((state) => {
    const toasts = state.toasts.map((t) =>
      t.id === id ? { ...t, ...updates } : t,
    )
    const updated = toasts.find((t) => t.id === id)
    if (updated) {
      scheduleAutoDismiss(id, AUTO_DISMISS_MS[updated.type])
    }
    return { toasts }
  }),

  dismissToast: (id) => set((state) => ({
    toasts: state.toasts.filter((t) => t.id !== id),
  })),
}))

const timers = new Map<string, ReturnType<typeof setTimeout>>()

function scheduleAutoDismiss(id: string, ms: number) {
  const prev = timers.get(id)
  if (prev) clearTimeout(prev)
  const timer = setTimeout(() => {
    useToastStore.getState().dismissToast(id)
    timers.delete(id)
  }, ms)
  timers.set(id, timer)
}

let toastCounter = 0

export function txToast(label: string) {
  const id = `tx-${++toastCounter}-${Date.now()}`
  const { addToast, updateToast, dismissToast } = useToastStore.getState()

  addToast({ id, message: `${label}...`, type: 'loading' })

  return {
    success: (msg?: string) => updateToast(id, { message: msg ?? `${label} confirmed`, type: 'success' }),
    error: (msg?: string) => updateToast(id, { message: msg ?? `${label} failed`, type: 'error' }),
    dismiss: () => dismissToast(id),
  }
}
