import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react'

type TutorialOverlayProps = {
  onComplete: () => void
  onStepChange?: (step: number, target: string | null) => void
}

type TutorialStep = {
  target: string | null
  title: string
  body: string
  buttonLabel: string
  placement: 'bottom' | 'top' | 'left' | 'right'
}

const STEPS: TutorialStep[] = [
  {
    target: null,
    title: 'Welcome, Alchemist!',
    body: 'You are standing before the <strong>Athanor</strong> — a mythical furnace of transmutation.<br/><br/>Your quest: discover all <strong>30 potions</strong> hidden within its depths. Let me show you how.',
    buttonLabel: "Let's Begin",
    placement: 'bottom',
  },
  {
    target: 'status-hud',
    title: 'The Race Against Time',
    body: 'This is your dashboard. It tracks your <strong>gold</strong>, elapsed <strong>time</strong>, and <strong>grimoire progress</strong> (potions discovered out of 30).<br/><br/>Games are <strong>ranked by completion time</strong> on the leaderboard — every second counts!',
    buttonLabel: 'Next',
    placement: 'bottom',
  },
  {
    target: 'heroes',
    title: 'Your Heroes',
    body: 'You begin with <strong>one hero</strong> and can recruit up to <strong>3</strong>. Each hero has three stats:<br/><br/><strong>HP</strong> — how much damage they can take while exploring<br/><strong>Power</strong> — increases gold earned and combat strength<br/><strong>Regen</strong> — HP recovered per second while idle<br/><br/>Press <strong>Tab</strong> to quickly cycle between your heroes.',
    buttonLabel: 'Next',
    placement: 'right',
  },
  {
    target: 'heroes',
    title: 'Recruiting & Buffing',
    body: 'Spend gold to <strong>recruit</strong> additional heroes — more heroes means parallel exploration, which is key to fast times.<br/><br/>Once you have potions, you can <strong>apply them</strong> to heroes to permanently boost their stats.',
    buttonLabel: 'Next',
    placement: 'right',
  },
  {
    target: null,
    title: 'The Exploration Map',
    body: 'Behind this panel is the map with <strong>5 zones</strong> of increasing danger. Each zone holds <strong>5 unique ingredients</strong> that can only be found there.<br/><br/>Select a hero, then click a zone to send them on an expedition. You can also press <strong>1–5</strong> to send the selected hero to a zone directly.',
    buttonLabel: 'Next',
    placement: 'bottom',
  },
  {
    target: null,
    title: 'Risk vs. Reward',
    body: 'Deeper zones cost <strong>more HP per tick</strong> but yield <strong>rarer ingredients</strong>. During exploration, heroes may encounter:<br/><br/><strong>Ingredients</strong> — gathered for brewing<br/><strong>Gold caches</strong> — collected on return<br/><strong>Beasts</strong> — win for gold, lose for HP damage<br/><strong>Traps</strong> — unavoidable HP loss<br/><strong>Healing springs</strong> — restore HP mid-expedition',
    buttonLabel: 'Next',
    placement: 'bottom',
  },
  {
    target: null,
    title: 'Claiming Loot',
    body: 'When an expedition ends, your hero returns to the Athanor carrying <strong>gold and ingredients</strong>. Click them to <strong>claim their loot</strong>.<br/><br/>Heroes <strong>cannot explore again</strong> until loot is claimed, so claim promptly!',
    buttonLabel: 'Next',
    placement: 'bottom',
  },
  {
    target: 'logs',
    title: 'Exploration Log',
    body: 'Events from your expeditions appear here in real time — gold found, beasts fought, ingredients gathered, traps sprung.<br/><br/>Keep an eye on it to track what your heroes are doing.',
    buttonLabel: 'Next',
    placement: 'right',
  },
  {
    target: 'ingredients',
    title: 'Your Ingredients',
    body: 'Ingredients are organized by the <strong>zone</strong> they come from. Each zone has 5 unique materials.<br/><br/>The progress bar at the top shows how many of all possible ingredient combinations you have tried so far.',
    buttonLabel: 'Next',
    placement: 'left',
  },
  {
    target: 'craft-slots',
    title: 'Brewing Potions',
    body: 'Click two ingredients from your inventory to load them into the <strong>brew slots</strong>, then press <strong>Brew</strong>.<br/><br/>Every unique pair produces a specific result — either a <strong>potion</strong> or a <strong>Soup</strong> (failed recipe, but you still get +1 gold).',
    buttonLabel: 'Next',
    placement: 'left',
  },
  {
    target: 'craft-slots',
    title: 'Discover All — Your Best Friend',
    body: 'The <strong>Discover All</strong> button automatically tries <strong>every untested combination</strong> in your inventory at once.<br/><br/>After each exploration haul, hit Discover All to quickly test all new ingredient pairs. You can also select one ingredient first to discover combos <strong>with that ingredient only</strong>.',
    buttonLabel: 'Next',
    placement: 'left',
  },
  {
    target: 'collection-tabs',
    title: 'Ingredients & Grimoire Tabs',
    body: 'Switch between <strong>Ingredients</strong> (your inventory) and <strong>Grimoire</strong> (your discovered potions) using these tabs.<br/><br/>Keyboard shortcuts: <strong>Tab</strong> to cycle heroes, <strong>1–5</strong> to explore zones, <strong>I</strong> for Ingredients, <strong>G</strong> for Grimoire.',
    buttonLabel: 'Next',
    placement: 'left',
  },
  {
    target: 'grimoire',
    title: 'The Grimoire',
    body: 'Your Grimoire tracks all <strong>30 potions</strong>. Discovered potions show their effect — <span style="color:#d04050"><strong>Health</strong></span> (max HP), <span style="color:#4080d0"><strong>Power</strong></span> (combat/gold), or <span style="color:#40c060"><strong>Regen</strong></span> (HP recovery).<br/><br/>Click a discovered potion to auto-load its recipe into the brew slots. <strong>Filling the entire Grimoire wins the game.</strong>',
    buttonLabel: 'Next',
    placement: 'left',
  },
  {
    target: 'hint-btn',
    title: 'Buying Hints',
    body: 'Stuck on the last few potions? Spend gold to buy a <strong>hint</strong>. It reveals one ingredient of an undiscovered recipe.<br/><br/>Hinted potions show a <strong>star badge</strong> in your Grimoire — click them to auto-fill the known ingredient. Hints cost more each time.',
    buttonLabel: 'Next',
    placement: 'left',
  },
  {
    target: null,
    title: 'Strategy Tips',
    body: '<strong>Recruit early</strong> — multiple heroes explore in parallel, saving massive time.<br/><strong>Discover All often</strong> — test combos immediately after each haul.<br/><strong>Apply potions</strong> — Regen recovers HP faster, Power earns more gold, Health survives deeper zones.<br/><strong>Claim loot fast</strong> — idle heroes waste precious seconds.<br/><strong>Save hints</strong> for the final undiscovered potions.',
    buttonLabel: 'Next',
    placement: 'bottom',
  },
  {
    target: null,
    title: "You're Ready!",
    body: 'Discover all <strong>30 potions</strong> as fast as you can. Your completion time determines your <strong>leaderboard rank</strong>.<br/><br/>The clock is ticking — good luck, Alchemist!',
    buttonLabel: 'Start Playing',
    placement: 'bottom',
  },
]

