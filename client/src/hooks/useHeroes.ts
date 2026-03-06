import { useMemo } from 'react'
import { useComponentValue } from '@dojoengine/react'
import { toEntityId } from '@/dojo/entityId'
import { useDojo } from '@/dojo/useDojo'

export function useHeroes(gameId: number | null) {
  const { contractComponents } = useDojo()

  const key0 = useMemo(() => (gameId != null ? toEntityId([BigInt(gameId), 0n]) : undefined), [gameId])
  const key1 = useMemo(() => (gameId != null ? toEntityId([BigInt(gameId), 1n]) : undefined), [gameId])
  const key2 = useMemo(() => (gameId != null ? toEntityId([BigInt(gameId), 2n]) : undefined), [gameId])

  const hero0 = useComponentValue(contractComponents.Hero, key0)
  const hero1 = useComponentValue(contractComponents.Hero, key1)
  const hero2 = useComponentValue(contractComponents.Hero, key2)

  return useMemo(() => {
    const heroes: NonNullable<typeof hero0>[] = []
    if (hero0) heroes.push(hero0)
    if (hero1) heroes.push(hero1)
    if (hero2) heroes.push(hero2)
    return heroes
  }, [hero0, hero1, hero2])
}
