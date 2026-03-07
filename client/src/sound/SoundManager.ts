import { Howl, Howler } from 'howler'
import { getSettingsSnapshot, useSettingsStore } from '@/stores/settingsStore'

const SFX_KEYS = [
  'click', 'brew-success', 'brew-fail', 'discovery',
  'trap', 'gold-find', 'heal', 'beast-win', 'beast-lose',
  'expedition-start', 'claim-loot', 'recruit', 'potion-apply',
  'victory', 'notification', 'ambient-lab',
] as const

const MUSIC_PLAYLIST = ['menu-theme', 'game-loop-1', 'game-loop-2'] as const

const MUSIC_FILES: Record<string, string> = {
  'menu-theme': 'main_theme.mp3',
  'game-loop-1': 'game_loop_1.mp3',
  'game-loop-2': 'game_loop_2.mp3',
}

class SoundManagerImpl {
  private sfx = new Map<string, Howl>()
  private music = new Map<string, Howl>()
  private currentMusic: Howl | null = null
  private currentMusicIndex = 0
  private ambient: Howl | null = null
  private started = false

  init(): void {
    if (this.started) return
    this.started = true

    for (const key of SFX_KEYS) {
      this.sfx.set(key, new Howl({
        src: [`/assets/sounds/effects/${key}.mp3`],
        preload: true,
        volume: 0.5,
      }))
    }

    for (const [key, file] of Object.entries(MUSIC_FILES)) {
      this.music.set(key, new Howl({
        src: [`/assets/sounds/music/${file}`],
        preload: true,
        volume: 0.5,
      }))
    }

    useSettingsStore.subscribe(() => this.updateVolumes())
  }

  playSfx(key: string, volume = 0.5): void {
    const sound = this.sfx.get(key)
    if (!sound) return
    const { sfxVolume } = getSettingsSnapshot()
    sound.volume(volume * sfxVolume)
    sound.play()
  }

  startMusic(): void {
    if (this.currentMusic) return
    this.currentMusicIndex = 0
    this.playMusicTrack(0)
  }

  stopMusic(): void {
    this.currentMusic?.stop()
    this.currentMusic = null
  }

  startAmbient(): void {
    if (this.ambient) return
    const sound = this.sfx.get('ambient-lab')
    if (!sound) return
    const { sfxVolume } = getSettingsSnapshot()
    this.ambient = sound
    sound.volume(0.15 * sfxVolume)
    sound.loop(true)
    sound.play()
  }

  stopAmbient(): void {
    this.ambient?.stop()
    this.ambient = null
  }

  updateVolumes(): void {
    const { sfxVolume, musicVolume } = getSettingsSnapshot()
    if (this.currentMusic) {
      this.currentMusic.volume(musicVolume)
    }
    if (this.ambient) {
      this.ambient.volume(0.15 * sfxVolume)
    }
  }

  setGlobalMute(muted: boolean): void {
    Howler.mute(muted)
  }

  destroy(): void {
    this.stopMusic()
    this.stopAmbient()
    for (const s of this.sfx.values()) s.unload()
    for (const s of this.music.values()) s.unload()
    this.sfx.clear()
    this.music.clear()
    this.started = false
  }

  private playMusicTrack(index: number): void {
    const key = MUSIC_PLAYLIST[index]
    const howl = this.music.get(key)
    if (!howl) {
      this.playNext()
      return
    }

    this.currentMusic?.stop()
    const { musicVolume } = getSettingsSnapshot()
    howl.volume(musicVolume)
    howl.loop(false)
    howl.once('end', () => this.playNext())
    howl.play()
    this.currentMusic = howl
  }

  private playNext(): void {
    this.currentMusicIndex = (this.currentMusicIndex + 1) % MUSIC_PLAYLIST.length
    this.playMusicTrack(this.currentMusicIndex)
  }
}

export const soundManager = new SoundManagerImpl()
