import { createContext, type ReactNode } from 'react'
import type { setupDojo } from './setup'

export type DojoSetup = Awaited<ReturnType<typeof setupDojo>>

export const DojoContext = createContext<DojoSetup | null>(null)

type DojoProviderProps = {
  children: ReactNode
  value: DojoSetup
}

export function DojoProvider({ children, value }: DojoProviderProps) {
  return <DojoContext.Provider value={value}>{children}</DojoContext.Provider>
}
