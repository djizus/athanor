import { create } from 'zustand'

const STORAGE_KEY = 'athanor-settings'

type SettingsState = {
  sfxVolume: number
  musicVolume: number
  setSfxVolume: (v: number) => void
  setMusicVolume: (v: number) => void
}

function loadPersistedSettings(): { sfxVolume: number; musicVolume: number } {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (raw) {
      const parsed = JSON.parse(raw) as Record<string, unknown>
      return {
        sfxVolume: typeof parsed.sfxVolume === 'number' ? parsed.sfxVolume : 0.7,
        musicVolume: typeof parsed.musicVolume === 'number' ? parsed.musicVolume : 0.5,
      }
    }
  } catch {
    // ignore corrupt storage
  }
  return { sfxVolume: 0.7, musicVolume: 0.5 }
}

function persist(state: { sfxVolume: number; musicVolume: number }): void {
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
      persist({ sfxVolume: v, musicVolume: get().musicVolume })
    },
    setMusicVolume: (v) => {
      set({ musicVolume: v })
      persist({ sfxVolume: get().sfxVolume, musicVolume: v })
    },
  }
})

/** Plain getter for use outside React (e.g. Phaser scenes) */
export function getSettingsSnapshot(): { sfxVolume: number; musicVolume: number } {
  const { sfxVolume, musicVolume } = useSettingsStore.getState()
  return { sfxVolume, musicVolume }
}
