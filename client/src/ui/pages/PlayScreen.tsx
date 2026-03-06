import { useCallback, useEffect, useState } from 'react'
import { useAccount } from '@starknet-react/core'
import { useDojo } from '@/dojo/useDojo'
import { useGame } from '@/hooks/useGame'
import { useHeroes } from '@/hooks/useHeroes'
import { useInventory } from '@/hooks/useInventory'
import { useRecipes } from '@/hooks/useRecipes'
import { useNavigationStore } from '@/stores/navigationStore'
import { txToast } from '@/stores/toastStore'
import type { PhaserBridge } from '@/phaser'
import {
  HERO_NAMES,
  HERO_RECRUIT_COSTS,
  HERO_STATUS_EXPLORING,
  HERO_STATUS_IDLE,
  HERO_STATUS_RETURNING,
  displayGold,
  displayHp,
  heroAssetUrl,
} from '@/game/constants'
import { StatusHUD } from '@/ui/components/StatusHUD'
import { CraftContent, GrimoireContent, InventoryContent } from '@/ui/components/RightPanel'
import { SettingsOverlay } from '@/ui/components/SettingsOverlay'

interface Props {
  bridge: PhaserBridge
}

export function PlayScreen({ bridge }: Props) {
  const { client } = useDojo()
  const { gameId, navigate } = useNavigationStore()
  const { account, address } = useAccount()
  const { session } = useGame(gameId)
  const heroes = useHeroes(gameId)
  const inventory = useInventory(gameId)
  const recipes = useRecipes(gameId)

  const [selectedHeroId, setSelectedHeroId] = useState(0)
  const [settingsOpen, setSettingsOpen] = useState(false)
  const [now, setNow] = useState(() => Math.floor(Date.now() / 1000))

  const [heroesCollapsed, setHeroesCollapsed] = useState(false)
  const [inventoryCollapsed, setInventoryCollapsed] = useState(false)
  const [craftCollapsed, setCraftCollapsed] = useState(false)
  const [grimoireCollapsed, setGrimoireCollapsed] = useState(false)

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

  useEffect(() => {
    const onHeroSelected = (heroId: number) => {
      if (heroId >= 0) setSelectedHeroId(heroId)
    }
    bridge.on('heroSelected', onHeroSelected)
    return () => { bridge.off('heroSelected', onHeroSelected) }
  }, [bridge])

  const scrollPanelIntoView = useCallback((panelClass: string, collapseSetter: React.Dispatch<React.SetStateAction<boolean>>) => {
    collapseSetter(false)
    requestAnimationFrame(() => {
      const el = document.querySelector(`.${panelClass}`)
      el?.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
    })
  }, [])

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLSelectElement) return
      switch (e.key.toLowerCase()) {
        case 'c': scrollPanelIntoView('panel-craft', setCraftCollapsed); break
        case 'g': scrollPanelIntoView('panel-grimoire', setGrimoireCollapsed); break
        case 'i': scrollPanelIntoView('panel-inventory', setInventoryCollapsed); break
        case 'escape': setSelectedHeroId(-1); break
      }
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [scrollPanelIntoView])

  const handleSendExpedition = async (heroId: number) => {
    if (!account || gameId == null) return
    const t = txToast('Sending expedition')
    try { await client.sendExpedition(account, gameId, heroId); t.success() } catch (e) { t.error(); console.error('Send expedition failed:', e) }
  }

  const handleClaimLoot = async (heroId: number) => {
    if (!account || gameId == null) return
    const t = txToast('Claiming loot')
    try { await client.claimLoot(account, gameId, heroId); t.success() } catch (e) { t.error(); console.error('Claim loot failed:', e) }
  }

  const handleCraft = async (ingredientA: number, ingredientB: number) => {
    if (!account || gameId == null) return
    const t = txToast('Brewing potion')
    try { await client.craft(account, gameId, ingredientA, ingredientB); t.success() } catch (e) { t.error(); console.error('Craft failed:', e) }
  }

  const handleBuyHint = async () => {
    if (!account || gameId == null) return
    const t = txToast('Buying hint')
    try { await client.buyHint(account, gameId); t.success() } catch (e) { t.error(); console.error('Buy hint failed:', e) }
  }

  const handleRecruitHero = async () => {
    if (!account || gameId == null) return
    const t = txToast('Recruiting hero')
    try { await client.recruitHero(account, gameId); t.success() } catch (e) { t.error(); console.error('Recruit hero failed:', e) }
  }

  const handleSurrender = async () => {
    if (!account || gameId == null) return
    const t = txToast('Surrendering')
    try { await client.surrender(account, gameId); t.success() } catch (e) { t.error(); console.error('Surrender failed:', e) }
  }

  if (gameId == null) {
    return (
      <div className="page-center">
        <p>No game selected.</p>
        <button onClick={() => navigate('home')}>Back</button>
      </div>
    )
  }

  const gold = session?.gold ?? 0
  const discoveredCount = session?.discovered_count ?? 0
  const heroCount = session?.hero_count ?? heroes.length
  const isGameOver = session?.game_over ?? false
  const hintCost = 1000 * Math.pow(3, session?.hints_used ?? 0)
  const startedAt = session ? Number(session.started_at) : now
  const elapsedSeconds = Math.max(0, now - startedAt)

  return (
    <div className="play-screen">
      <button className="play-back-btn floating-panel" onClick={() => navigate('home')}>
        ← Back
      </button>

      <StatusHUD
        gold={gold}
        discoveredCount={discoveredCount}
        elapsedSeconds={elapsedSeconds}
      />

      <button className="play-settings-btn floating-panel" onClick={() => setSettingsOpen(true)}>
        ⚙
      </button>

      <div className="play-left-panels">
        <div className="side-panel floating-panel panel-heroes">
          <button className="side-panel-header" onClick={() => setHeroesCollapsed((v) => !v)}>
            <span className="side-panel-title">Heroes</span>
            <span className="side-panel-chevron">{heroesCollapsed ? '▸' : '▾'}</span>
          </button>
          {!heroesCollapsed && (
            <div className="side-panel-body">
              {[0, 1, 2].map((slot) => (
                <HeroSlot
                  key={slot}
                  slot={slot}
                  heroes={heroes}
                  heroCount={heroCount}
                  selectedHeroId={selectedHeroId}
                  gold={gold}
                  isGameOver={isGameOver}
                  now={now}
                  onSelectHero={setSelectedHeroId}
                  onRecruit={() => void handleRecruitHero()}
                  onSendExpedition={(id) => void handleSendExpedition(id)}
                  onClaimLoot={(id) => void handleClaimLoot(id)}
                />
              ))}
            </div>
          )}
        </div>

        <div className="side-panel floating-panel panel-inventory">
          <button className="side-panel-header" onClick={() => setInventoryCollapsed((v) => !v)}>
            <span className="side-panel-title">Inventory</span>
            <span className="side-panel-chevron">{inventoryCollapsed ? '▸' : '▾'}</span>
          </button>
          {!inventoryCollapsed && (
            <div className="side-panel-body">
              <InventoryContent inventory={inventory} />
            </div>
          )}
        </div>
      </div>

      <div className="play-right-panels">
        <div className="side-panel floating-panel panel-craft">
          <button className="side-panel-header" onClick={() => setCraftCollapsed((v) => !v)}>
            <span className="side-panel-title">Brew</span>
            <span className="side-panel-chevron">{craftCollapsed ? '▸' : '▾'}</span>
          </button>
          {!craftCollapsed && (
            <div className="side-panel-body">
              <CraftContent
                inventory={inventory}
                gold={gold}
                isGameOver={isGameOver}
                hintCost={hintCost}
                onCraft={(a, b) => void handleCraft(a, b)}
                onBuyHint={() => void handleBuyHint()}
              />
            </div>
          )}
        </div>

        <div className="side-panel floating-panel panel-grimoire">
          <button className="side-panel-header" onClick={() => setGrimoireCollapsed((v) => !v)}>
            <span className="side-panel-title">Grimoire {discoveredCount}/10</span>
            <span className="side-panel-chevron">{grimoireCollapsed ? '▸' : '▾'}</span>
          </button>
          {!grimoireCollapsed && (
            <div className="side-panel-body">
              <GrimoireContent recipes={recipes} discoveredCount={discoveredCount} />
            </div>
          )}
        </div>
      </div>

      <button
        className="play-surrender-btn floating-panel btn-danger"
        onClick={() => void handleSurrender()}
        disabled={isGameOver}
      >
        Surrender
      </button>

      {isGameOver && (
        <div className="game-over-overlay">
          <div className={`game-over-card floating-panel ${discoveredCount >= 10 ? 'won' : 'lost'}`}>
            <h2>{discoveredCount >= 10 ? 'Grimoire Complete!' : 'Surrendered'}</h2>
            <button onClick={() => navigate('home')} style={{ marginTop: '1rem' }}>
              Return to Menu
            </button>
          </div>
        </div>
      )}

      {settingsOpen && address && (
        <SettingsOverlay
          open={settingsOpen}
          onClose={() => setSettingsOpen(false)}
          address={address}
        />
      )}
    </div>
  )
}

