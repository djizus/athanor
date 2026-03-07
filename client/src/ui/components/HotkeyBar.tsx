import type { PanelMode } from './RightPanel'

interface Props {
  activePanel: PanelMode | null
  onTogglePanel: (mode: PanelMode) => void
  onSettings: () => void
}

const HOTKEYS: { key: string; label: string; mode: PanelMode }[] = [
  { key: 'I', label: 'Ingredients', mode: 'ingredients' },
  { key: 'G', label: 'Grimoire', mode: 'grimoire' },
]

export function HotkeyBar({ activePanel, onTogglePanel, onSettings }: Props) {
  return (
    <div className="hotkey-bar floating-panel">
      {HOTKEYS.map(({ key, label, mode }) => (
        <button
          key={mode}
          className={`hotkey-btn${activePanel === mode ? ' active' : ''}`}
          onClick={() => onTogglePanel(mode)}
        >
          <span className="hotkey-key">{key}</span>
          {label}
        </button>
      ))}
      <button className="hotkey-btn" onClick={onSettings}>
        <span className="hotkey-key">⚙</span>
      </button>
    </div>
  )
}
