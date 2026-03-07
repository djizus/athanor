import { useMemo, useState } from 'react'
import {
  EFFECT_COLORS,
  EFFECT_NAMES,
  EFFECT_CATEGORIES,
  INGREDIENT_NAMES,
  INGREDIENTS_PER_ZONE,
  ZONE_COLORS,
  ZONE_NAMES,
  displayGold,
  getZoneForIngredient,
  ingredientAssetUrl,
  effectAssetUrl,
  effectStatLabel,
} from '@/game/constants'
import { bitmapGet } from '@/game/packer'
import type { DiscoveryData } from '@/hooks/useRecipes'

export type PanelMode = 'ingredients' | 'grimoire'

export interface InventoryItem {
  ingredient_id: number
  quantity: number
}


type FilterCategory = 'all' | 'health' | 'power' | 'regen'

/* ── Shared ingredient icon ───────────────────── */

function IngredientIcon({
  ingredientId,
  quantity,
  size = 42,
  selected = false,
  onClick,
}: {
  ingredientId: number
  quantity?: number
  size?: number
  selected?: boolean
  onClick?: () => void
}) {
  const zoneColor = ZONE_COLORS[getZoneForIngredient(ingredientId)]
  const name = INGREDIENT_NAMES[ingredientId]
  const isEmpty = quantity !== undefined && quantity === 0

  return (
    <div
      className={`ing-cell${isEmpty ? ' ing-cell-zero' : ''}${selected ? ' ing-cell-selected' : ''}${onClick ? ' ing-cell-clickable' : ''}`}
      data-name={quantity !== undefined ? `${name} (x${quantity})` : name}
      onClick={onClick}
    >
      <div
        className="ing-icon-wrap"
        style={{
          width: size,
          height: size,
          ['--zone-color' as string]: zoneColor,
        }}
      >
        <img
          className="ing-icon"
          src={ingredientAssetUrl(ingredientId)}
          alt={name}
          style={{ width: size, height: size }}
        />
        {quantity !== undefined && (
          <span className="ing-badge">{quantity}</span>
        )}
      </div>
    </div>
  )
}

/* ── Brew Panel Content ───────────────────────── */

const TOTAL_COMBINATIONS = 25 * 24 / 2

export function BrewContent({
  slotA,
  slotB,
  recipes,
  isGameOver,
  brewAllCount,
  onSetSlotA,
  onSetSlotB,
  onCraft,
  onBrewAll,
}: {
  slotA: number | null
  slotB: number | null
  recipes: DiscoveryData[]
  isGameOver: boolean
  brewAllCount: number
  onSetSlotA: (v: number | null) => void
  onSetSlotB: (v: number | null) => void
  onCraft: (a: number, b: number) => void
  onBrewAll: () => void
}) {
  const handleBrew = () => {
    if (slotA != null && slotB != null) onCraft(slotA, slotB)
  }

  const selectedDiscovery = useMemo(() => {
    if (slotA == null || slotB == null) return null
    const lo = Math.min(slotA, slotB)
    const hi = Math.max(slotA, slotB)
    return recipes.find(
      (r) => r.discovered && Math.min(r.ingredient_a, r.ingredient_b) === lo && Math.max(r.ingredient_a, r.ingredient_b) === hi,
    ) ?? null
  }, [slotA, slotB, recipes])

  return (
    <>
      <div className="craft-slots">
        <button
          className={`craft-slot${slotA != null ? ' craft-slot-filled' : ''}`}
          onClick={() => onSetSlotA(null)}
          title={slotA != null ? INGREDIENT_NAMES[slotA] : 'Select ingredient'}
          style={slotA != null ? { ['--zone-color' as string]: ZONE_COLORS[getZoneForIngredient(slotA)] } : undefined}
        >
          {slotA != null ? (
            <img className="craft-slot-img" src={ingredientAssetUrl(slotA)} alt={INGREDIENT_NAMES[slotA]} />
          ) : (
            <span className="craft-slot-empty">?</span>
          )}
        </button>
        <span className="craft-plus">+</span>
        <button
          className={`craft-slot${slotB != null ? ' craft-slot-filled' : ''}`}
          onClick={() => onSetSlotB(null)}
          title={slotB != null ? INGREDIENT_NAMES[slotB] : 'Select ingredient'}
          style={slotB != null ? { ['--zone-color' as string]: ZONE_COLORS[getZoneForIngredient(slotB)] } : undefined}
        >
          {slotB != null ? (
            <img className="craft-slot-img" src={ingredientAssetUrl(slotB)} alt={INGREDIENT_NAMES[slotB]} />
          ) : (
            <span className="craft-slot-empty">?</span>
          )}
        </button>
        <span className="craft-arrow">=</span>
        <div className={`craft-result${selectedDiscovery ? ' craft-result-known' : ''}`}>
          {selectedDiscovery ? (
            <CraftResultPreview discovery={selectedDiscovery} />
          ) : (
            <span className="craft-result-unknown">?</span>
          )}
        </div>
        <button
          className="btn-primary btn-sm craft-brew-btn"
          onClick={handleBrew}
          disabled={isGameOver || slotA == null || slotB == null}
        >
          Brew
        </button>
      </div>

      <div className="craft-btn-row">
        <button onClick={onBrewAll} disabled={isGameOver || brewAllCount === 0}>
          Brew All ({brewAllCount})
        </button>
      </div>
    </>
  )
}

