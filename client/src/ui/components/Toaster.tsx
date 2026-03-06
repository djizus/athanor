import { useToastStore, type ToastType } from '@/stores/toastStore'

const ICONS: Record<ToastType, string> = {
  loading: '⏳',
  success: '✓',
  error: '✕',
}

export function Toaster() {
  const toasts = useToastStore((s) => s.toasts)
  const dismissToast = useToastStore((s) => s.dismissToast)

  if (toasts.length === 0) return null

  return (
    <div className="toaster-container">
      {toasts.map((toast) => (
        <div
          key={toast.id}
          className={`toast-item toast-${toast.type}`}
          onClick={() => dismissToast(toast.id)}
        >
          <span className={`toast-icon toast-icon-${toast.type}`}>{ICONS[toast.type]}</span>
          <div className="toast-content">
            <span className="toast-message">{toast.message}</span>
            {toast.description && (
              <span className="toast-description">{toast.description}</span>
            )}
          </div>
        </div>
      ))}
    </div>
  )
}
