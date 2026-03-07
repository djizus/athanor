import { useState } from 'react'
import { useSettingsStore } from '@/stores/settingsStore'

type SettingsOverlayProps = {
  open: boolean
  onClose: () => void
  onSurrender?: () => void
}

export function SettingsOverlay({ open, onClose, onSurrender }: SettingsOverlayProps) {
  const { sfxVolume, musicVolume, setSfxVolume, setMusicVolume } = useSettingsStore()
  const [confirmSurrender, setConfirmSurrender] = useState(false)

  if (!open) return null

  return (
    <>
      <div className="settings-overlay-backdrop" onClick={onClose} />
      <div className="settings-overlay panel">
        <h2 className="settings-overlay-title">Settings</h2>

        <div className="settings-section">
          <h3 className="settings-section-label">Sound</h3>
          <div className="settings-slider-row">
            <span className="settings-slider-label">Effects</span>
            <input
              type="range"
              className="settings-slider"
              min={0}
              max={1}
              step={0.05}
              value={sfxVolume}
              onChange={(e) => setSfxVolume(Number(e.target.value))}
            />
            <span className="settings-slider-value">{Math.round(sfxVolume * 100)}%</span>
          </div>
          <div className="settings-slider-row">
            <span className="settings-slider-label">Music</span>
            <input
              type="range"
              className="settings-slider"
              min={0}
              max={1}
              step={0.05}
              value={musicVolume}
              onChange={(e) => setMusicVolume(Number(e.target.value))}
            />
            <span className="settings-slider-value">{Math.round(musicVolume * 100)}%</span>
          </div>
        </div>

        {onSurrender && (
          <div className="settings-section">
            {!confirmSurrender ? (
              <button className="btn-danger" onClick={() => setConfirmSurrender(true)}>
                Surrender
              </button>
            ) : (
              <div className="settings-confirm-row">
                <span className="settings-confirm-text">Abandon this run?</span>
                <button className="btn-danger" onClick={() => { onSurrender(); setConfirmSurrender(false) }}>
                  Yes, surrender
                </button>
                <button className="home-menu-button" onClick={() => setConfirmSurrender(false)}>
                  Cancel
                </button>
              </div>
            )}
          </div>
        )}

        <button className="home-menu-button settings-close-btn" onClick={onClose}>
          Close
        </button>
      </div>
    </>
  )
}
