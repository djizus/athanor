# Athanor

**Onchain tactical dungeon crawler on Starknet.**

Turn-based combat on an 8×8 isometric grid where stamina pays for both movement and abilities. Enemies follow simple deterministic rules — you can predict what they'll do, but you can't avoid everything. The tension between dodging telegraphed attacks and spending stamina on offense IS the game.

Built with [Dojo](https://www.dojoengine.org/) (Cairo contracts) and [Godot 4.6](https://godotengine.org/) (2D isometric client on [Godot-GameTemplate](https://github.com/nezvers/Godot-GameTemplate)).

> **Previous versions**: [3D PoC](../../tree/3d-approach) • [Game Jam VIII](../../tree/game-jam-viii)

---

## Combat

- **8×8 grid** with ~20 obstacle tiles creating cover and choke points
- **Stamina** (100) is the universal currency — movement costs 10/tile, abilities cost 15-30
- **5 abilities**: Strike (melee), Dash (line move+hit), Cleave (cone AOE), Fireball (radius AOE), Guard (damage reduction)
- **Telegraph system**: enemy attacks show danger zones on turn N, damage resolves on turn N+1 — you get one full turn to reposition
- **Deterministic enemy AI**: Melee Brute moves toward you, Ranged Caster keeps distance. All computed onchain. No randomness.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Contracts | Cairo 2.15 + Dojo 1.8 |
| Client | Godot 4.6 (GDScript, 2D isometric) |
| Dojo SDK | [godot-dojo](https://github.com/lonewolftechnology/godot-dojo) v0.7.4 |
| Wallet | [Cartridge Controller](https://docs.cartridge.gg/controller/overview) |
| Indexer | [Torii](https://book.dojoengine.org/toolchain/torii) |
| Deployment | [Slot](https://docs.cartridge.gg/slot/overview) |

---

## Project Structure

```
athanor/
├── contracts/src/
│   ├── v2/
│   │   ├── models/          RunState, RoomState, ActorState, AbilitySlotState, TelegraphState
│   │   ├── events/          14 events (ActorMoved, TelegraphCreated, RoomCleared, etc.)
│   │   ├── types/           Phase, Faction, Archetype, Ability, Direction, Shape enums
│   │   ├── helpers/         u64 bitmap ops for 8×8 grid
│   │   ├── systems/         actions_v2 + movement, abilities, telegraph, enemy_ai, phase
│   │   ├── constants.cairo
│   │   └── store.cairo
│   ├── lib.cairo
│   └── tests.cairo          16 tests
├── client/
│   ├── addons/
│   │   ├── great_games_library/   Template core (ValueResource, ResourceNode)
│   │   └── top_down/              Template game systems (MoverTopDown2D, ArenaStarter, etc.)
│   ├── scripts/
│   │   ├── autoload/        dojo_bridge.gd, game_state.gd, audio_manager.gd
│   │   ├── combat/          combat_manager, movement_constraint, telegraph_system,
│   │   │                    enemy_visual, aoe_preview, debug_overlay
│   │   ├── resources/       stamina_resource, combat_stats_resource, ability_resource
│   │   ├── ui/              combat_hud
│   │   ├── game_entry.gd    Main menu + auth + game flow
│   │   ├── game_room.gd     Combat scene (builds 8×8 grid programmatically)
│   │   └── auth_browser.gd  CEF embedded / external browser auth
│   └── project.godot
├── docs/                    Domain spec, ABI spec, enemy rules, art spec
├── scripts/                 deploy_dev.sh, deploy_slot.sh, qa_local.sh
├── Scarb.toml
├── dojo_v2.toml             Local dev profile
├── dojo_slot.toml           Slot deployment profile
├── setup.sh                 Installs godot-dojo + godot-cef addons
├── .tool-versions           scarb 2.15.1, sozo 1.8.6
└── PLAN.md
```

---

## Prerequisites

- [Dojo](https://book.dojoengine.org/getting-started) 1.8.0+ (`sozo`, `katana`, `torii`)
- [Godot 4.6+](https://godotengine.org/download/)
- [mise](https://mise.jdx.dev/) or [asdf](https://asdf-vm.com/) (reads `.tool-versions` for exact versions)

```bash
mise install        # pins scarb 2.15.1, sozo 1.8.6
sozo --version      # sozo 1.8.x
godot --version     # 4.6.x
```

---

## Running Locally

```bash
git clone git@github.com:djizus/athanor.git
cd athanor && git checkout v2

./setup.sh          # downloads godot-dojo + godot-cef addons

# Terminal 1: local sequencer
katana --dev --dev.no-fee --dev.no-account-validation

# Terminal 2: deploy + start indexer
./scripts/deploy_dev.sh --with-torii

# Terminal 3: launch game
cd client && godot
```

Local dev auto-detects `localhost` and uses a Katana burner account — no wallet setup needed. Click **Enter Dungeon** to start.

---

## Running on Slot

```bash
./scripts/deploy_slot.sh
cd client && godot
```

Click **Connect Wallet** → Cartridge Controller auth (passkey or social login) → **Enter Dungeon**.

---

## Testing

```bash
sozo test                     # 16 contract tests (spawn, move, abilities, telegraphs, AI, phases)
./scripts/qa_local.sh        # E2E: deploy to katana + play full combat loop via sozo CLI
./scripts/qa_local.sh --keep # keep stack running for manual inspection
```

---

## Contract Actions

| Action | Params | Purpose |
|--------|--------|---------|
| `spawn_v2` | `class_id` | Create run + player actor + 5 ability slots |
| `enter_room_v2` | `game_id, room_id` | Enter room, spawn enemies, begin PlayerTurn |
| `move_v2` | `game_id, x, y` | Move on grid (costs stamina = Manhattan distance × 10) |
| `use_ability_v2` | `game_id, ability_id, target_mode, a, b` | Cast ability (Strike/Dash/Cleave/Fireball/Guard) |
| `end_player_phase_v2` | `game_id` | End player turn → EnemyTurn |
| `step_enemy_phase_v2` | `game_id` | Resolve telegraphs → enemy AI → new telegraphs → PlayerTurn |

CLI example:
```bash
sozo execute athanor_v2-actions_v2 spawn_v2 0 -P v2 --wait
sozo execute athanor_v2-actions_v2 enter_room_v2 0 0 -P v2 --wait
sozo execute athanor_v2-actions_v2 move_v2 0 2 1 -P v2 --wait
sozo execute athanor_v2-actions_v2 use_ability_v2 0 0 0 1 0 -P v2 --wait  # Strike enemy 1
sozo execute athanor_v2-actions_v2 end_player_phase_v2 0 -P v2 --wait
sozo execute athanor_v2-actions_v2 step_enemy_phase_v2 0 -P v2 --wait
```

---

## Architecture

```
┌─────────────┐     sozo execute      ┌──────────────┐
│ Godot Client │ ──────────────────── │  Cairo/Dojo   │
│              │     (burner CLI       │  Contracts    │
│  game_entry  │      or Controller    │              │
│  game_room   │      session)         │  actions_v2   │
│  combat_*    │                       │  enemy_ai     │
│  dojo_bridge │ ◄──── Torii gRPC ──── │  telegraph    │
│  game_state  │     entity updates    │  movement     │
└─────────────┘                       └──────────────┘
```

All game state lives onchain. The client is a pure renderer + input handler. Entity updates stream from Torii to `game_state.gd` which emits signals. Visual systems react to signals.

---

## License

MIT
