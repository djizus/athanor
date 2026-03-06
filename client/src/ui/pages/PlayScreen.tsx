import { useCallback, useEffect, useState } from 'react'
import { useAccount } from '@starknet-react/core'
import { useDojo } from '@/dojo/useDojo'
import { useGame } from '@/hooks/useGame'
import { useHeroes } from '@/hooks/useHeroes'
import { useInventory } from '@/hooks/useInventory'
import { useRecipes } from '@/hooks/useRecipes'
import { useNavigationStore } from '@/stores/navigationStore'
import type { PhaserBridge } from '@/phaser'
import { StatusHUD } from '@/ui/components/StatusHUD'
import { MiniHeroRoster } from '@/ui/components/MiniHeroRoster'
import { ActionBar } from '@/ui/components/ActionBar'
import { RightPanel, type PanelMode } from '@/ui/components/RightPanel'
import { HotkeyBar } from '@/ui/components/HotkeyBar'
import { SettingsOverlay } from '@/ui/components/SettingsOverlay'

interface Props {
  bridge: PhaserBridge
}

export function PlayScreen({ bridge }: Props) {
  const { client } = useDojo()
  const { gameId, navigate } = useNavigationStore()
  const { account, address } = useAccount()
  const { session, seed } = useGame(gameId)
  const heroes = useHeroes(gameId)
  const inventory = useInventory(gameId)
  const recipes = useRecipes(gameId)

  const [selectedHeroId, setSelectedHeroId] = useState(0)
  const [activePanel, setActivePanel] = useState<PanelMode | null>(null)
  const [settingsOpen, setSettingsOpen] = useState(false)
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

  useEffect(() => {
    const onHeroSelected = (heroId: number) => {
      if (heroId >= 0) setSelectedHeroId(heroId)
    }
    bridge.on('heroSelected', onHeroSelected)
    return () => { bridge.off('heroSelected', onHeroSelected) }
  }, [bridge])

  const togglePanel = useCallback((mode: PanelMode) => {
    setActivePanel((current) => (current === mode ? null : mode))
  }, [])

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLSelectElement) return
      switch (e.key.toLowerCase()) {
        case 'c': togglePanel('craft'); break
        case 'g': togglePanel('grimoire'); break
        case 'i': togglePanel('inventory'); break
        case 'escape': setActivePanel(null); break
      }
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [togglePanel])

  const handleSendExpedition = async (heroId: number) => {
    if (!account || gameId == null) return
    try { await client.sendExpedition(account, gameId, heroId) } catch (e) { console.error('Send expedition failed:', e) }
  }

  const handleClaimLoot = async (heroId: number) => {
    if (!account || gameId == null) return
    try { await client.claimLoot(account, gameId, heroId) } catch (e) { console.error('Claim loot failed:', e) }
  }

  const handleCraft = async (ingredientA: number, ingredientB: number) => {
    if (!account || gameId == null) return
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

  const gold = session?.gold ?? 0
  const discoveredCount = session?.discovered_count ?? 0
  const heroCount = session?.hero_count ?? heroes.length
  const isGameOver = session?.game_over ?? false
  const hintCost = 1000 * Math.pow(3, session?.hints_used ?? 0)
  const seedLabel = seed ? `#${String(seed.seed).slice(0, 8)}` : '...'

  return (
    <div className="play-screen">
      <StatusHUD
        gold={gold}
        discoveredCount={discoveredCount}
        seedLabel={seedLabel}
        isGameOver={isGameOver}
        onSurrender={() => void handleSurrender()}
        onBack={() => navigate('home')}
      />

      <MiniHeroRoster
        heroes={heroes}
        heroCount={heroCount}
        selectedHeroId={selectedHeroId}
        gold={gold}
        isGameOver={isGameOver}
        now={now}
        onSelectHero={setSelectedHeroId}
        onRecruit={() => void handleRecruitHero()}
      />

      <ActionBar
        heroes={heroes}
        selectedHeroId={selectedHeroId}
        isGameOver={isGameOver}
        now={now}
        onSendExpedition={(id) => void handleSendExpedition(id)}
        onClaimLoot={(id) => void handleClaimLoot(id)}
      />

      {activePanel && (
        <RightPanel
          mode={activePanel}
          onClose={() => setActivePanel(null)}
          inventory={inventory}
          recipes={recipes}
          discoveredCount={discoveredCount}
          gold={gold}
          isGameOver={isGameOver}
          hintCost={hintCost}
          onCraft={(a, b) => void handleCraft(a, b)}
          onBuyHint={() => void handleBuyHint()}
        />
      )}

      <HotkeyBar
        activePanel={activePanel}
        onTogglePanel={togglePanel}
        onSettings={() => setSettingsOpen(true)}
      />

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
