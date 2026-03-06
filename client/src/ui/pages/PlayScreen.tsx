import { useEffect, useMemo, useState } from 'react'
import { useAccount } from '@starknet-react/core'
import {
  EFFECT_COLORS,
  EFFECT_NAMES,
  HERO_NAMES,
  HERO_RECRUIT_COSTS,
  HERO_STATUS_EXPLORING,
  HERO_STATUS_IDLE,
  HERO_STATUS_RETURNING,
  INGREDIENT_NAMES,
  INGREDIENTS_PER_ZONE,
  ZONE_COLORS,
  ZONE_NAMES,
  displayGold,
  displayHp,
  getZoneForDepth,
  heroAssetUrl,
  ingredientAssetUrl,
} from '@/game/constants'
import { useDojo } from '@/dojo/useDojo'
import { useGame } from '@/hooks/useGame'
import { useHeroes } from '@/hooks/useHeroes'
import { useInventory } from '@/hooks/useInventory'
import { useRecipes } from '@/hooks/useRecipes'
import { useNavigationStore } from '@/stores/navigationStore'
import type { PhaserBridge } from '@/phaser'

type TabId = 'heroes' | 'craft' | 'grimoire' | 'bag'

const TABS: { id: TabId; label: string }[] = [
  { id: 'heroes', label: 'Heroes' },
  { id: 'craft', label: 'Craft' },
  { id: 'grimoire', label: 'Grimoire' },
  { id: 'bag', label: 'Bag' },
]

interface Props {
  bridge: PhaserBridge
}

