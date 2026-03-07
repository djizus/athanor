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
} from '@/game/constants'
import { bitmapGet } from '@/game/packer'
import type { DiscoveryData } from '@/hooks/useRecipes'

export type PanelMode = 'craft' | 'grimoire' | 'inventory'

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

/* ── Craft Panel Content ──────────────────────── */

export function CraftContent({
  inventory,
  isGameOver,
  brewAllCount,
  onCraft,
  onBrewAll,
}: {
  inventory: InventoryItem[]
  isGameOver: boolean
  brewAllCount: number
  onCraft: (a: number, b: number) => void
  onBrewAll: () => void
}) {
  const [slotA, setSlotA] = useState<number | null>(null)
  const [slotB, setSlotB] = useState<number | null>(null)

  const handlePickIngredient = (id: number) => {
    if (slotA === id) { setSlotA(null); return }
    if (slotB === id) { setSlotB(null); return }

    if (slotA === null) {
      setSlotA(id)
    } else if (slotB === null) {
      setSlotB(id)
    } else {
      setSlotA(id)
      setSlotB(null)
    }
  }

  const handleBrew = () => {
    if (slotA != null && slotB != null) onCraft(slotA, slotB)
  }

  return (
    <>
      <div className="craft-slots">
        <button
          className={`craft-slot${slotA != null ? ' craft-slot-filled' : ''}`}
          onClick={() => setSlotA(null)}
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
          onClick={() => setSlotB(null)}
          style={slotB != null ? { ['--zone-color' as string]: ZONE_COLORS[getZoneForIngredient(slotB)] } : undefined}
        >
          {slotB != null ? (
            <img className="craft-slot-img" src={ingredientAssetUrl(slotB)} alt={INGREDIENT_NAMES[slotB]} />
          ) : (
            <span className="craft-slot-empty">?</span>
          )}
        </button>
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
                  onClick={item.quantity > 0 ? () => handlePickIngredient(item.ingredient_id) : undefined}
                />
              ))}
            </div>
          </div>
        )
      })}
    </>
  )
}

/* ── Potion Use Popup ─────────────────────────── */

