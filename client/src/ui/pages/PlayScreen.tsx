import { useEffect, useMemo, useState } from 'react'
import { useAccount } from '@starknet-react/core'
import {
  EFFECT_NAMES,
  HERO_STATUS_EXPLORING,
  HERO_STATUS_IDLE,
  HERO_STATUS_RETURNING,
  INGREDIENT_NAMES,
  ZONE_NAMES,
  displayGold,
  displayHp,
  getZoneForDepth,
} from '@/game/constants'
import { useDojo } from '@/dojo/useDojo'
import { useGame } from '@/hooks/useGame'
import { useHeroes } from '@/hooks/useHeroes'
import { useInventory } from '@/hooks/useInventory'
import { useRecipes } from '@/hooks/useRecipes'
import { useNavigationStore } from '@/stores/navigationStore'

const HERO_RECRUIT_COSTS = [0, 8000, 20000] as const

export function PlayScreen() {
  const { client } = useDojo()
  const { gameId, navigate } = useNavigationStore()
  const { account } = useAccount()
  const { session, seed } = useGame(gameId)
  const heroes = useHeroes(gameId)
  const inventory = useInventory(gameId)
  const recipes = useRecipes(gameId)

  const [ingredientA, setIngredientA] = useState<number | null>(null)
  const [ingredientB, setIngredientB] = useState<number | null>(null)
  const [now, setNow] = useState(() => Math.floor(Date.now() / 1000))

  useEffect(() => {
    const timer = window.setInterval(() => {
      setNow(Math.floor(Date.now() / 1000))
    }, 1000)

    return () => {
      window.clearInterval(timer)
    }
  }, [])

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
    setIngredientA((current) => (current != null && availableIngredients.some((i) => i.ingredient_id === current) ? current : firstId))
    setIngredientB((current) => (current != null && availableIngredients.some((i) => i.ingredient_id === current) ? current : firstId))
  }, [availableIngredients])

  const handleSendExpedition = async (heroId: number) => {
    if (!account || gameId == null) return
    try {
      await client.sendExpedition(account, gameId, heroId)
    } catch (error) {
      console.error('Send expedition failed:', error)
    }
  }

  const handleClaimLoot = async (heroId: number) => {
    if (!account || gameId == null) return
    try {
      await client.claimLoot(account, gameId, heroId)
    } catch (error) {
      console.error('Claim loot failed:', error)
    }
  }

  const handleCraft = async () => {
    if (!account || gameId == null || ingredientA == null || ingredientB == null) return
    try {
      await client.craft(account, gameId, ingredientA, ingredientB)
    } catch (error) {
      console.error('Craft failed:', error)
    }
  }

  const handleBuyHint = async () => {
    if (!account || gameId == null) return
    try {
      await client.buyHint(account, gameId)
    } catch (error) {
      console.error('Buy hint failed:', error)
    }
  }

  const handleRecruitHero = async () => {
    if (!account || gameId == null) return
    try {
      await client.recruitHero(account, gameId)
    } catch (error) {
      console.error('Recruit hero failed:', error)
    }
  }

  const handleSurrender = async () => {
    if (!account || gameId == null) return
    try {
      await client.surrender(account, gameId)
    } catch (error) {
      console.error('Surrender failed:', error)
    }
  }

  if (gameId == null) {
    return (
      <main style={{ padding: '2rem', maxWidth: 1080, margin: '0 auto' }}>
        <h1>Play</h1>
        <p>No game selected.</p>
        <button onClick={() => navigate('home')}>Back</button>
      </main>
    )
  }

  const discoveredCount = session?.discovered_count ?? 0
  const hintCost = 1000 * Math.pow(3, session?.hints_used ?? 0)
  const heroCount = session?.hero_count ?? heroes.length
  const recruitCost = HERO_RECRUIT_COSTS[Math.min(heroCount, 2)]
  const isGameOver = session?.game_over ?? false

  return (
    <main style={{ padding: '2rem', maxWidth: 1080, margin: '0 auto', display: 'grid', gap: '1rem' }}>
      <section
        style={{
          background: '#1d1d1d',
          border: '1px solid #2f2f2f',
          borderRadius: 12,
          padding: '1rem',
          display: 'grid',
          gap: '0.75rem',
        }}
      >
        <div style={{ display: 'flex', justifyContent: 'space-between', gap: '0.5rem', alignItems: 'center', flexWrap: 'wrap' }}>
          <h1 style={{ margin: 0 }}>Game #{gameId}</h1>
          <div style={{ display: 'flex', gap: '0.5rem' }}>
            <button onClick={() => navigate('home')}>Back</button>
            <button onClick={handleSurrender} disabled={!account || isGameOver}>
              Surrender
            </button>
          </div>
        </div>
        <div style={{ display: 'flex', gap: '1rem', flexWrap: 'wrap', color: 'rgba(255,255,255,0.85)' }}>
          <span>Gold: {displayGold(session?.gold ?? 0)}</span>
          <span>Discovered: {discoveredCount}/10</span>
          <span>Seed: {seed ? `#${String(seed.seed).slice(0, 8)}` : 'Pending'}</span>
        </div>
      </section>

      <section style={{ background: '#1d1d1d', border: '1px solid #2f2f2f', borderRadius: 12, padding: '1rem' }}>
        <h2 style={{ marginTop: 0 }}>Heroes</h2>
        <div style={{ display: 'grid', gap: '0.75rem' }}>
          {[0, 1, 2].map((heroSlot) => {
            const hero = heroes.find((item) => item.hero_id === heroSlot)
            if (!hero) {
              return (
                <div
                  key={heroSlot}
                  style={{ border: '1px solid #303030', borderRadius: 10, padding: '0.75rem', color: 'rgba(255,255,255,0.6)' }}
                >
                  Hero {heroSlot}: Unrecruited
                </div>
              )
            }

            const hpPercent = hero.max_hp > 0 ? Math.min(100, (hero.hp / hero.max_hp) * 100) : 0
            const remainingSeconds = Math.max(0, Number(hero.return_at) - now)
            const zoneId = Math.min(getZoneForDepth(hero.death_depth + 1), ZONE_NAMES.length - 1)
            const isIdle = hero.status === HERO_STATUS_IDLE
            const isExploring = hero.status === HERO_STATUS_EXPLORING
            const isReturning = hero.status === HERO_STATUS_RETURNING

            let statusLabel = 'Idle'
            if (hero.loot_ready || (isReturning && remainingSeconds === 0)) {
              statusLabel = 'Loot Ready!'
            } else if (isExploring) {
              statusLabel = `Exploring (returns in ${remainingSeconds}s)`
            }

            const hpColor = hero.hp > hero.max_hp * 0.5 ? '#4caf50' : hero.hp > hero.max_hp * 0.25 ? '#ff9800' : '#f44336'

            return (
              <div key={hero.hero_id} style={{ border: '1px solid #303030', borderRadius: 10, padding: '0.75rem', display: 'grid', gap: '0.5rem' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', gap: '1rem', flexWrap: 'wrap' }}>
                  <strong>Hero {hero.hero_id}</strong>
                  <span>{statusLabel}</span>
                </div>
                <div style={{ width: '100%', background: '#333', borderRadius: 4, height: 16 }}>
                  <div style={{ width: `${hpPercent}%`, background: hpColor, height: '100%', borderRadius: 4 }} />
                </div>
                <div style={{ display: 'flex', gap: '1rem', flexWrap: 'wrap', color: 'rgba(255,255,255,0.82)' }}>
                  <span>HP: {displayHp(hero.hp)}/{displayHp(hero.max_hp)}</span>
                  <span>Power: {displayHp(hero.power)}</span>
                  <span>Regen: {displayHp(hero.regen_per_sec)}/s</span>
                  <span>Depth: {hero.death_depth}</span>
                  <span>Next Zone: {ZONE_NAMES[zoneId]}</span>
                </div>
                <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
                  {isIdle ? (
                    <button onClick={() => void handleSendExpedition(hero.hero_id)} disabled={!account || isGameOver}>
                      Send Expedition
                    </button>
                  ) : null}
                  {hero.loot_ready || (isReturning && remainingSeconds === 0) ? (
                    <button onClick={() => void handleClaimLoot(hero.hero_id)} disabled={!account || isGameOver}>
                      Claim Loot
                    </button>
                  ) : null}
                </div>
              </div>
            )
          })}
        </div>
      </section>

      <section style={{ background: '#1d1d1d', border: '1px solid #2f2f2f', borderRadius: 12, padding: '1rem' }}>
        <h2 style={{ marginTop: 0 }}>Inventory</h2>
        <div style={{ display: 'grid', gap: '0.75rem' }}>
          {ZONE_NAMES.map((zoneName, zoneIndex) => (
            <div key={zoneName}>
              <h3 style={{ margin: '0 0 0.5rem 0', fontSize: '1rem' }}>{zoneName}</h3>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, minmax(120px, 1fr))', gap: '0.5rem' }}>
                {inventory.slice(zoneIndex * 3, zoneIndex * 3 + 3).map((item) => (
                  <div key={item.ingredient_id} style={{ border: '1px solid #303030', borderRadius: 8, padding: '0.5rem' }}>
                    <div style={{ fontSize: '0.95rem' }}>{INGREDIENT_NAMES[item.ingredient_id]}</div>
                    <div style={{ color: 'rgba(255,255,255,0.72)' }}>x{item.quantity}</div>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      </section>

      <section style={{ background: '#1d1d1d', border: '1px solid #2f2f2f', borderRadius: 12, padding: '1rem' }}>
        <h2 style={{ marginTop: 0 }}>Crafting</h2>
        <div style={{ display: 'grid', gap: '0.75rem', maxWidth: 520 }}>
          <label style={{ display: 'grid', gap: '0.3rem' }}>
            Ingredient A
            <select
              value={ingredientA ?? ''}
              onChange={(event) => setIngredientA(event.target.value === '' ? null : Number(event.target.value))}
            >
              {availableIngredients.map((item) => (
                <option key={`a-${item.ingredient_id}`} value={item.ingredient_id}>
                  {INGREDIENT_NAMES[item.ingredient_id]} (x{item.quantity})
                </option>
              ))}
            </select>
          </label>
          <label style={{ display: 'grid', gap: '0.3rem' }}>
            Ingredient B
            <select
              value={ingredientB ?? ''}
              onChange={(event) => setIngredientB(event.target.value === '' ? null : Number(event.target.value))}
            >
              {availableIngredients.map((item) => (
                <option key={`b-${item.ingredient_id}`} value={item.ingredient_id}>
                  {INGREDIENT_NAMES[item.ingredient_id]} (x{item.quantity})
                </option>
              ))}
            </select>
          </label>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem' }}>
            <button
              onClick={() => void handleCraft()}
              disabled={!account || isGameOver || ingredientA == null || ingredientB == null || availableIngredients.length === 0}
            >
              Craft
            </button>
            <button onClick={() => void handleBuyHint()} disabled={!account || isGameOver}>
              Buy Hint ({displayGold(hintCost)} gold)
            </button>
            {heroCount < 3 ? (
              <button onClick={() => void handleRecruitHero()} disabled={!account || isGameOver}>
                Recruit Hero ({displayGold(recruitCost)} gold)
              </button>
            ) : null}
          </div>
        </div>
      </section>

      <section style={{ background: '#1d1d1d', border: '1px solid #2f2f2f', borderRadius: 12, padding: '1rem' }}>
        <h2 style={{ marginTop: 0 }}>Grimoire</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, minmax(220px, 1fr))', gap: '0.75rem' }}>
          {Array.from({ length: 10 }, (_, recipeId) => {
            const recipe = recipes.find((item) => item.recipe_id === recipeId)
            const discovered = recipe?.discovered ?? false
            return (
              <div key={recipeId} style={{ border: '1px solid #303030', borderRadius: 8, padding: '0.6rem' }}>
                {discovered && recipe ? (
                  <div style={{ display: 'grid', gap: '0.25rem' }}>
                    <strong>Recipe #{recipeId + 1}</strong>
                    <span>
                      {INGREDIENT_NAMES[recipe.ingredient_a]} + {INGREDIENT_NAMES[recipe.ingredient_b]}
                    </span>
                    <span>
                      {EFFECT_NAMES[recipe.effect_type]} +{displayHp(recipe.effect_value)}
                    </span>
                  </div>
                ) : (
                  <div style={{ color: 'rgba(255,255,255,0.65)' }}>Recipe #{recipeId + 1}: ???</div>
                )}
              </div>
            )
          })}
        </div>
      </section>

      {isGameOver ? (
        <section
          style={{
            background: discoveredCount >= 10 ? '#243224' : '#322424',
            border: '1px solid #3a3a3a',
            borderRadius: 12,
            padding: '1rem',
          }}
        >
          <h2 style={{ margin: 0 }}>{discoveredCount >= 10 ? 'Grimoire Complete!' : 'Surrendered'}</h2>
        </section>
      ) : null}
    </main>
  )
}
