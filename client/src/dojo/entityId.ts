import type { Entity } from '@dojoengine/recs'
import { getEntityIdFromKeys } from '@dojoengine/utils'

export function normalizeEntityId(entityId: string): Entity {
  if (!entityId.startsWith('0x')) return entityId as Entity
  const hex = entityId.slice(2).replace(/^0+/, '') || '0'
  return `0x${hex}` as Entity
}

export function toEntityId(keys: bigint[]): Entity {
  return normalizeEntityId(getEntityIdFromKeys(keys))
}

export function padAddress(address: string): string {
  if (!address) return ''
  const hex = address.startsWith('0x') ? address.slice(2) : address
  return `0x${hex.padStart(64, '0')}`
}