function PotionUsePopup({
  effectIndex,
  maxQuantity,
  heroes,
  onUse,
  onClose,
}: {
  effectIndex: number
  maxQuantity: number
  heroes: GrimoireHero[]
  onUse: (heroId: number, quantity: number) => void
  onClose: () => void
}) {
  const [quantity, setQuantity] = useState(1)
  const [heroId, setHeroId] = useState<number | null>(heroes.length > 0 ? heroes[0].id : null)

  const category = EFFECT_CATEGORIES[effectIndex]
  const categoryColor = EFFECT_COLORS[category]
  const categoryLabel = category.charAt(0).toUpperCase() + category.slice(1)

  return (
    <div className="potion-popup-backdrop" onClick={onClose}>
      <div className="potion-popup floating-panel" onClick={e => e.stopPropagation()}>
        <div className="potion-popup-header">
          <img
            className="potion-popup-icon"
            src={effectAssetUrl(effectIndex)}
            alt={EFFECT_NAMES[effectIndex]}
            style={{ borderColor: categoryColor }}
          />
          <div>
            <div className="potion-popup-name" style={{ color: categoryColor }}>
              {EFFECT_NAMES[effectIndex]}
            </div>
            <div className="potion-popup-category">{categoryLabel} Potion</div>
          </div>
        </div>

        <div className="potion-popup-section">
          <span className="potion-popup-label">Quantity</span>
          <div className="potion-popup-qty-control">
            <button onClick={() => setQuantity(q => Math.max(1, q - 1))} disabled={quantity <= 1}>−</button>
            <span>{quantity}</span>
            <button onClick={() => setQuantity(q => Math.min(maxQuantity, q + 1))} disabled={quantity >= maxQuantity}>+</button>
          </div>
        </div>

        <div className="potion-popup-section">
          <span className="potion-popup-label">Apply to</span>
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

        <div className="potion-popup-actions">
          <button
            className="btn-primary"
            onClick={() => heroId !== null && onUse(heroId, quantity)}
            disabled={heroId === null}
          >
            Apply
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
  hints,
  effectQuantities,
  recipes,
  hintIngredients,
  discoveredCount,
  gold,
  hintCost,
  isGameOver,
  heroes,
  onBuyHint,
  onUsePotion,
}: {
  grimoire: number
  hints: number
  effectQuantities: number[]
  recipes: DiscoveryData[]
  hintIngredients: Map<number, number[]>
  discoveredCount: number
  gold: number
  hintCost: number
  isGameOver: boolean
  heroes: GrimoireHero[]
  onBuyHint: () => void
  onUsePotion: (effect: number, heroId: number, quantity: number) => void
}) {
  const [filter, setFilter] = useState<FilterCategory>('all')
  const [selectedEffect, setSelectedEffect] = useState<number | null>(null)

  const discoveryMap = useMemo(() => {
    const map = new Map<number, DiscoveryData>()
    for (const r of recipes) {
      if (bitmapGet(grimoire, r.effect) && !map.has(r.effect)) {
        map.set(r.effect, r)
      }
    }
    return map
  }, [recipes, grimoire])

  const effects = useMemo(() => {
    const all = Array.from({ length: 30 }, (_, i) => i)
    if (filter === 'all') return all
    return all.filter(i => EFFECT_CATEGORIES[i] === filter)
  }, [filter])

  const selectedQuantity = selectedEffect !== null ? effectQuantities[selectedEffect] : 0

  return (
    <>
      <div className="grimoire-progress">
        <div className="grimoire-progress-fill" style={{ width: `${(discoveredCount / 30) * 100}%` }} />
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
          const isDiscovered = bitmapGet(grimoire, effectIdx)
          const isHinted = !isDiscovered && bitmapGet(hints, effectIdx)
          const quantity = effectQuantities[effectIdx]
          const hasStock = quantity > 0
          const canUse = isDiscovered && hasStock && !isGameOver
          const discovery = discoveryMap.get(effectIdx)
          const hintIngs = hintIngredients.get(effectIdx)
          const category = EFFECT_CATEGORIES[effectIdx]
          const categoryColor = EFFECT_COLORS[category]
          const categoryLabel = category.charAt(0).toUpperCase() + category.slice(1)

          return (
            <div
              key={effectIdx}
              className={`grimoire-potion${isDiscovered ? ' discovered' : ''}${isHinted ? ' hinted' : ''}${!isDiscovered && !isHinted ? ' locked' : ''}${canUse ? ' usable' : ''}`}
              onClick={canUse ? () => setSelectedEffect(effectIdx) : undefined}
            >
              <div className="grimoire-potion-icon-wrap" style={{ ['--effect-color' as string]: categoryColor }}>
                <img
                  className="grimoire-potion-icon"
                  src={effectAssetUrl(effectIdx)}
                  alt={isDiscovered ? EFFECT_NAMES[effectIdx] : '???'}
                />
                {hasStock && <span className="grimoire-potion-badge">{quantity}</span>}
              </div>
              <div className="grimoire-potion-info">
                <span className="grimoire-potion-name" style={isDiscovered ? { color: categoryColor } : undefined}>
                  {isDiscovered ? EFFECT_NAMES[effectIdx] : '???'}
                </span>
                <span className="grimoire-potion-category">{categoryLabel}</span>
                {isDiscovered && discovery && (
                  <span className="grimoire-potion-recipe">
                    <img className="grimoire-potion-recipe-icon" src={ingredientAssetUrl(discovery.ingredient_a)} alt={INGREDIENT_NAMES[discovery.ingredient_a]} />
                    <span>+</span>
                    <img className="grimoire-potion-recipe-icon" src={ingredientAssetUrl(discovery.ingredient_b)} alt={INGREDIENT_NAMES[discovery.ingredient_b]} />
                  </span>
                )}
                {isHinted && hintIngs && hintIngs.length > 0 && (
                  <span className="grimoire-potion-hint">
                    Uses: {hintIngs.map(id => INGREDIENT_NAMES[id]).join(', ')}
                  </span>
                )}
              </div>
            </div>
          )
        })}
      </div>

      {selectedEffect !== null && bitmapGet(grimoire, selectedEffect) && selectedQuantity > 0 && (
        <PotionUsePopup
          effectIndex={selectedEffect}
          maxQuantity={selectedQuantity}
          heroes={heroes}
          onUse={(heroId, qty) => { onUsePotion(selectedEffect, heroId, qty); setSelectedEffect(null) }}
          onClose={() => setSelectedEffect(null)}
        />
      )}
    </>
  )
}

