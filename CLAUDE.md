# CLAUDE.md — Athanor Project Guide

## What is this project?

Athanor is a tactical RPG (Into the Breach-style) built with Godot 4.5.2 (2D isometric pixel art client) and Dojo (Cairo smart contracts on Starknet). Combat plays locally (optimistic), then turn actions are submitted onchain.

## Repository Layout

```
contracts/src/        Cairo contracts (namespace: athanor_0_1)
client/               Godot 4.5.2 project (480x270, 4x upscale to 1080p)
scripts/              Deploy + QA shell scripts
PLAN.md               Combat design document (source of truth for game design)
```

## Key Architecture

- **Offline-first**: Game works 100% without Dojo. Chain is additive.
- **Optimistic play**: Combat resolves locally. On turn confirm, actions batch-submit to chain.
- **Turn order**: PLAYER -> RESOLVE -> ENEMY (bumps pay off immediately)
- **Stamina**: 80 base, +10 kill bonus, +20 energy orb pickup, reset to 80 each turn

## Build & Validate Commands

```bash
# Contracts
sozo build                    # Build Cairo contracts
sozo test                     # Run contract tests

# Client (Godot)
cd client && timeout 60 godot --headless --quit 2>&1    # Parse check all scripts
cd client && godot --headless --export-release "Web" export/web/index.html  # HTML5 export

# Serve for browser testing
python3 -m http.server 8090 --directory client/export/web

# Deploy to Slot
./scripts/deploy.sh           # Build, migrate, update client addresses
```

## Game Design (from PLAN.md)

### 5 Abilities
| # | Name | Cost | CD | Effect |
|---|------|------|----|--------|
| 0 | Strike | 20 | 0 | 15 dmg adjacent |
| 1 | Dash | 25 | 1 | Line move + 10 dmg |
| 2 | Heal | 25 | 3 | Restore 20 HP |
| 3 | Shove | 20 | 1 | Push 2 tiles + 5 dmg + collision |
| 4 | Slam | 35 | 2 | 10 dmg all adjacent + push 1 tile |

### 5 Enemy Types
| Type | HP | Behavior | Telegraph |
|------|----|----------|-----------|
| Brute | 50 | Chase + melee | Single tile on player |
| Caster | 30 | Kite + AOE | Circle on player |
| Flanker | 40 | Flank behind | Single tile behind player |
| Heavy | 70 | Slow chase, **immovable** | Cross (+) on player, 25 dmg |
| Puller | 35 | Maintain distance | 3x3 PULL zone (forced movement) |

### 3 Rooms (all 8x8 grid)
- Room 0: 2 Brute + 1 Caster (easy)
- Room 1: 1 Brute + 1 Flanker + 1 Heavy (medium)
- Room 2: 1 Heavy + 1 Puller + 2 Flanker (hard)

### Bump Displacement
Move into enemy-occupied tile -> push enemy 1 tile in movement direction.
- Open tile: enemy displaced, player takes old position
- Blocked/wall/out-of-bounds: enemy stays, takes 5 collision damage
- Immovable enemy: player stops short, enemy takes 5 damage

## QA Pipeline (HTML5 + Playwright)

The preferred testing approach uses Godot's HTML5 export + Playwright MCP:

```bash
# Export
cd client && godot --headless --export-release "Web" export/web/index.html

# Serve
python3 -m http.server 8090 --directory export/web &

# Playwright MCP commands
playwright_browser_navigate -> http://localhost:8090
playwright_browser_wait_for -> time: 12  (let Godot/WebGL init)
playwright_browser_take_screenshot
```

### Canvas coordinate mapping
Game viewport is 480x270 stretched to canvas. To click game coordinate (gx, gy):
```javascript
const canvas = document.querySelector('canvas');
const rect = canvas.getBoundingClientRect();
const scaleX = rect.width / 480;
const scaleY = rect.height / 270;
const x = rect.left + gx * scaleX;
const y = rect.top + gy * scaleY;
canvas.dispatchEvent(new MouseEvent('mousedown', {clientX: x, clientY: y, button: 0, bubbles: true}));
canvas.dispatchEvent(new MouseEvent('mouseup', {clientX: x, clientY: y, button: 0, bubbles: true}));
```

