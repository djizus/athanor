import { useState } from 'react'
import { useAccount, useConnect } from '@starknet-react/core'
import type ControllerConnector from '@cartridge/connector/controller'
import { usePlayerName } from '@/hooks/usePlayerName'
import { useNavigationStore } from '@/stores/navigationStore'
import { SettingsOverlay } from '@/ui/components/SettingsOverlay'

export function HowToPlayPage() {
  const { navigate } = useNavigationStore()
  const { address } = useAccount()
  const { connectors } = useConnect()
  const { displayName } = usePlayerName(address)
  const [settingsOpen, setSettingsOpen] = useState(false)

  return (
    <div className="glass-page">
      <div className="glass-page-topbar">
        <button
          className="home-menu-player-chip"
          type="button"
          onClick={() => {
            const ctrl = connectors[0] as ControllerConnector | undefined
            if (ctrl?.controller) void ctrl.controller.openProfile()
          }}
        >
          <span className="home-menu-player-name">{displayName}</span>
        </button>
        <div className="glass-page-header-actions">
          <button className="home-menu-gear" onClick={() => setSettingsOpen(true)} aria-label="Settings">
            <span aria-hidden>&#x2699;</span>
          </button>
          <button onClick={() => navigate('home')}>Back</button>
        </div>
      </div>

      <div className="glass-page-panel">
        <div className="glass-page-header">
          <h1 className="glass-page-title">How to Play</h1>
        </div>

        <div className="glass-page-body htp-body">
          <section className="htp-section">
            <h2 className="htp-heading">Goal</h2>
            <p className="htp-text">
              You are an alchemist. Discover all <strong>30 potions</strong> as fast as possible by
              exploring dangerous zones, gathering ingredients, and brewing recipes. Your time is
              tracked on the leaderboard &mdash; speed matters.
            </p>
          </section>

          <section className="htp-section">
            <h2 className="htp-heading">Heroes</h2>
            <p className="htp-text">
              You start with one hero and can recruit up to <strong>3</strong>. Each hero has
              a role &mdash; <em>Mage</em>, <em>Rogue</em>, or <em>Warrior</em> &mdash; with
              different base stats:
            </p>
            <ul className="htp-list">
              <li><strong>Health (HP)</strong> &mdash; determines how deep a hero can explore before needing rest.</li>
              <li><strong>Power (PWR)</strong> &mdash; increases gold earned from exploration and combat.</li>
              <li><strong>Regen</strong> &mdash; how fast HP recovers while idle.</li>
            </ul>
          </section>

          <section className="htp-section">
            <h2 className="htp-heading">Exploration</h2>
            <p className="htp-text">
              Send heroes into the depths to gather ingredients and earn gold. There are <strong>5 zones</strong>,
              each with 5 unique ingredients. Deeper zones yield rarer materials but cost more HP.
              During exploration, heroes may encounter:
            </p>
            <ul className="htp-list">
              <li><strong>Ingredients</strong> &mdash; collected automatically for brewing.</li>
              <li><strong>Gold</strong> &mdash; found in caches throughout the zones.</li>
              <li><strong>Beasts</strong> &mdash; win to earn gold, lose to take HP damage.</li>
              <li><strong>Traps</strong> &mdash; unavoidable HP loss.</li>
              <li><strong>Healing</strong> &mdash; restores some HP during the expedition.</li>
            </ul>
            <p className="htp-text">
              After an expedition, <strong>claim the loot</strong> to collect the hero&rsquo;s gathered
              gold and ingredients. Heroes regenerate HP while idle at the Athanor.
            </p>
          </section>

          <section className="htp-section">
            <h2 className="htp-heading">Brewing</h2>
            <p className="htp-text">
              Select two different ingredients and brew them together. Each unique pair produces a
              specific potion &mdash; or a <strong>Soup</strong> (failed recipe that gives +1 gold).
              Discovered recipes are saved to your Grimoire. Use <strong>Brew All</strong> to
              try every untested combination at once.
            </p>
          </section>

          <section className="htp-section">
            <h2 className="htp-heading">Potions</h2>
            <p className="htp-text">
              Potions come in three categories:
            </p>
            <ul className="htp-list">
              <li><span className="htp-cat htp-cat-health">Health</span> &mdash; boosts max HP.</li>
              <li><span className="htp-cat htp-cat-power">Power</span> &mdash; increases PWR for better combat and exploration rewards.</li>
              <li><span className="htp-cat htp-cat-regen">Regen</span> &mdash; speeds up HP recovery while idle.</li>
            </ul>
            <p className="htp-text">
              Apply potions to your heroes from their hero card. You&rsquo;ll see the stat
              bonuses appear as floating numbers on the hero.
            </p>
          </section>

          <section className="htp-section">
            <h2 className="htp-heading">Grimoire</h2>
            <p className="htp-text">
              Your Grimoire tracks all discovered and hinted potions. Use the filter tabs
              (<strong>All</strong>, <strong>Health</strong>, <strong>Power</strong>, <strong>Regen</strong>)
              to browse by category. Click any discovered potion to load both ingredients into the
              brew panel for quick re-crafting.
            </p>
          </section>

          <section className="htp-section">
            <h2 className="htp-heading">Hints</h2>
            <p className="htp-text">
              Stuck? Spend gold to buy hints. A hint reveals one ingredient involved in an
              undiscovered recipe. Hinted potions appear in your Grimoire with a <strong>star
              badge</strong>. Click them to auto-fill the known ingredient into the brew panel.
            </p>
          </section>

          <section className="htp-section">
            <h2 className="htp-heading">Tips</h2>
            <ul className="htp-list">
              <li>Recruit more heroes early &mdash; they explore in parallel and regen while idle.</li>
              <li>Apply regen potions to active explorers, power potions to deep-diving heroes.</li>
              <li>Use Brew All after each exploration haul to quickly test new combinations.</li>
              <li>Soups are not wasted &mdash; they still give +1 gold each.</li>
              <li>Hints are most valuable when you&rsquo;re down to the last few undiscovered potions.</li>
              <li>Claim loot promptly &mdash; heroes can&rsquo;t explore while carrying unclaimed rewards.</li>
            </ul>
          </section>
        </div>
      </div>

      <SettingsOverlay open={settingsOpen} onClose={() => setSettingsOpen(false)} />
    </div>
  )
}
