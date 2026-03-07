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
  ingredientAssetUrl,
} from '@/game/constants'
import type { DiscoveryData } from '@/hooks/useRecipes'

export type PanelMode = 'craft' | 'grimoire' | 'inventory'

export interface InventoryItem {
  ingredient_id: number
  quantity: number
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
  const [ingredientA, setIngredientA] = useState<number | null>(available[0]?.ingredient_id ?? null)
  const [ingredientB, setIngredientB] = useState<number | null>(available[0]?.ingredient_id ?? null)

  const handleBrew = () => {
    if (ingredientA != null && ingredientB != null) onCraft(ingredientA, ingredientB)
  }

  return (
    <>
      <div className="craft-slot-row">
        <select
          value={ingredientA ?? ''}
          onChange={(e) => setIngredientA(e.target.value === '' ? null : Number(e.target.value))}
        >
          {available.map((item) => (
            <option key={`a-${item.ingredient_id}`} value={item.ingredient_id}>
              {INGREDIENT_NAMES[item.ingredient_id]} (x{item.quantity})
            </option>
          ))}
        </select>
        <span className="craft-plus">+</span>
        <select
          value={ingredientB ?? ''}
          onChange={(e) => setIngredientB(e.target.value === '' ? null : Number(e.target.value))}
        >
          {available.map((item) => (
            <option key={`b-${item.ingredient_id}`} value={item.ingredient_id}>
              {INGREDIENT_NAMES[item.ingredient_id]} (x{item.quantity})
            </option>
          ))}
        </select>
      </div>
      <div className="craft-btn-row">
        <button
          className="btn-primary"
          onClick={handleBrew}
          disabled={isGameOver || ingredientA == null || ingredientB == null || available.length === 0}
        >
          Brew
        </button>
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
            return (
              <div key={`${recipe.ingredient_a}-${recipe.ingredient_b}`} className="grimoire-card discovered">
                <div className="grimoire-card-title">#{idx + 1}</div>
                <div className="grimoire-card-info">
                  {INGREDIENT_NAMES[recipe.ingredient_a]} + {INGREDIENT_NAMES[recipe.ingredient_b]}
                </div>
                <div className="grimoire-card-info" style={{ color: effectColor }}>
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
          {inventory
            .slice(zi * INGREDIENTS_PER_ZONE, zi * INGREDIENTS_PER_ZONE + INGREDIENTS_PER_ZONE)
            .map((item) => (
              <div
                key={item.ingredient_id}
                className={`inventory-row${item.quantity === 0 ? ' inventory-row-zero' : ''}`}
              >
                <img
                  className="inventory-row-icon"
                  src={ingredientAssetUrl(item.ingredient_id)}
                  alt={INGREDIENT_NAMES[item.ingredient_id]}
                />
                <span className="inventory-row-name">{INGREDIENT_NAMES[item.ingredient_id]}</span>
                <span className="inventory-row-qty">x{item.quantity}</span>
              </div>
            ))}
        </div>
      ))}
    </>
  )
}
