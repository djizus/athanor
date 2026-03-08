import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react'

type TutorialOverlayProps = {
  onComplete: () => void
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
    body: 'Let me guide you through the Athanor. You\'ll learn how to explore, brew potions, and complete your Grimoire.',
    buttonLabel: "Let's Begin",
    placement: 'bottom',
  },
  {
    target: 'status-hud',
    title: 'Dashboard',
    body: 'Your dashboard shows your <strong>gold</strong>, elapsed <strong>time</strong>, and <strong>grimoire progress</strong>. Discover all 30 potions to win!',
    buttonLabel: 'Next',
    placement: 'bottom',
  },
  {
    target: 'heroes',
    title: 'Heroes',
    body: 'Your <strong>heroes</strong> explore the depths for you. Each has HP, Power, and Regen stats. You start with one and can recruit up to 3.',
    buttonLabel: 'Next',
    placement: 'right',
  },
  {
    target: 'journey-map',
    title: 'Exploration Map',
    body: 'The <strong>exploration map</strong>. Click a zone to send a hero on an expedition. Deeper zones are more dangerous but yield rarer ingredients.',
    buttonLabel: 'Next',
    placement: 'bottom',
  },
  {
    target: 'brew',
    title: 'Brewing Station',
    body: 'The <strong>brewing station</strong>. Select two ingredients and combine them to discover potions — or get Soup (+1 gold). Use <strong>Brew All</strong> to try every untested combo at once.',
    buttonLabel: 'Next',
    placement: 'left',
  },
  {
    target: 'grimoire',
    title: 'Grimoire',
    body: 'Your <strong>Grimoire</strong> tracks all discoveries. Buy <strong>hints</strong> with gold to reveal ingredients for undiscovered potions.',
    buttonLabel: 'Next',
    placement: 'left',
  },
  {
    target: null,
    title: "You're Ready!",
    body: 'Discover all 30 potions as fast as you can. Your time is tracked on the leaderboard. Good luck!',
    buttonLabel: 'Start Playing',
    placement: 'bottom',
  },
]

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

export function TutorialOverlay({ onComplete }: TutorialOverlayProps) {
  const [step, setStep] = useState(0)
  const [rect, setRect] = useState<Rect | null>(null)
  const [visible, setVisible] = useState(false)
  const tooltipRef = useRef<HTMLDivElement>(null)
  const current = STEPS[step]

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
        setStep(s => s - 1)
      }
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  })

  const handleNext = useCallback(() => {
    if (step >= STEPS.length - 1) {
      onComplete()
    } else {
      setStep(s => s + 1)
    }
  }, [step, onComplete])

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
            {step} / {STEPS.length - 2}
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
                onClick={() => setStep(s => s - 1)}
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
