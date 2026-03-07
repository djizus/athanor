import { useMemo, useState } from 'react'
import {
  EFFECT_COLORS,
  EFFECT_NAMES,
  EFFECT_CATEGORIES,
  INGREDIENT_NAMES,
  INGREDIENTS_PER_ZONE,
  ROLE_NAMES,
  ZONE_COLORS,
  ZONE_NAMES,
  displayGold,
  getZoneForIngredient,
  ingredientAssetUrl,
  effectAssetUrl,
  roleAssetUrl,
  effectStatLabel,
} from '@/game/constants'
import { bitmapGet } from '@/game/packer'
import type { DiscoveryData } from '@/hooks/useRecipes'

export type PanelMode = 'ingredients' | 'grimoire'

export interface InventoryItem {
  ingredient_id: number
  quantity: number
}

export interface GrimoireHero {
  id: number
  role: number
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

function PotionUsePopup({
  effectQuantities,
  heroes,
  onApply,
  onClose,
}: {
  effectQuantities: number[]
  heroes: GrimoireHero[]
  onApply: (heroId: number, selections: { effect: number; quantity: number }[]) => void
  onClose: () => void
}) {
  const [heroId, setHeroId] = useState<number | null>(heroes.length > 0 ? heroes[0].id : null)
  const [selected, setSelected] = useState<Map<number, number>>(() => new Map())

  const available = useMemo(() =>
    effectQuantities.map((qty, idx) => ({ idx, qty })).filter(e => e.qty > 0),
    [effectQuantities],
  )

  const togglePotion = (idx: number, delta: number) => {
    setSelected(prev => {
      const next = new Map(prev)
      const cur = next.get(idx) ?? 0
      const max = effectQuantities[idx]
      const val = Math.max(0, Math.min(max, cur + delta))
      if (val === 0) next.delete(idx)
      else next.set(idx, val)
      return next
    })
  }

  const totalSelected = Array.from(selected.values()).reduce((a, b) => a + b, 0)

  const heroRoleIdx = heroId !== null
    ? (() => { const h = heroes.find(h => h.id === heroId); return h ? (h.role > 0 ? h.role - 1 : h.id) : 0 })()
    : 0
  const heroName = ROLE_NAMES[heroRoleIdx] ?? 'Hero'

  return (
    <div className="potion-popup-backdrop" onClick={onClose}>
      <div className="potion-popup floating-panel" onClick={e => e.stopPropagation()}>
        <div className="potion-popup-section">
          <div className="potion-popup-heroes">
            {heroes.map(hero => {
              const roleIdx = hero.role > 0 ? hero.role - 1 : hero.id
              return (
                <button
                  key={hero.id}
                  className={`potion-popup-hero${heroId === hero.id ? ' selected' : ''}`}
                  onClick={() => setHeroId(hero.id)}
                >
                  <img src={roleAssetUrl(roleIdx)} alt={ROLE_NAMES[roleIdx]} />
                  <span>{ROLE_NAMES[roleIdx]}</span>
                </button>
              )
            })}
          </div>
        </div>

        <div className="potion-popup-grid">
          {available.map(({ idx, qty }) => {
            const category = EFFECT_CATEGORIES[idx]
            const color = EFFECT_COLORS[category]
            const count = selected.get(idx) ?? 0
            const isSelected = count > 0

            return (
              <div
                key={idx}
                className={`potion-popup-cell${isSelected ? ' active' : ''}`}
                style={{ ['--effect-color' as string]: color }}
              >
                <div className="potion-popup-cell-icon">
                  <img src={effectAssetUrl(idx)} alt={effectStatLabel(idx)} />
                </div>
                <span className="potion-popup-cell-stat" style={{ color }}>
                  {effectStatLabel(idx)}
                </span>
                <span className="potion-popup-cell-stock">×{qty}</span>
                <div className="potion-popup-cell-qty">
                  <button onClick={() => togglePotion(idx, -1)} disabled={count <= 0}>−</button>
                  <span>{count}</span>
                  <button onClick={() => togglePotion(idx, 1)} disabled={count >= qty}>+</button>
                </div>
              </div>
            )
          })}
        </div>

        <div className="potion-popup-actions">
          <button
            className="btn-primary"
            onClick={() => {
              if (heroId === null || selected.size === 0) return
              const selections = Array.from(selected.entries()).map(([effect, quantity]) => ({ effect, quantity }))
              onApply(heroId, selections)
            }}
            disabled={heroId === null || totalSelected === 0}
          >
            Apply {totalSelected > 0 ? `${totalSelected} to ${heroName}` : ''}
          </button>
          <button onClick={onClose}>Cancel</button>
        </div>
      </div>
    </div>
  )
}

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
  heroes,
  inventory,
  onBuyHint,
  onApplyPotions,
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
  heroes: GrimoireHero[]
  inventory: InventoryItem[]
  onBuyHint: () => void
  onApplyPotions: (heroId: number, selections: { effect: number; quantity: number }[]) => void
  onSelectIngredients: (a: number, b: number) => void
}) {
  const [filter, setFilter] = useState<FilterCategory>('all')
  const [potionPopupOpen, setPotionPopupOpen] = useState(false)

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

  const hasAnyStock = effectQuantities.some(q => q > 0)

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

      <div className="grimoire-btn-row">
        <button onClick={onBuyHint} disabled={isGameOver || gold < hintCost}>
          Hint ({displayGold(hintCost)}g)
        </button>
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

      {hasAnyStock && !isGameOver && heroes.length > 0 && (
        <div className="grimoire-btn-row">
          <button className="btn-primary" onClick={() => setPotionPopupOpen(true)}>
            Apply Potions
          </button>
        </div>
      )}

      {potionPopupOpen && (
        <PotionUsePopup
          effectQuantities={effectQuantities}
          heroes={heroes}
          onApply={(heroId, selections) => { onApplyPotions(heroId, selections); setPotionPopupOpen(false) }}
          onClose={() => setPotionPopupOpen(false)}
        />
      )}
    </>
  )
}

