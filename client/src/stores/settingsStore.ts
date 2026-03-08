import { create } from 'zustand'

const STORAGE_KEY = 'athanor-settings'

type SettingsState = {
  sfxVolume: number
  musicVolume: number
  tutorialEnabled: boolean
  setSfxVolume: (v: number) => void
  setMusicVolume: (v: number) => void
  setTutorialEnabled: (v: boolean) => void
}

type PersistedSettings = { sfxVolume: number; musicVolume: number; tutorialEnabled: boolean }

function loadPersistedSettings(): PersistedSettings {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (raw) {
      const parsed = JSON.parse(raw) as Record<string, unknown>
      return {
        sfxVolume: typeof parsed.sfxVolume === 'number' ? parsed.sfxVolume : 0.3,
        musicVolume: typeof parsed.musicVolume === 'number' ? parsed.musicVolume : 0.3,
        tutorialEnabled: typeof parsed.tutorialEnabled === 'boolean' ? parsed.tutorialEnabled : true,
      }
    }
  } catch {
    // ignore corrupt storage
  }
  return { sfxVolume: 0.3, musicVolume: 0.3, tutorialEnabled: true }
}

function persist(state: PersistedSettings): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state))
  } catch {
    // storage full / unavailable
  }
}

export const useSettingsStore = create<SettingsState>((set, get) => {
  const initial = loadPersistedSettings()

  return {
    ...initial,
    setSfxVolume: (v) => {
      set({ sfxVolume: v })
      const s = get()
      persist({ sfxVolume: v, musicVolume: s.musicVolume, tutorialEnabled: s.tutorialEnabled })
    },
    setMusicVolume: (v) => {
      set({ musicVolume: v })
      const s = get()
      persist({ sfxVolume: s.sfxVolume, musicVolume: v, tutorialEnabled: s.tutorialEnabled })
    },
    setTutorialEnabled: (v) => {
      set({ tutorialEnabled: v })
      const s = get()
      persist({ sfxVolume: s.sfxVolume, musicVolume: s.musicVolume, tutorialEnabled: v })
    },
  }
})

/** Plain getter for use outside React (e.g. Phaser scenes) */
export function getSettingsSnapshot(): { sfxVolume: number; musicVolume: number; tutorialEnabled: boolean } {
  const { sfxVolume, musicVolume, tutorialEnabled } = useSettingsStore.getState()
  return { sfxVolume, musicVolume, tutorialEnabled }
}
