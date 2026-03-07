/**
 * TS equivalents of the contract's Packer (base-N encode/decode) and Bitmap helpers.
 * The contract packs values using modular arithmetic (not bit-shifting):
 * INGREDIENT=2^10=1024, EFFECT=2^8=256, TRY=2^5=32
 */

export function unpack(packed: bigint, size: bigint, count: number): number[] {
  const result: number[] = []
  let v = packed
  for (let i = 0; i < count; i++) {
    result.push(Number(v % size))
    v = v / size
  }
  return result
}

export function pack(values: number[], size: bigint): bigint {
  let result = 0n
  let offset = 1n
  for (let i = 0; i < values.length; i++) {
    result += offset * BigInt(values[i])
    if (i < values.length - 1) {
      offset *= size
    }
  }
  return result
}

export function packerGet(packed: bigint, index: number, size: bigint): number {
  let v = packed
  for (let i = 0; i < index; i++) {
    v = v / size
  }
  return Number(v % size)
}

export function bitmapGet(bitmap: number, index: number): boolean {
  return ((bitmap >>> index) & 1) === 1
}

export function bitmapSet(bitmap: number, index: number): number {
  return bitmap | (1 << index)
}

export function bitmapUnset(bitmap: number, index: number): number {
  return bitmap & ~(1 << index)
}

export function bitmapPopcount(bitmap: number): number {
  let count = 0
  let n = bitmap >>> 0
  while (n) {
    count += n & 1
    n >>>= 1
  }
  return count
}

export const INGREDIENT_SIZE = 1024n
export const EFFECT_SIZE = 256n
export const TRY_SIZE = 32n

export const INGREDIENT_COUNT = 25
export const EFFECT_COUNT = 30

export function unpackIngredients(packed: bigint): number[] {
  return unpack(packed, INGREDIENT_SIZE, INGREDIENT_COUNT)
}

export function unpackEffects(packed: bigint): number[] {
  return unpack(packed, EFFECT_SIZE, EFFECT_COUNT)
}

export function unpackTries(packed: bigint): number[] {
  return unpack(packed, TRY_SIZE, INGREDIENT_COUNT)
}

export function unpackCharacterIngredients(packed: bigint): number[] {
  return unpack(packed, INGREDIENT_SIZE, INGREDIENT_COUNT)
}

export function getDiscoveredRecipes(grimoire: number): number[] {
  const result: number[] = []
  for (let i = 0; i < EFFECT_COUNT; i++) {
    if (bitmapGet(grimoire, i)) {
      result.push(i)
    }
  }
  return result
}

export function getHintedRecipes(hints: number): number[] {
  const result: number[] = []
  for (let i = 0; i < EFFECT_COUNT; i++) {
    if (bitmapGet(hints, i)) {
      result.push(i)
    }
  }
  return result
}

export function getRecruitedRoles(heroes: number): number[] {
  const result: number[] = []
  for (let i = 0; i < 3; i++) {
    if (bitmapGet(heroes, i)) {
      result.push(i)
    }
  }
  return result
}
