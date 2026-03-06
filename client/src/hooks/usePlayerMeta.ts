import { useMemo } from 'react'
import { useComponentValue } from '@dojoengine/react'
import { toEntityId } from '@/dojo/entityId'
import { useDojo } from '@/dojo/useDojo'

export function usePlayerMeta(address: string | undefined) {
  const { contractComponents } = useDojo()

  const entityId = useMemo(
    () => (address ? toEntityId([BigInt(address)]) : undefined),
    [address],
  )

  return useComponentValue(contractComponents.PlayerMeta, entityId)
}
