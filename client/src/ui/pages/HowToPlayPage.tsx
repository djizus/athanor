import { useNavigationStore } from '@/stores/navigationStore'
import { useSettingsStore } from '@/stores/settingsStore'

export function HowToPlayPage() {
  const { navigate } = useNavigationStore()
  const { tutorialEnabled, setTutorialEnabled } = useSettingsStore()

  return (
    <div className="glass-page">
      <div className="glass-page-panel">
        <div className="glass-page-header">
          <h1 className="glass-page-title">How to Play</h1>
          <button onClick={() => navigate('home')}>Back</button>
        </div>

        <div className="glass-page-body htp-body">
          <section className="htp-section">
            <p className="htp-text">
              Discover all <strong>30 potions</strong> as fast as possible. Explore zones, gather
              ingredients, brew recipes. Your time is tracked on the leaderboard.
            </p>
            {!tutorialEnabled && (
              <button
                className="home-menu-button"
                onClick={() => {
                  setTutorialEnabled(true)
                  navigate('home')
                }}
              >
                Replay In-Game Tutorial
              </button>
            )}
            {tutorialEnabled && (
              <p className="htp-text htp-tutorial-note">
                The in-game tutorial is active &mdash; it will guide you through the interface
                when you start a game.
              </p>
            )}
          </section>

          <section className="htp-section">
            <h2 className="htp-heading">Heroes &amp; Exploration</h2>
            <p className="htp-text">
              You start with one hero and can recruit up to <strong>3</strong> (Mage, Rogue, Warrior).
              Each has <strong>HP</strong>, <strong>Power</strong>, and <strong>Regen</strong>.
              Send them into <strong>5 zones</strong> to gather ingredients and gold &mdash; deeper
              zones are riskier but yield rarer materials. After an expedition, claim the loot
              to collect rewards. Heroes regenerate HP while idle.
            </p>
          </section>

          <section className="htp-section">
            <h2 className="htp-heading">Brewing &amp; Potions</h2>
            <p className="htp-text">
              Combine two ingredients to discover a potion or get <strong>Soup</strong> (+1 gold).
              Use <strong>Brew All</strong> to try every untested combination at once. Potions come
              in three categories:
            </p>
            <ul className="htp-list">
              <li><span className="htp-cat htp-cat-health">Health</span> &mdash; boosts max HP.</li>
              <li><span className="htp-cat htp-cat-power">Power</span> &mdash; increases combat and exploration rewards.</li>
              <li><span className="htp-cat htp-cat-regen">Regen</span> &mdash; speeds up HP recovery while idle.</li>
            </ul>
            <p className="htp-text">
              Apply potions to heroes from their hero card. Your <strong>Grimoire</strong> tracks
              all discoveries &mdash; click any discovered potion to re-craft it.
            </p>
          </section>

          <section className="htp-section">
            <h2 className="htp-heading">Hints</h2>
            <p className="htp-text">
              Spend gold to reveal one ingredient of an undiscovered recipe. Hinted potions
              appear in your Grimoire with a star badge &mdash; click them to auto-fill the
              known ingredient.
            </p>
          </section>

          <section className="htp-section">
            <h2 className="htp-heading">Tips</h2>
            <ul className="htp-list">
              <li>Recruit heroes early &mdash; they explore in parallel and regen while idle.</li>
              <li>Use Brew All after each haul to quickly test new combinations.</li>
              <li>Soups still give +1 gold each &mdash; nothing is wasted.</li>
              <li>Save hints for the last few undiscovered potions.</li>
              <li>Claim loot promptly &mdash; heroes can&rsquo;t explore while carrying rewards.</li>
            </ul>
          </section>
        </div>
      </div>
    </div>
  )
}
