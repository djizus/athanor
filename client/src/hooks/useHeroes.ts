import { useMemo } from 'react'
import { useComponentValue } from '@dojoengine/react'
import { toEntityId } from '@/dojo/entityId'
import { useDojo } from '@/dojo/useDojo'

export function useCharacters(gameId: number | null) {
  const { contractComponents } = useDojo()

  const key0 = useMemo(() => (gameId != null ? toEntityId([BigInt(gameId), 0n]) : undefined), [gameId])
  const key1 = useMemo(() => (gameId != null ? toEntityId([BigInt(gameId), 1n]) : undefined), [gameId])
  const key2 = useMemo(() => (gameId != null ? toEntityId([BigInt(gameId), 2n]) : undefined), [gameId])

  const char0 = useComponentValue(contractComponents.Character, key0)
  const char1 = useComponentValue(contractComponents.Character, key1)
  const char2 = useComponentValue(contractComponents.Character, key2)

  return useMemo(() => {
    const characters: NonNullable<typeof char0>[] = []
    if (char0) characters.push(char0)
    if (char1) characters.push(char1)
    if (char2) characters.push(char2)
    return characters
  }, [char0, char1, char2])
}

export { useCharacters as useHeroes }
