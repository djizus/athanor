import { useMemo, useState } from 'react'
import {
  EFFECT_COLORS,
  EFFECT_NAMES,
  INGREDIENT_NAMES,
  INGREDIENTS_PER_ZONE,
  ZONE_COLORS,
  ZONE_NAMES,
  displayGold,
  displayHp,
  ingredientAssetUrl,
} from '@/game/constants'

export type PanelMode = 'craft' | 'grimoire' | 'inventory'

interface InventoryItem {
  ingredient_id: number
  quantity: number
}

interface RecipeData {
  recipe_id: number
  discovered: boolean
  ingredient_a: number
  ingredient_b: number
  effect_type: number
  effect_value: number
}

interface Props {
  mode: PanelMode
  onClose: () => void
  inventory: InventoryItem[]
  recipes: RecipeData[]
  discoveredCount: number
  gold: number
  isGameOver: boolean
  hintCost: number
  onCraft: (ingredientA: number, ingredientB: number) => void
  onBuyHint: () => void
}

export function RightPanel({
  mode,
  onClose,
  inventory,
  recipes,
  discoveredCount,
  gold,
  isGameOver,
  hintCost,
  onCraft,
  onBuyHint,
}: Props) {
  const titles: Record<PanelMode, string> = {
    craft: 'Brew',
    grimoire: `Grimoire ${discoveredCount}/10`,
    inventory: 'Inventory',
  }

  return (
    <div className="right-panel floating-panel" key={mode}>
      <div className="right-panel-header">
        <span className="right-panel-title">{titles[mode]}</span>
        <button className="right-panel-close" onClick={onClose}>✕</button>
      </div>
      <div className="right-panel-body">
        {mode === 'craft' && (
          <CraftContent
            inventory={inventory}
            gold={gold}
            isGameOver={isGameOver}
            hintCost={hintCost}
            onCraft={onCraft}
            onBuyHint={onBuyHint}
          />
        )}
        {mode === 'grimoire' && (
          <GrimoireContent recipes={recipes} discoveredCount={discoveredCount} />
        )}
        {mode === 'inventory' && (
          <InventoryContent inventory={inventory} />
        )}
      </div>
    </div>
  )
}

function CraftContent({
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

function GrimoireContent({
  recipes,
  discoveredCount,
}: {
  recipes: RecipeData[]
  discoveredCount: number
}) {
  return (
    <>
      <div className="grimoire-progress">
        <div className="grimoire-progress-fill" style={{ width: `${(discoveredCount / 10) * 100}%` }} />
      </div>
      <div className="grimoire-grid">
        {Array.from({ length: 10 }, (_, recipeId) => {
          const recipe = recipes.find((r) => r.recipe_id === recipeId)
          const discovered = recipe?.discovered ?? false
          return (
            <div key={recipeId} className={`grimoire-card${discovered ? ' discovered' : ''}`}>
              {discovered && recipe ? (
                <>
                  <div className="grimoire-card-title">#{recipeId + 1}</div>
                  <div className="grimoire-card-info">
                    {INGREDIENT_NAMES[recipe.ingredient_a]} + {INGREDIENT_NAMES[recipe.ingredient_b]}
                  </div>
                  <div className="grimoire-card-info" style={{ color: EFFECT_COLORS[recipe.effect_type] }}>
                    {EFFECT_NAMES[recipe.effect_type]} +{displayHp(recipe.effect_value)}
                  </div>
                </>
              ) : (
                <div className="grimoire-card-undiscovered">#{recipeId + 1} — ???</div>
              )}
            </div>
          )
        })}
      </div>
    </>
  )
}

function InventoryContent({ inventory }: { inventory: InventoryItem[] }) {
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