interface HeroSlotProps {
  slot: number
  heroes: Array<{
    hero_id: number
    hp: number
    max_hp: number
    status: number
    return_at: bigint | number
    pending_gold: number
  }>
  heroCount: number
  selectedHeroId: number
  gold: number
  isGameOver: boolean
  now: number
  onSelectHero: (heroId: number) => void
  onRecruit: () => void
  onSendExpedition: (heroId: number) => void
  onClaimLoot: (heroId: number) => void
}

function HeroSlot({
  slot,
  heroes,
  heroCount,
  selectedHeroId,
  gold,
  isGameOver,
  now,
  onSelectHero,
  onRecruit,
  onSendExpedition,
  onClaimLoot,
}: HeroSlotProps) {
  const hero = heroes.find((h) => h.hero_id === slot)

  if (!hero) {
    if (slot < heroCount) return null
    if (slot === heroCount && heroCount < 3) {
      const cost = HERO_RECRUIT_COSTS[Math.min(heroCount, 2)]
      return (
        <div className="hero-card hero-card-locked">
          <div className="hero-card-locked-icon">+</div>
          <div className="hero-card-info">
            <span className="hero-card-name">{HERO_NAMES[slot]}</span>
            <button
              className="hero-card-recruit btn-primary"
              onClick={onRecruit}
              disabled={isGameOver || gold < cost}
            >
              Recruit ({displayGold(cost)}g)
            </button>
          </div>
        </div>
      )
    }
    return null
  }

  const hpPct = hero.max_hp > 0 ? Math.min(100, (hero.hp / hero.max_hp) * 100) : 0
  const remaining = Math.max(0, Number(hero.return_at) - now)
  const isIdle = hero.status === HERO_STATUS_IDLE
  const isExploring = hero.status === HERO_STATUS_EXPLORING
  const isReturning = hero.status === HERO_STATUS_RETURNING
  const lootReady = isReturning && remaining === 0

  let statusText = 'Ready'
  let statusClass = ''
  if (lootReady) { statusText = 'Loot!'; statusClass = 'loot-ready' }
  else if (isExploring) { statusText = `Exploring ${remaining}s`; statusClass = 'exploring' }
  else if (isReturning) { statusText = `Returning ${remaining}s`; statusClass = 'returning' }

  const hpColor = hpPct > 50 ? 'var(--accent-green)' : hpPct > 25 ? '#ff9800' : 'var(--accent-red)'

  return (
    <div
      className={`hero-card${selectedHeroId === hero.hero_id ? ' selected' : ''}`}
      onClick={() => onSelectHero(hero.hero_id)}
    >
      <div className="hero-card-top">
        <img
          className="hero-card-portrait"
          src={heroAssetUrl(hero.hero_id)}
          alt={HERO_NAMES[hero.hero_id]}
        />
        <div className="hero-card-info">
          <span className="hero-card-name">
            {HERO_NAMES[hero.hero_id]} — {displayHp(hero.hp)}/{displayHp(hero.max_hp)}
          </span>
          <div className="hero-card-hp">
            <div className="hero-card-hp-fill" style={{ width: `${hpPct}%`, background: hpColor }} />
          </div>
          <span className={`hero-card-status ${statusClass}`}>{statusText}</span>
        </div>
      </div>
      <div className="hero-card-actions">
        {isIdle && (
          <button
            className="btn-primary btn-sm"
            onClick={(e) => { e.stopPropagation(); onSendExpedition(hero.hero_id) }}
            disabled={isGameOver}
          >
            Send Expedition
          </button>
        )}
        {isExploring && (
          <span className="hero-card-timer">Exploring... {remaining}s</span>
        )}
        {isReturning && !lootReady && (
          <span className="hero-card-timer">Returning... {remaining}s</span>
        )}
        {lootReady && (
          <button
            className="btn-primary btn-sm btn-loot"
            onClick={(e) => { e.stopPropagation(); onClaimLoot(hero.hero_id) }}
            disabled={isGameOver}
          >
            Claim Loot
          </button>
        )}
      </div>
    </div>
  )
}