const LAST_HIGHLIGHTED_STEP = STEPS.reduce(
  (last, s, i) => (s.target !== null ? i : last), 0,
)

const SPOTLIGHT_PAD = 10

type Rect = { top: number; left: number; width: number; height: number }

function measureTarget(target: string): Rect | null {
  const el = document.querySelector(`[data-tutorial="${target}"]`)
  if (!el) return null
  const r = el.getBoundingClientRect()
  return {
    top: r.top - SPOTLIGHT_PAD,
    left: r.left - SPOTLIGHT_PAD,
    width: r.width + SPOTLIGHT_PAD * 2,
    height: r.height + SPOTLIGHT_PAD * 2,
  }
}

export function TutorialOverlay({ onComplete, onStepChange }: TutorialOverlayProps) {
  const [step, setStepRaw] = useState(0)
  const [rect, setRect] = useState<Rect | null>(null)
  const [visible, setVisible] = useState(false)
  const tooltipRef = useRef<HTMLDivElement>(null)
  const current = STEPS[step]

  const goToStep = useCallback((next: number) => {
    setStepRaw(next)
    onStepChange?.(next, STEPS[next].target)
  }, [onStepChange])

  useEffect(() => {
    const raf = requestAnimationFrame(() => setVisible(true))
    return () => cancelAnimationFrame(raf)
  }, [])

  useLayoutEffect(() => {
    if (!current.target) {
      setRect(null)
      return
    }
    const measured = measureTarget(current.target)
    setRect(measured)
  }, [step, current.target])

  useEffect(() => {
    if (!current.target) return
    const update = () => {
      const measured = measureTarget(current.target!)
      setRect(measured)
    }
    window.addEventListener('resize', update)
    window.addEventListener('scroll', update, true)
    return () => {
      window.removeEventListener('resize', update)
      window.removeEventListener('scroll', update, true)
    }
  }, [current.target])

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onComplete()
      } else if (e.key === 'Enter' || e.key === 'ArrowRight') {
        handleNext()
      } else if (e.key === 'ArrowLeft' && step > 0) {
        goToStep(step - 1)
      }
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  })

  const handleNext = useCallback(() => {
    if (step >= STEPS.length - 1) {
      onComplete()
    } else {
      goToStep(step + 1)
    }
  }, [step, onComplete, goToStep])

  const isCentered = current.target === null
  const showSpotlight = !isCentered && rect !== null

  const tooltipStyle = computeTooltipStyle(rect, current.placement, isCentered)

  return (
    <div className={`tutorial-overlay${visible ? ' tutorial-visible' : ''}`}>
      {isCentered && <div className="tutorial-backdrop" />}

      {showSpotlight && (
        <div
          className="tutorial-spotlight"
          style={{
            top: rect.top,
            left: rect.left,
            width: rect.width,
            height: rect.height,
          }}
        />
      )}

      <div
        ref={tooltipRef}
        className={`tutorial-tooltip${isCentered ? ' tutorial-tooltip-centered' : ''}`}
        style={isCentered ? undefined : tooltipStyle}
      >
        {!isCentered && (
          <span className="tutorial-step-indicator">
            {step} / {LAST_HIGHLIGHTED_STEP}
          </span>
        )}
        <h3 className="tutorial-tooltip-title">{current.title}</h3>
        <p
          className="tutorial-tooltip-body"
          dangerouslySetInnerHTML={{ __html: current.body }}
        />
        <div className="tutorial-tooltip-actions">
          <button
            className="tutorial-btn-skip"
            onClick={onComplete}
          >
            Skip Tutorial
          </button>
          <div className="tutorial-tooltip-nav">
            {step > 0 && (
              <button
                className="tutorial-btn-back"
                onClick={() => goToStep(step - 1)}
              >
                Back
              </button>
            )}
            <button
              className="tutorial-btn-next"
              onClick={handleNext}
            >
              {current.buttonLabel}
            </button>
          </div>
        </div>
        {step === STEPS.length - 1 && (
          <span className="tutorial-reactivate-note">
            You can re-enable this tutorial in Settings.
          </span>
        )}
      </div>
    </div>
  )
}

function computeTooltipStyle(
  rect: Rect | null,
  placement: TutorialStep['placement'],
  isCentered: boolean,
): React.CSSProperties {
  if (isCentered || !rect) return {}

  const gap = 16
  const style: React.CSSProperties = { position: 'fixed' }

  switch (placement) {
    case 'bottom':
      style.top = rect.top + rect.height + gap
      style.left = rect.left + rect.width / 2
      style.transform = 'translateX(-50%)'
      break
    case 'top':
      style.bottom = window.innerHeight - rect.top + gap
      style.left = rect.left + rect.width / 2
      style.transform = 'translateX(-50%)'
      break
    case 'right':
      style.top = rect.top + rect.height / 2
      style.left = rect.left + rect.width + gap
      style.transform = 'translateY(-50%)'
      break
    case 'left':
      style.top = rect.top + rect.height / 2
      style.right = window.innerWidth - rect.left + gap
      style.transform = 'translateY(-50%)'
      break
  }

  return style
}
