import { useEffect, useRef, useState } from 'react'

export function useAnimatedNumber(target: number, duration = 600): [number, boolean] {
  const [display, setDisplay] = useState(target)
  const displayRef = useRef(target)
  const rafRef = useRef(0)
  const initialRef = useRef(true)

  useEffect(() => {
    if (initialRef.current) {
      initialRef.current = false
      displayRef.current = target
      setDisplay(target)
      return
    }

    const from = displayRef.current
    if (from === target) return

    if (rafRef.current) cancelAnimationFrame(rafRef.current)

    const start = performance.now()
    const animate = (now: number) => {
      const elapsed = now - start
      const progress = Math.min(elapsed / duration, 1)
      const eased = 1 - Math.pow(1 - progress, 3)
      const value = Math.round(from + (target - from) * eased)
      displayRef.current = value
      setDisplay(value)
      if (progress < 1) {
        rafRef.current = requestAnimationFrame(animate)
      }
    }
    rafRef.current = requestAnimationFrame(animate)
    return () => {
      if (rafRef.current) cancelAnimationFrame(rafRef.current)
    }
  }, [target, duration])

  return [display, display !== target]
}
