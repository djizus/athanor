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
} from '@/game/constants'
import type { DiscoveryData } from '@/hooks/useRecipes'

export type PanelMode = 'craft' | 'grimoire' | 'inventory'

export interface InventoryItem {
  ingredient_id: number
  quantity: number
}

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
  gold,
  isGameOver,
  hintCost,
  onCraft,
  onBuyHint,
}: {
  inventory: InventoryItem[]
  gold: number
  isGameOver: boolean
  hintCost: number
  onCraft: (a: number, b: number) => void
  onBuyHint: () => void
}) {
  const available = useMemo(() => inventory.filter((i) => i.quantity > 0), [inventory])
  const [slotA, setSlotA] = useState<number | null>(null)
  const [slotB, setSlotB] = useState<number | null>(null)

  const handlePickIngredient = (id: number) => {
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

      <div className="craft-ingredient-grid">
        {available.map((item) => (
          <IngredientIcon
            key={item.ingredient_id}
            ingredientId={item.ingredient_id}
            quantity={item.quantity}
            size={36}
            selected={item.ingredient_id === slotA || item.ingredient_id === slotB}
            onClick={() => handlePickIngredient(item.ingredient_id)}
          />
        ))}
        {available.length === 0 && (
          <div className="craft-empty-msg">No ingredients available</div>
        )}
      </div>

      <div className="craft-btn-row">
        <button onClick={onBuyHint} disabled={isGameOver || gold < hintCost}>
          Hint ({displayGold(hintCost)}g)
        </button>
      </div>
    </>
  )
}

/* ── Grimoire Panel Content ───────────────────── */

export function GrimoireContent({
  recipes,
  discoveredCount,
}: {
  recipes: DiscoveryData[]
  discoveredCount: number
}) {
  const discovered = useMemo(() => recipes.filter((r) => r.discovered), [recipes])

  return (
    <>
      <div className="grimoire-progress">
        <div className="grimoire-progress-fill" style={{ width: `${(discoveredCount / 30) * 100}%` }} />
      </div>
      <div className="grimoire-grid">
        {discovered.length === 0 ? (
          <div className="grimoire-card-undiscovered">No discoveries yet</div>
        ) : (
          discovered.map((recipe, idx) => {
            const effectCategory = EFFECT_CATEGORIES[recipe.effect]
            const effectColor = effectCategory ? EFFECT_COLORS[effectCategory] : undefined
            const zoneA = getZoneForIngredient(recipe.ingredient_a)
            const zoneB = getZoneForIngredient(recipe.ingredient_b)
            return (
              <div key={`${recipe.ingredient_a}-${recipe.ingredient_b}`} className="grimoire-card discovered">
                <div className="grimoire-card-title">#{idx + 1}</div>
                <div className="grimoire-card-recipe">
                  <div className="grimoire-ingredient">
                    <img
                      className="grimoire-ing-icon"
                      src={ingredientAssetUrl(recipe.ingredient_a)}
                      alt={INGREDIENT_NAMES[recipe.ingredient_a]}
                      style={{ borderColor: ZONE_COLORS[zoneA] }}
                    />
                    <span style={{ color: ZONE_COLORS[zoneA] }}>
                      {INGREDIENT_NAMES[recipe.ingredient_a]}
                    </span>
                  </div>
                  <span className="grimoire-plus">+</span>
                  <div className="grimoire-ingredient">
                    <img
                      className="grimoire-ing-icon"
                      src={ingredientAssetUrl(recipe.ingredient_b)}
                      alt={INGREDIENT_NAMES[recipe.ingredient_b]}
                      style={{ borderColor: ZONE_COLORS[zoneB] }}
                    />
                    <span style={{ color: ZONE_COLORS[zoneB] }}>
                      {INGREDIENT_NAMES[recipe.ingredient_b]}
                    </span>
                  </div>
                </div>
                <div className="grimoire-card-effect" style={{ color: effectColor }}>
                  {EFFECT_NAMES[recipe.effect]}
                </div>
              </div>
            )
          })
        )}
      </div>
    </>
  )
}

/* ── Inventory Panel Content ──────────────────── */

export function InventoryContent({ inventory }: { inventory: InventoryItem[] }) {
  return (
    <>
      {ZONE_NAMES.map((zoneName, zi) => (
        <div key={zoneName}>
          <div className="inventory-zone-header" style={{ color: ZONE_COLORS[zi] }}>{zoneName}</div>
          <div className="inventory-zone-grid">
            {inventory
              .slice(zi * INGREDIENTS_PER_ZONE, zi * INGREDIENTS_PER_ZONE + INGREDIENTS_PER_ZONE)
              .map((item) => (
                <IngredientIcon
                  key={item.ingredient_id}
                  ingredientId={item.ingredient_id}
                  quantity={item.quantity}
                />
              ))}
          </div>
        </div>
      ))}
    </>
  )
}
