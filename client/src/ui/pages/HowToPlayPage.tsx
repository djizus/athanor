import { useNavigationStore } from '@/stores/navigationStore'

export function HowToPlayPage() {
  const { navigate } = useNavigationStore()

  return (
    <div className="glass-page">
      <div className="glass-page-panel">
        <div className="glass-page-header">
          <h1 className="glass-page-title">How to Play</h1>
          <button onClick={() => navigate('home')}>Back</button>
        </div>

        <div className="glass-page-body htp-body">
          <section className="htp-section">
            <h2 className="htp-heading">Goal</h2>
            <p className="htp-text">
              You are an alchemist. Your objective is to discover all <strong>30 potions</strong> by
              combining ingredients found across five mysterious zones. Send your heroes to explore,
              gather resources, brew potions, and strengthen your party.
            </p>
          </section>

          <section className="htp-section">
            <h2 className="htp-heading">Heroes</h2>
            <p className="htp-text">
              You start with one hero and can recruit up to <strong>3</strong>. Each hero has a role
              &mdash; <em>Mage</em>, <em>Rogue</em>, or <em>Warrior</em> &mdash; with different stats:
            </p>
            <ul className="htp-list">
              <li><strong>Health (HP)</strong> &mdash; determines how deep a hero can explore before needing rest.</li>
              <li><strong>Power (PWR)</strong> &mdash; increases gold earned from exploration.</li>
              <li><strong>Regen</strong> &mdash; how fast HP recovers over time.</li>
            </ul>
          </section>

          <section className="htp-section">
            <h2 className="htp-heading">Exploration</h2>
            <p className="htp-text">
              Send heroes into the depths to gather ingredients and earn gold. There are <strong>5 zones</strong>,
              each with 5 unique ingredients. Deeper zones yield rarer materials but cost more HP.
              When a hero&rsquo;s HP runs out, wait for it to regenerate before sending them again.
            </p>
          </section>

          <section className="htp-section">
            <h2 className="htp-heading">Brewing</h2>
            <p className="htp-text">
              Select two different ingredients and brew them together. Each unique pair produces a
              specific potion &mdash; or nothing at all. Discovered recipes are saved to your <strong>Grimoire</strong>.
              Use the <strong>Brew All</strong> button to try every untested combination at once.
            </p>
          </section>

          <section className="htp-section">
            <h2 className="htp-heading">Potions</h2>
            <p className="htp-text">
              Potions come in three categories:
            </p>
            <ul className="htp-list">
              <li><span className="htp-cat htp-cat-health">Health</span> &mdash; restores or boosts max HP.</li>
              <li><span className="htp-cat htp-cat-power">Power</span> &mdash; increases PWR for better exploration rewards.</li>
              <li><span className="htp-cat htp-cat-regen">Regen</span> &mdash; speeds up HP recovery.</li>
            </ul>
            <p className="htp-text">
              Apply potions to your heroes from their hero card to make them stronger.
            </p>
          </section>

          <section className="htp-section">
            <h2 className="htp-heading">Hints</h2>
            <p className="htp-text">
              Stuck? Purchase hints to reveal which ingredient participates in undiscovered recipes.
              Hinted potions appear in your Grimoire with a magnifying glass icon. Click them to
              auto-fill the known ingredient into the brew panel.
            </p>
          </section>

          <section className="htp-section">
            <h2 className="htp-heading">Grimoire</h2>
            <p className="htp-text">
              Your Grimoire tracks all discovered and hinted potions. A <strong>star badge</strong> means
              you have the ingredients to brew it again. Click any discovered potion to load both
              ingredients into the brew panel.
            </p>
          </section>

          <section className="htp-section">
            <h2 className="htp-heading">Tips</h2>
            <ul className="htp-list">
              <li>Recruit more heroes early &mdash; they explore in parallel and regen while idle.</li>
              <li>Apply potions strategically: regen potions on active explorers, power potions on deep divers.</li>
              <li>Use Brew All after each exploration haul to quickly test new combinations.</li>
              <li>Hints are most valuable when you&rsquo;re down to the last few undiscovered potions.</li>
            </ul>
          </section>
        </div>
      </div>
    </div>
  )
}