### Play-testing via Playwright
Actually interact with the game: click tiles for movement, press 1-5 for abilities, Enter to confirm turns, R to reset. Take screenshots at each step to verify visual state.

## Skills to Use

### Godot Development
- **godot-task**: Scene/script generation, HTML5 export, Playwright QA, visual verification
- **playwright** (MCP): Browser interaction for HTML5-exported game testing

### Dojo / Contracts
- **dojo-model**: Create/modify Cairo models
- **dojo-system**: Create/modify Cairo system contracts
- **dojo-config**: Scarb.toml, dojo profiles, namespace config
- **dojo-test**: Write Cairo tests
- **dojo-review**: Audit contracts for issues
- **dojo-deploy**: Deploy to Katana/Slot
- **dojo-client**: Wire Godot client to Dojo
- **dojo-init**, **dojo-migrate**, **dojo-world**, **dojo-indexer**, **dojo-token**

### Cartridge / Infrastructure
- **controller-setup**, **controller-react**, **controller-sessions**, **controller-signers**, **controller-backend**, **controller-native**, **controller-presets**
- **slot-deploy**, **slot-rpc**, **slot-teams**, **slot-paymaster**, **slot-scale**, **slot-vrng**
- **create-pr**: PR workflow
- **create-a-plan**: Structured planning interviews

## Contract Namespace & Naming

Following zkube pattern: version in namespace, not in contract names.

- **Namespace**: `athanor_0_1`
- **Contract**: `actions` (not `actions_v2`)
- **Functions**: `spawn`, `enter_room`, `confirm_turn`
- **Models**: `RunState`, `RoomState`, `ActorState`, `AbilitySlotState`, `TelegraphState`

### Batched Turn Architecture

Player plays full turn locally (optimistic), then submits all actions in one `confirm_turn(game_id, actions: Span<felt252>)` transaction. The contract processes all player actions sequentially, then auto-runs enemy phase (telegraph resolve, enemy AI, new telegraphs, turn flip).

**Action encoding** (packed felt252 array):
| Action | Type ID | Fields | Felts |
|--------|---------|--------|-------|
| Move | 0 | target_x, target_y | 3 |
| Ability | 1 | ability_id, target_mode, target_a, target_b | 5 |

```bash
# CLI examples
sozo execute athanor_0_1-actions confirm_turn $GID 3 0 2 1 --wait              # Move to (2,1)
sozo execute athanor_0_1-actions confirm_turn $GID 8 0 2 1 1 0 0 1 0 --wait    # Move + Strike actor 1
```

## Dojo Integration (Client Side)

| File | Purpose |
|------|---------|
| `dojo_bridge.gd` | Autoload. ToriiClient, DojoSessionAccount, burner mode, Controller auth, sozo CLI fallback |
| `dojo_integration.gd` | Autoload. Records moves/abilities, batch-submits on confirm turn |
| `game_state.gd` | Autoload. Model containers (run, room, actors dict), Torii subscription updates |

### Slot Endpoints
- Torii: `https://api.cartridge.gg/x/athanor-djizus-slot/torii`
- Katana: `https://api.cartridge.gg/x/athanor-djizus-slot/katana`
- World/actions addresses: set after `sozo migrate`

## Known Quirks

- `.gd` files have no LSP in this environment. Use `godot --headless --quit` as parse check.
- `move` is a Cairo keyword — avoid as function names in contracts.
- GDScript typed arrays (`Array[Vector2i]`) reject untyped literals in tests — create typed locals first.
- godot-dojo GDExtension binaries are not in git — user installs from dojo.godot releases into `client/addons/godot-dojo/bin/`.
- Godot export templates installed at `~/.local/share/godot/export_templates/4.5.2.stable/`.
- Web export uses `variant/thread_support=false` for broadest browser compatibility.