/* ── Ingredients Grid Content ─────────────────── */

export function IngredientsContent({
  inventory,
  slotA,
  slotB,
  remainingTries,
  onPickIngredient,
}: {
  inventory: InventoryItem[]
  slotA: number | null
  slotB: number | null
  remainingTries: number
  onPickIngredient: (id: number) => void
}) {
  const tried = TOTAL_COMBINATIONS - remainingTries
  const progressPct = TOTAL_COMBINATIONS > 0 ? Math.min(100, (tried / TOTAL_COMBINATIONS) * 100) : 0

  return (
    <>
      <div className="hero-card-hp" style={{ marginBottom: '0.5rem' }}>
        <div className="hero-card-hp-fill" style={{ width: `${progressPct}%`, background: 'var(--accent-gold)' }} />
        <span className="hero-card-bar-label">{tried}/{TOTAL_COMBINATIONS}</span>
      </div>
      {ZONE_NAMES.map((zoneName, zi) => {
        const zoneItems = inventory.slice(
          zi * INGREDIENTS_PER_ZONE,
          zi * INGREDIENTS_PER_ZONE + INGREDIENTS_PER_ZONE,
        )
        return (
          <div key={zoneName}>
            <div className="inventory-zone-header" style={{ color: ZONE_COLORS[zi] }}>{zoneName}</div>
            <div className="inventory-zone-grid">
              {zoneItems.map((item) => (
                <IngredientIcon
                  key={item.ingredient_id}
                  ingredientId={item.ingredient_id}
                  quantity={item.quantity}
                  selected={item.ingredient_id === slotA || item.ingredient_id === slotB}
                  onClick={item.quantity > 0 ? () => onPickIngredient(item.ingredient_id) : undefined}
                />
              ))}
            </div>
          </div>
        )
      })}
    </>
  )
}

function CraftResultPreview({ discovery }: { discovery: DiscoveryData }) {
  const effectIdx = discovery.effect
  const category = EFFECT_CATEGORIES[effectIdx]
  const isSoup = category === undefined

  if (isSoup || effectIdx < 0 || effectIdx >= EFFECT_NAMES.length) {
    return (
      <div className="craft-result-soup">
        <img className="craft-result-icon" src="/assets/potions/craft-soup.webp" alt="Soup" />
        <span className="craft-result-tag">+1g</span>
      </div>
    )
  }

  const color = EFFECT_COLORS[category]
  return (
    <div className="craft-result-potion">
      <img
        className="craft-result-icon"
        src={effectAssetUrl(effectIdx)}
        alt={EFFECT_NAMES[effectIdx]}
        style={{ borderColor: color }}
      />
    </div>
  )
}

/* ── Potion Use Popup ─────────────────────────── */

/* ── Grimoire Panel Content ───────────────────── */

