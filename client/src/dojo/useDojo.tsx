import { useContext } from 'react'
import { DojoContext } from './context'

export function useDojo() {
  const dojo = useContext(DojoContext)

  if (!dojo) {
    throw new Error('useDojo must be used inside DojoProvider')
  }

  return dojo
}