export function PlayScreen({ bridge }: Props) {
  const { client } = useDojo()
  const { gameId, navigate } = useNavigationStore()
  const { account } = useAccount()
  const { session, seed } = useGame(gameId)
  const heroes = useHeroes(gameId)
  const inventory = useInventory(gameId)
  const recipes = useRecipes(gameId)

  const [activeTab, setActiveTab] = useState<TabId>('heroes')
  const [ingredientA, setIngredientA] = useState<number | null>(null)
  const [ingredientB, setIngredientB] = useState<number | null>(null)
  const [now, setNow] = useState(() => Math.floor(Date.now() / 1000))

  useEffect(() => {
    const timer = window.setInterval(() => setNow(Math.floor(Date.now() / 1000)), 1000)
    return () => window.clearInterval(timer)
  }, [])

  useEffect(() => {
    bridge.updateHeroes(
      heroes.map((h) => ({
        hero_id: h.hero_id,
        hp: h.hp,
        max_hp: h.max_hp,
        power: h.power,
        regen_per_sec: h.regen_per_sec,
        status: h.status,
        return_at: Number(h.return_at),
        death_depth: h.death_depth,
        pending_gold: h.pending_gold,
      })),
    )
  }, [heroes, bridge])

  useEffect(() => {
    if (session) {
      bridge.updateSession({
        game_id: gameId ?? 0,
        gold: session.gold,
        discovered_count: session.discovered_count,
        hero_count: session.hero_count,
        game_over: session.game_over,
        started_at: Number(session.started_at),
      })
    }
  }, [session, bridge, gameId])

  const availableIngredients = useMemo(
    () => inventory.filter((item) => item.quantity > 0),
    [inventory],
  )

  useEffect(() => {
    if (availableIngredients.length === 0) {
      setIngredientA(null)
      setIngredientB(null)
      return
    }
    const firstId = availableIngredients[0].ingredient_id
    setIngredientA((c) => (c != null && availableIngredients.some((i) => i.ingredient_id === c) ? c : firstId))
    setIngredientB((c) => (c != null && availableIngredients.some((i) => i.ingredient_id === c) ? c : firstId))
  }, [availableIngredients])

  const handleSendExpedition = async (heroId: number) => {
    if (!account || gameId == null) return
    try { await client.sendExpedition(account, gameId, heroId) } catch (e) { console.error('Send expedition failed:', e) }
  }

  const handleClaimLoot = async (heroId: number) => {
    if (!account || gameId == null) return
    try { await client.claimLoot(account, gameId, heroId) } catch (e) { console.error('Claim loot failed:', e) }
  }

  const handleCraft = async () => {
    if (!account || gameId == null || ingredientA == null || ingredientB == null) return
    try { await client.craft(account, gameId, ingredientA, ingredientB) } catch (e) { console.error('Craft failed:', e) }
  }

  const handleBuyHint = async () => {
    if (!account || gameId == null) return
    try { await client.buyHint(account, gameId) } catch (e) { console.error('Buy hint failed:', e) }
  }

  const handleRecruitHero = async () => {
    if (!account || gameId == null) return
    try { await client.recruitHero(account, gameId) } catch (e) { console.error('Recruit hero failed:', e) }
  }

  const handleSurrender = async () => {
    if (!account || gameId == null) return
    try { await client.surrender(account, gameId) } catch (e) { console.error('Surrender failed:', e) }
  }

  if (gameId == null) {
    return (
      <div className="page-center">
        <p>No game selected.</p>
        <button onClick={() => navigate('home')}>Back</button>
      </div>
    )
  }

  const discoveredCount = session?.discovered_count ?? 0
  const hintCost = 1000 * Math.pow(3, session?.hints_used ?? 0)
  const heroCount = session?.hero_count ?? heroes.length
  const recruitCost = HERO_RECRUIT_COSTS[Math.min(heroCount, 2)]
  const isGameOver = session?.game_over ?? false

  return (
    <div className="page">
      <div className="status-bar">
        <span className="status-bar-title">ATHANOR</span>
        <div className="status-bar-stats">
          <span>Gold: {displayGold(session?.gold ?? 0)}</span>
          <span>{discoveredCount}/10</span>
          <span>{seed ? `#${String(seed.seed).slice(0, 8)}` : '...'}</span>
        </div>
        <div className="status-bar-actions">
          <button onClick={() => navigate('home')}>Back</button>
          <button className="btn-danger" onClick={handleSurrender} disabled={!account || isGameOver}>
            Surrender
          </button>
        </div>
      </div>

      <div className="tab-bar">
        {TABS.map(({ id, label }) => (
          <button
            key={id}
            className={`tab${activeTab === id ? ' active' : ''}`}
            onClick={() => setActiveTab(id)}
          >
            {label}
          </button>
        ))}
      </div>

      <div className="tab-content">
        {activeTab === 'heroes' && (
          <>
            {[0, 1, 2].map((slot) => {
              const hero = heroes.find((h) => h.hero_id === slot)
              if (!hero) {
                if (slot < heroCount) return null
                if (slot === heroCount && heroCount < 3) {
                  return (
                    <div key={slot} className="hero-card">
                      <div className="hero-header">
                        <span className="hero-name">{HERO_NAMES[slot]}</span>
                        <span className="hero-status">Locked</span>
                      </div>
                      <button className="btn-primary" onClick={() => void handleRecruitHero()} disabled={!account || isGameOver}>
                        Recruit ({displayGold(recruitCost)}g)
                      </button>
                    </div>
                  )
                }
                return null
              }

              const hpPct = hero.max_hp > 0 ? Math.min(100, (hero.hp / hero.max_hp) * 100) : 0
              const remaining = Math.max(0, Number(hero.return_at) - now)
              const zoneId = Math.min(getZoneForDepth(hero.death_depth + 1), ZONE_NAMES.length - 1)
              const isIdle = hero.status === HERO_STATUS_IDLE
              const isExploring = hero.status === HERO_STATUS_EXPLORING
              const isReturning = hero.status === HERO_STATUS_RETURNING
              const lootReady = isReturning && remaining === 0

              let statusText = 'Ready'
              let statusClass = ''
              if (lootReady) { statusText = 'Loot Ready'; statusClass = 'loot-ready' }
              else if (isExploring) { statusText = `Exploring (${remaining}s)`; statusClass = 'exploring' }
              else if (isReturning) { statusText = `Returning (${remaining}s)`; statusClass = 'returning' }

              const hpClass = hpPct > 50 ? 'hp-high' : hpPct > 25 ? 'hp-mid' : 'hp-low'

              return (
                <div key={hero.hero_id} className="hero-card">
                  <div className="hero-header">
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                      <img className="hero-portrait" src={heroAssetUrl(hero.hero_id)} alt={HERO_NAMES[hero.hero_id]} />
                      <span className="hero-name">{HERO_NAMES[hero.hero_id]}</span>
                    </div>
                    <span className={`hero-status ${statusClass}`}>{statusText}</span>
                  </div>
                  <div className="stat-bar">
                    <div className={`stat-bar-fill ${hpClass}`} style={{ width: `${hpPct}%` }} />
                  </div>
                  <div className="hero-stats">
                    <span>HP: {displayHp(hero.hp)}/{displayHp(hero.max_hp)}</span>
                    <span>Pwr: {displayHp(hero.power)}</span>
                    <span>Rgn: {displayHp(hero.regen_per_sec)}/s</span>
                    <span>Depth: {hero.death_depth} ({ZONE_NAMES[zoneId]})</span>
                  </div>
                  <div className="hero-actions">
                    {isIdle && (
                      <button className="btn-primary" onClick={() => void handleSendExpedition(hero.hero_id)} disabled={!account || isGameOver}>
                        Send Expedition
                      </button>
                    )}
                    {lootReady && (
                      <button className="btn-primary" onClick={() => void handleClaimLoot(hero.hero_id)} disabled={!account || isGameOver}>
                        Claim Loot
                      </button>
                    )}
                  </div>
                </div>
              )
            })}
          </>
        )}

        {activeTab === 'craft' && (
          <div className="craft-panel">
            <div className="panel-title">Combine Ingredients</div>
            <div className="craft-selects">
              <select
                value={ingredientA ?? ''}
                onChange={(e) => setIngredientA(e.target.value === '' ? null : Number(e.target.value))}
              >
                {availableIngredients.map((item) => (
                  <option key={`a-${item.ingredient_id}`} value={item.ingredient_id}>
                    {INGREDIENT_NAMES[item.ingredient_id]} (x{item.quantity})
                  </option>
                ))}
              </select>
              <select
                value={ingredientB ?? ''}
                onChange={(e) => setIngredientB(e.target.value === '' ? null : Number(e.target.value))}
              >
                {availableIngredients.map((item) => (
                  <option key={`b-${item.ingredient_id}`} value={item.ingredient_id}>
                    {INGREDIENT_NAMES[item.ingredient_id]} (x{item.quantity})
                  </option>
                ))}
              </select>
            </div>
            <div className="craft-actions">
              <button
                className="btn-primary"
                onClick={() => void handleCraft()}
                disabled={!account || isGameOver || ingredientA == null || ingredientB == null || availableIngredients.length === 0}
              >
                Brew
              </button>
              <button onClick={() => void handleBuyHint()} disabled={!account || isGameOver}>
                Buy Hint ({displayGold(hintCost)}g)
              </button>
            </div>
          </div>
        )}

        {activeTab === 'grimoire' && (
          <>
            <div className="panel-title">Recipes {discoveredCount}/10</div>
            <div className="recipe-grid">
              {Array.from({ length: 10 }, (_, recipeId) => {
                const recipe = recipes.find((r) => r.recipe_id === recipeId)
                const discovered = recipe?.discovered ?? false
                return (
                  <div key={recipeId} className={`recipe-card${discovered ? ' discovered' : ''}`}>
                    {discovered && recipe ? (
                      <>
                        <div className="recipe-card-title">Recipe #{recipeId + 1}</div>
                        <div className="recipe-card-info">
                          {INGREDIENT_NAMES[recipe.ingredient_a]} + {INGREDIENT_NAMES[recipe.ingredient_b]}
                        </div>
                        <div className="recipe-card-info" style={{ color: EFFECT_COLORS[recipe.effect_type] }}>
                          {EFFECT_NAMES[recipe.effect_type]} +{displayHp(recipe.effect_value)}
                        </div>
                      </>
                    ) : (
                      <div className="recipe-card-undiscovered">Recipe #{recipeId + 1} — ???</div>
                    )}
                  </div>
                )
              })}
            </div>
          </>
        )}

        {activeTab === 'bag' && (
          <>
            {ZONE_NAMES.map((zoneName, zi) => (
              <div key={zoneName}>
                <div className="zone-header" style={{ color: ZONE_COLORS[zi] }}>{zoneName}</div>
                {inventory.slice(zi * INGREDIENTS_PER_ZONE, zi * INGREDIENTS_PER_ZONE + INGREDIENTS_PER_ZONE).map((item) => (
                  <div key={item.ingredient_id} className="ingredient-row">
                    <img className="ingredient-icon" src={ingredientAssetUrl(item.ingredient_id)} alt={INGREDIENT_NAMES[item.ingredient_id]} />
                    <span className="ingredient-name">{INGREDIENT_NAMES[item.ingredient_id]}</span>
                    <span className="ingredient-qty">x{item.quantity}</span>
                  </div>
                ))}
              </div>
            ))}
          </>
        )}

        {isGameOver && (
          <div className={`game-over-banner ${discoveredCount >= 10 ? 'won' : 'lost'}`}>
            <h2>{discoveredCount >= 10 ? 'Grimoire Complete!' : 'Surrendered'}</h2>
          </div>
        )}
      </div>
    </div>
  )
}