export function GrimoireContent({
  grimoire,
  effectQuantities,
  recipes,
  hintIngredients,
  discoveredCount,
  gold,
  hintCost,
  isGameOver,
  inventory,
  onBuyHint,
  onSelectIngredients,
}: {
  grimoire: number
  effectQuantities: number[]
  recipes: DiscoveryData[]
  hintIngredients: Map<number, number[]>
  discoveredCount: number
  gold: number
  hintCost: number
  isGameOver: boolean
  inventory: InventoryItem[]
  onBuyHint: () => void
  onSelectIngredients: (a: number, b: number) => void
}) {
  const [filter, setFilter] = useState<FilterCategory>('all')

  const invMap = useMemo(() => {
    const m = new Map<number, number>()
    for (const item of inventory) m.set(item.ingredient_id, item.quantity)
    return m
  }, [inventory])

  const discoveryMap = useMemo(() => {
    const map = new Map<number, DiscoveryData>()
    for (const r of recipes) {
      if (bitmapGet(grimoire, r.effect + 1) && !map.has(r.effect)) {
        map.set(r.effect, r)
      }
    }
    return map
  }, [recipes, grimoire])

  const effects = useMemo(() => {
    const all = Array.from({ length: 30 }, (_, i) => i)
    const visible = all.filter(i => bitmapGet(grimoire, i + 1) || hintIngredients.has(i))
    const filtered = filter === 'all' ? visible : visible.filter(i => EFFECT_CATEGORIES[i] === filter)

    return filtered.sort((a, b) => {
      const aDisc = bitmapGet(grimoire, a + 1) ? 1 : 0
      const bDisc = bitmapGet(grimoire, b + 1) ? 1 : 0
      if (aDisc !== bDisc) return bDisc - aDisc

      if (aDisc && bDisc) {
        const aQty = effectQuantities[a]
        const bQty = effectQuantities[b]
        if (aQty !== bQty) return bQty - aQty
      }

      const aHint = !aDisc && hintIngredients.has(a) ? 1 : 0
      const bHint = !bDisc && hintIngredients.has(b) ? 1 : 0
      if (aHint !== bHint) return bHint - aHint

      return a - b
    })
  }, [filter, grimoire, effectQuantities, hintIngredients])

  return (
    <>
      <div className="hero-card-hp" style={{ marginBottom: '0.5rem' }}>
        <div className="hero-card-hp-fill" style={{ width: `${(discoveredCount / 30) * 100}%`, background: 'var(--accent-green)' }} />
        <span className="hero-card-bar-label">{discoveredCount}/30</span>
      </div>

      <div className="grimoire-filters">
        {(['all', 'health', 'power', 'regen'] as const).map(cat => (
          <button
            key={cat}
            className={`grimoire-filter-btn${filter === cat ? ' active' : ''}`}
            style={cat !== 'all' ? { ['--filter-color' as string]: EFFECT_COLORS[cat] } : undefined}
            onClick={() => setFilter(cat)}
          >
            {cat === 'all' ? 'All' : cat.charAt(0).toUpperCase() + cat.slice(1)}
          </button>
        ))}
      </div>

      <div className="grimoire-grid">
        {effects.map(effectIdx => {
          const isDiscovered = bitmapGet(grimoire, effectIdx + 1)
          const isHinted = !isDiscovered && hintIngredients.has(effectIdx)
          const quantity = effectQuantities[effectIdx]
          const hasStock = quantity > 0
          const discovery = discoveryMap.get(effectIdx)
          const category = EFFECT_CATEGORIES[effectIdx]
          const categoryColor = EFFECT_COLORS[category]

          const maxCraftable = discovery
            ? Math.min(invMap.get(discovery.ingredient_a) ?? 0, invMap.get(discovery.ingredient_b) ?? 0)
            : 0
          const canCraft = isDiscovered && discovery && maxCraftable > 0 && !isGameOver
          const hintIngs = hintIngredients.get(effectIdx)

          const handleClick = () => {
            if (isDiscovered && discovery) {
              onSelectIngredients(discovery.ingredient_a, discovery.ingredient_b)
            } else if (isHinted && hintIngs && hintIngs.length > 0) {
              if (hintIngs.length >= 2) {
                onSelectIngredients(hintIngs[0], hintIngs[1])
              } else {
                onSelectIngredients(hintIngs[0], -1)
              }
            }
          }

          return (
            <div
              key={effectIdx}
              className={`grimoire-cell${isDiscovered ? ' discovered' : ''}${isHinted ? ' hinted' : ''}${isDiscovered || isHinted ? ' grimoire-cell-clickable' : ''}`}
              onClick={isDiscovered || isHinted ? handleClick : undefined}
            >
              <div
                className="grimoire-icon-wrap"
                style={{ ['--effect-color' as string]: categoryColor }}
              >
                <img
                  className="grimoire-icon"
                  src={effectAssetUrl(effectIdx)}
                  alt={isDiscovered ? EFFECT_NAMES[effectIdx] : '???'}
                />
                {hasStock && <span className="grimoire-qty-badge">{quantity}</span>}
                {canCraft && <span className="grimoire-badge-star">★</span>}
                {isHinted && <span className="grimoire-badge-hint">🔍</span>}
              </div>
              <span className="grimoire-stat-badge" style={{ color: categoryColor }}>
                {effectStatLabel(effectIdx)}
              </span>
            </div>
          )
        })}
      </div>

      <div className="grimoire-btn-row">
        <button onClick={onBuyHint} disabled={isGameOver || gold < hintCost}>
          Hint ({displayGold(hintCost)}g)
        </button>
      </div>
    </>
  )
}

