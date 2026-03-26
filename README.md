# Athanor

**Onchain tactical RPG on Starknet.** Into the Breach meets Attack of the Astrals.

Turn-based combat on an 8x8 isometric grid. Move into enemies to bump them into telegraphed danger zones. Spend stamina on movement and abilities. Kill enemies to gain bonus stamina and energy orbs. Clear 3 rooms to win.

Built with [Dojo](https://www.dojoengine.org/) (Cairo contracts) and [Godot 4.5](https://godotengine.org/) (2D isometric pixel art client).

> **Previous versions**: [3D PoC](../../tree/3d-approach) | [Game Jam VIII](../../tree/game-jam-viii)

---

## Combat

- **8x8 isometric grid** with obstacle tiles per room
- **Bump displacement**: move into an enemy to push them 1 tile — into danger zones, walls (5 collision damage), or other enemies
- **Escalating stamina**: 80 base per turn, +10 on kill, +20 from energy orbs that drop at death locations
- **5 abilities**: Strike (melee), Dash (line move+hit), Heal (self HP restore), Shove (push 2 tiles), Slam (AOE + push all adjacent)
- **Telegraph system**: enemies show danger zones, damage resolves next turn. Turn order: PLAYER -> RESOLVE -> ENEMY
- **5 enemy types**: Brute (chase + melee), Caster (kite + AOE), Flanker (backstab), Heavy (immovable, cross telegraph), Puller (forced movement)
- **3-room progression**: escalating difficulty, HP carries between rooms
- **Confirm/Reset**: preview your whole turn, undo freely, then commit

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Contracts | Cairo 2.15 + Dojo 1.8 |
| Client | Godot 4.5.2 (GDScript, 2D isometric, HTML5 export) |
| Dojo SDK | [godot-dojo](https://github.com/dojoengine/dojo.godot) GDExtension |
| Wallet | [Cartridge Controller](https://docs.cartridge.gg/controller/overview) |
| Indexer | [Torii](https://book.dojoengine.org/toolchain/torii) |
| Deployment | [Slot](https://docs.cartridge.gg/slot/overview) |

---

## Project Structure

```
athanor/
├── contracts/src/v2/
│   ├── models/          RunState, RoomState, ActorState, AbilitySlotState, TelegraphState
│   ├── systems/         actions (main contract), movement, abilities, telegraph, enemy_ai, phase
│   ├── types/           Phase, Faction, Archetype, Ability, Direction, Shape enums
│   ├── helpers/         u64 bitmap ops for 8x8 grid
│   ├── events/          14 event types
│   ├── constants.cairo
│   └── store.cairo
├── client/
│   ├── scripts/
│   │   ├── combat/      combat_manager, combat_grid, turn_manager, grid_movement,
│   │   │                ability_manager, ability_targeting, telegraph_system,
│   │   │                bump_system, energy_orb_system, enemy_turn_resolver,
│   │   │                room_sequencer, grid_cursor, grid_utils
│   │   ├── combat/abilities/  ability_strike, ability_dash, ability_heal, ability_shove, ability_slam
│   │   ├── combat/ai/        brute_ai, caster_ai, flanker_ai, heavy_ai, puller_ai
│   │   ├── autoload/         dojo_bridge, dojo_integration, game_state
│   │   ├── resources/        health_resource, stamina_resource, combat_stats_resource, ability_resource
│   │   ├── ui/               combat_hud, game_result_screen
│   │   ├── dungeon_room.gd   Room setup, enemy spawning, combat wiring
│   │   ├── player.gd         WASD CharacterBody2D
│   │   └── main_menu.gd      Menu + Dojo connect
│   ├── scenes/          5 scenes (main_menu, dungeon_room, player, combat_hud, game_result_screen)
│   ├── assets/images/   Character sprites (6), tileset PNGs
│   └── project.godot
├── scripts/             deploy_dev.sh, deploy_slot.sh, qa_local.sh
├── dojo_dev.toml        Local dev profile (namespace: athanor_0_1)
├── dojo_slot.toml       Slot deployment profile
├── PLAN.md              Combat design document
└── .tool-versions       scarb 2.15.1, sozo 1.8.6
```

---

## Prerequisites

- [Dojo](https://book.dojoengine.org/getting-started) 1.8+ (`sozo`, `katana`, `torii`)
- [Godot 4.5+](https://godotengine.org/download/)
- [mise](https://mise.jdx.dev/) or [asdf](https://asdf-vm.com/) (reads `.tool-versions`)

```bash
mise install
sozo --version      # sozo 1.8.x
godot --version     # 4.5.x
```

---

## Running Locally

```bash
git clone git@github.com:djizus/athanor.git && cd athanor

# Build contracts
sozo build

# Terminal 1: local sequencer
katana --dev --dev.no-fee

# Terminal 2: deploy + indexer
./scripts/deploy_dev.sh --with-torii

# Terminal 3: launch game
cd client && godot
```

The game works **fully offline** without Katana/Torii. Click **Enter Dungeon** to play immediately. Onchain integration activates when you click **Connect (Burner)**.

### HTML5 Web Export

```bash
cd client
godot --headless --export-release "Web" export/web/index.html
python3 -m http.server 8090 --directory export/web
# Open http://localhost:8090
```

---

## Running on Slot

```bash
./scripts/deploy_slot.sh
cd client && godot
```

Click **Connect (Burner)** or use Cartridge Controller for wallet auth.

---

## Testing

```bash
sozo test                     # Contract tests
./scripts/qa_local.sh         # E2E: deploy + play via CLI
```

---

## Contract Actions

Namespace: `athanor_0_1`

| Action | Params | Purpose |
|--------|--------|---------|
| `spawn` | `class_id` | Create run + player (100 HP, 80 stamina) + 5 ability slots |
| `enter_room` | `game_id, room_id` | Enter room (0/1/2), spawn enemies, begin combat |
| `move_action` | `game_id, x, y` | Move on grid (10 stamina/tile). Bump enemies on collision. |
| `use_ability` | `game_id, ability_id, target_mode, a, b` | Strike/Dash/Heal/Shove/Slam |
| `end_player_phase` | `game_id` | End player turn -> Resolve -> Enemy |
| `step_enemy_phase` | `game_id` | Resolve telegraphs, enemy AI, new telegraphs, back to player |

```bash
sozo execute athanor_0_1-actions spawn 0 --wait
sozo execute athanor_0_1-actions enter_room $GID 0 --wait
sozo execute athanor_0_1-actions move_action $GID 2 1 --wait
sozo execute athanor_0_1-actions use_ability $GID 0 0 1 0 --wait
sozo execute athanor_0_1-actions end_player_phase $GID --wait
sozo execute athanor_0_1-actions step_enemy_phase $GID --wait
```

---

## Architecture

```
┌──────────────┐                        ┌───────────────┐
│ Godot Client │                        │  Cairo / Dojo │
│              │   optimistic local     │               │
│ dungeon_room │   play + submit on     │   actions     │
│ combat_mgr   │   turn confirm ──────► │   enemy_ai    │
│ dojo_bridge  │                        │   telegraph   │
│ game_state   │ ◄── Torii subscription │   movement    │
└──────────────┘    entity updates      └───────────────┘
```

Combat plays **locally first** (instant, responsive). On turn confirm, actions are batched and submitted to the chain. Torii subscriptions sync onchain state back for verification. The game is fully playable offline.

---

## License

MIT
