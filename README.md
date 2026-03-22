# Athanor

**Onchain tactical dungeon crawler on Starknet.**

Athanor is a turn-based tactical RPG where players spawn a hero, navigate a branching dungeon graph, and fight mobs in onchain combat. Built with [Dojo](https://www.dojoengine.org/) (Cairo contracts) and [Godot 4](https://godotengine.org/) (3D client with fixed isometric camera).

Named after the *athanor*, the self-feeding philosophical furnace of medieval alchemy. The dungeon is the furnace; clearing it is the Great Work.

> **Previous version**: The grimoire-race idle game from Game Jam VIII is preserved on the [`game-jam-viii`](../../tree/game-jam-viii) branch and tag.

---

## Game Design (PoC)

### Core Loop

```
Spawn Hero --> Navigate Dungeon --> Fight Mobs --> Clear Zones --> Complete Dungeon
```

### Dungeon Graph (Diamond / Branching)

```
        [Zone 0: Spawn]
           /        \
    [Zone 1]    [Zone 2]      <-- 1 mob each
           \        /
        [Zone 3]                <-- 2 mobs
           |
        [Zone 4]                <-- 4 mobs (final)
```

Players choose their path at forks via `choose(direction)`. Zones with a single exit auto-advance after clearing combat.

### Combat (Turn-Based)

Each turn:
1. **Player phase**: Cast 1-3 auto-attacks (30 stamina each, 100 stamina total)
2. **Call `finish()`**: All surviving mobs attack simultaneously, stamina resets to max

Combat ends when all mobs in the zone are dead (zone cleared) or player HP hits 0 (dungeon failed).

### Stats

| | Player | Mob |
|---|--------|-----|
| Health | 100 | 20 |
| Power | 10 | 5 |
| Stamina | 100 | -- |
| Auto-Attack Cost | 30 | -- |

- **No health regen** between zones (attrition is the difficulty)
- **Stamina fully resets** on `finish()`
- Mobs attack simultaneously: `total_damage = alive_mobs * 5`

### Contract Actions

| Action | Params | Purpose |
|--------|--------|---------|
| `spawn(class_id)` | `u8` | Create character + dungeon, place in zone 0 |
| `choose(game_id, direction)` | `u32, Direction` | Navigate to next zone at a fork |
| `start(game_id)` | `u32` | Begin combat in current zone |
| `cast(game_id, mob_id, skill_id)` | `u32, u8, u8` | Attack a mob (skill 0 = auto-attack) |
| `finish(game_id)` | `u32` | End turn, resolve mob attacks |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Contracts | [Cairo](https://www.cairo-lang.org/) 2.15 + [Dojo](https://www.dojoengine.org/) 1.8 |
| Client | [Godot 4.6+](https://godotengine.org/) (GDScript, 3D isometric) |
| Dojo SDK | [godot-dojo](https://github.com/lonewolftechnology/godot-dojo) v0.7.4 (gRPC streaming) |
| Wallet | [Cartridge Controller](https://docs.cartridge.gg/controller/overview) (session keys, passkey auth, in-game CEF browser) |
| Embedded Browser | [godot-cef](https://github.com/dsh0416/godot-cef) v1.13.0 (in-client auth, no external browser popup) |
| Indexer | [Torii](https://book.dojoengine.org/toolchain/torii) (real-time entity sync) |
| Deployment | [Slot](https://docs.cartridge.gg/slot/overview) / Sepolia |

---

## Project Structure

```
athanor/
+-- contracts/                        # Cairo smart contracts (Dojo ECS)
|   +-- src/
|   |   +-- constants.cairo           # Zone graph, mob/player stats, skill costs
|   |   +-- store.cairo               # Typed read/write for all models + event emitters
|   |   +-- models/
|   |   |   +-- character.cairo       # Character model (health, power, stamina, zone)
|   |   |   +-- dungeon.cairo         # Dungeon model (zones_cleared bitmap, completed/failed)
|   |   |   +-- fight.cairo           # Fight model (packed mob HPs, mob_power, active)
|   |   |   +-- player_state.cairo    # Per-player game counter
|   |   +-- types/
|   |   |   +-- direction.cairo       # Direction enum (Left, Right)
|   |   |   +-- class.cairo           # ClassType enum (Warrior for PoC)
|   |   |   +-- skill.cairo           # SkillType enum (AutoAttack)
|   |   +-- events/
|   |   |   +-- index.cairo           # 11 events (CharacterSpawned, MobDamaged, etc.)
|   |   +-- helpers/
|   |   |   +-- packing.cairo         # Mob HP bit-packing in u64 (16 bits per mob)
|   |   +-- systems/
|   |   |   +-- actions.cairo         # Main system: spawn, choose, start, cast, finish
|   |   +-- tests.cairo               # 19 tests (unit + integration)
|   +-- Scarb.toml
+-- client/                           # Godot 4 project
|   +-- addons/godot-dojo/            # Dojo SDK (binary, gitignored except metadata)
|   +-- scenes/
|   |   +-- main.tscn                 # Entry point: ToriiClient, DojoSessionAccount, scene switcher
|   |   +-- connection.tscn           # Auth screen (Connect wallet button)
|   |   +-- auth_browser.tscn         # Embedded CEF browser overlay for in-game auth
|   |   +-- dungeon.tscn             # 3D dungeon view (5 zones, player, isometric camera)
|   |   +-- combat_ui.tscn           # CanvasLayer: HP bars, Attack/End Turn buttons, stamina
|   +-- scripts/
|   |   +-- autoload/
|   |   |   +-- game_state.gd        # Singleton: parsed entity state, signals
|   |   |   +-- dojo_bridge.gd       # Singleton: Torii subscriptions, tx calldata, auth signals
|   |   +-- main.gd                  # Scene switcher, SDK node bootstrapping
|   |   +-- connection.gd            # Controller auth flow (embedded + external browser)
|   |   +-- auth_browser.gd          # CefTexture wrapper: URL monitoring, auth completion detection
|   |   +-- dungeon_view.gd          # Zone rendering, player movement, state colors
|   |   +-- combat_ui.gd             # Combat HUD logic
|   +-- project.godot
+-- Scarb.toml                        # Workspace root
+-- dojo_dev.toml                     # Local Katana deployment config
+-- setup.sh                          # Downloads gitignored addons (godot-cef, godot-dojo)
+-- PLAN.md                           # Detailed implementation plan
+-- .gitignore
```

---

## Prerequisites

- [Dojo](https://book.dojoengine.org/getting-started) 1.8.0+ (installs `sozo`, `katana`, `torii`)
- [Godot 4.6+](https://godotengine.org/download/) (editor for GUI, or headless for CI)
- [Scarb](https://docs.swmansion.com/scarb/) 2.15+ (Cairo package manager, included with Dojo)

Verify installation:

```bash
sozo --version     # sozo 1.8.x
katana --version   # katana 1.8.x
torii --version    # torii 1.8.x
scarb --version    # scarb 2.15.x
godot --version    # 4.6.x
```

---

## Running Locally (Contracts Only)

If you just want to test the onchain logic without the Godot client.

### 1. Clone and build

```bash
git clone git@github.com:djizus/athanor.git
cd athanor

# Build contracts
sozo build
```

### 2. Run tests

```bash
sozo test
```

Expected output: `test result: ok. 19 passed; 0 failed; 0 ignored; 0 filtered out;`

### 3. Deploy to local Katana

Open **Terminal 1** -- start the local sequencer:

```bash
katana --dev --dev.no-fee
```

Open **Terminal 2** -- deploy contracts:

```bash
sozo migrate
```

You'll see: `Migration successful with world at address 0x06e71...` (address varies).

### 4. Play through the dungeon via CLI

After deploying, you can play the entire game from the command line:

```bash
# 1. Spawn a hero (class_id=0 = Warrior)
sozo execute athanor-actions spawn 0

# 2. Choose a path at the fork (0=Left to Zone 1, 1=Right to Zone 2)
sozo execute athanor-actions choose 1 0

# 3. Start combat in Zone 1 (1 mob, 20 HP)
sozo execute athanor-actions start 1

# 4. Attack the mob twice (mob_id=0, skill_id=0=AutoAttack)
#    Each auto-attack costs 30 stamina and deals 10 damage
#    2 hits = 20 damage = mob dead
sozo execute athanor-actions cast 1 0 0
sozo execute athanor-actions cast 1 0 0

# 5. End turn -- mob is dead, zone clears, auto-advance to Zone 3
sozo execute athanor-actions finish 1

# 6. Zone 3 has 2 mobs -- start combat
sozo execute athanor-actions start 1

# 7. Turn 1: kill mob 0, wound mob 1
sozo execute athanor-actions cast 1 0 0    # mob 0: 20 -> 10
sozo execute athanor-actions cast 1 0 0    # mob 0: 10 -> 0 (dead)
sozo execute athanor-actions cast 1 1 0    # mob 1: 20 -> 10
sozo execute athanor-actions finish 1       # mob 1 attacks: 5 dmg. stamina resets.

# 8. Turn 2: kill mob 1
sozo execute athanor-actions cast 1 1 0    # mob 1: 10 -> 0 (dead)
sozo execute athanor-actions finish 1       # zone cleared, auto-advance to Zone 4

# 9. Zone 4 has 4 mobs -- start combat
sozo execute athanor-actions start 1

# 10. Turn 1: kill mob 0, wound mob 1
sozo execute athanor-actions cast 1 0 0
sozo execute athanor-actions cast 1 0 0
sozo execute athanor-actions cast 1 1 0
sozo execute athanor-actions finish 1       # 3 mobs attack: 15 dmg

# 11. Turn 2: kill mob 1, kill mob 2
sozo execute athanor-actions cast 1 1 0
sozo execute athanor-actions cast 1 2 0
sozo execute athanor-actions cast 1 2 0
sozo execute athanor-actions finish 1       # 1 mob attacks: 5 dmg

# 12. Turn 3: kill mob 3
sozo execute athanor-actions cast 1 3 0
sozo execute athanor-actions cast 1 3 0
sozo execute athanor-actions finish 1       # ALL MOBS DEAD -- DUNGEON COMPLETE!
```

Every `sozo execute` returns a transaction hash. If any action fails, it will show the revert reason (e.g., `'Not enough stamina'`, `'Mob already dead'`, `'Not at a fork'`).

### 5. Start Torii (optional, for querying state)

Open **Terminal 3**:

```bash
# Replace with your world address from step 3
torii --world 0x06e7172f23b20e73fa5dcbdf059133c73b53dfda89ec5447b3fd54f19eba30b5 \
      --rpc http://localhost:5050
```

Torii provides:
- **GraphQL** at `http://localhost:8080/graphql`
- **gRPC** at `http://localhost:8080` (used by the Godot client)

---

## Running Locally (Full Stack with Godot)

### 1. Install addons

```bash
./setup.sh
```

Downloads both gitignored addons:
- **godot-dojo** v0.7.4 — Dojo SDK (GDExtension)
- **godot-cef** v1.13.0 — Embedded Chromium browser (all platforms)

### 2. Start the backend (3 terminals)

**Terminal 1 -- Katana** (local sequencer):

```bash
katana --dev --dev.no-fee
```

**Terminal 2 -- Deploy contracts**:

```bash
sozo build && sozo migrate
```

Note the world address printed at the end.

**Terminal 3 -- Torii** (indexer):

```bash
torii --world <WORLD_ADDRESS> --rpc http://localhost:5050
```

### 3. Open the Godot project

**Terminal 4**:

```bash
cd client
godot --editor
```

This opens the Godot 4 editor. The project has:

- **Main scene** (`scenes/main.tscn`): Entry point with ToriiClient and DojoSessionAccount nodes
- **Connection scene** (`scenes/connection.tscn`): Wallet connect screen
- **Dungeon scene** (`scenes/dungeon.tscn`): 3D diamond dungeon with 5 zone platforms
- **Combat UI** (`scenes/combat_ui.tscn`): Overlay with HP bars, Attack/End Turn buttons

### 4. Configure connection (if needed)

The default configuration in `scripts/autoload/dojo_bridge.gd` points to:
- **RPC**: `http://localhost:5050` (Katana)
- **Torii**: `http://localhost:8080` (Torii gRPC)

These match the default local development ports. No changes needed for local testing.

### 5. Run the game

Press **F5** in the Godot editor (or click the Play button). The game flow:

1. **Connection screen** -- click Connect to authenticate via Cartridge Controller (opens in-game browser on desktop, external browser on mobile)
2. **Spawn** -- click Spawn to create your hero and dungeon
3. **Dungeon view** -- 3D diamond layout with 5 zone platforms
4. **Navigate** -- click a zone to choose your path at forks
5. **Combat** -- click Start to begin fighting, then use Attack/End Turn buttons
6. **Win/Lose** -- overlay appears when dungeon is completed or you die

### Headless validation (CI)

```bash
cd client && timeout 60 godot --headless --quit 2>&1
```

This validates all GDScript files parse correctly without needing a display.

---

## Architecture

### Onchain State (Dojo ECS)

| Model | Key | Fields |
|-------|-----|--------|
| `Character` | `(player, game_id)` | class_id, health, max_health, power, stamina, max_stamina, current_zone |
| `Dungeon` | `(player, game_id)` | zones_cleared (bitmap), completed, failed |
| `Fight` | `(player, game_id, zone_id)` | mob_count, mob_healths (packed u64), mob_power, active |
| `PlayerState` | `(player)` | game_count (auto-increment) |

### Mob HP Packing

Up to 4 mob HPs are packed into a single `u64` (16 bits per mob):

```
mob 0 = bits 0-15, mob 1 = bits 16-31, mob 2 = bits 32-47, mob 3 = bits 48-63
```

### Events (Indexed by Torii)

| Event | Emitted By | Key Fields |
|-------|-----------|------------|
| `CharacterSpawned` | spawn | player, game_id, class_id, health, power, stamina |
| `DungeonCreated` | spawn | player, game_id |
| `ZoneEntered` | choose/auto-advance | player, game_id, zone_id |
| `FightStarted` | start | player, game_id, zone_id, mob_count |
| `MobDamaged` | cast | player, game_id, zone_id, mob_id, damage, remaining_hp |
| `MobDied` | cast | player, game_id, zone_id, mob_id |
| `PlayerDamaged` | finish | player, game_id, damage, remaining_hp |
| `TurnEnded` | finish | player, game_id, zone_id |
| `FightEnded` | finish | player, game_id, zone_id |
| `DungeonCompleted` | finish | player, game_id |
| `DungeonFailed` | finish | player, game_id |

### Action State Machine

```
[SPAWNED]                    <-- spawn(class_id)
    |
    v
[IN_ZONE: zone=0]           Spawn zone (no combat)
    |
    | choose(direction)      Only at forks (zone 0)
    v
[IN_ZONE: zone=1|2]         Zone with mobs
    |
    | start()                Creates Fight entity
    v
[IN_FIGHT]                   Fight is active
    |
    | cast(mob_id, AA)       1-3 times per turn
    | finish()               Mobs attack, stamina resets
    |   |-- mobs remain --> back to [IN_FIGHT]
    |   |-- all dead + single exit --> auto-advance to next zone
    |   |-- all dead + fork --> wait for choose()
    |   |-- all dead + zone 4 --> [DUNGEON_COMPLETE]
    |   +-- player HP=0 --> [DUNGEON_FAILED]
```

### Client Architecture (Godot)

```
project.godot
  |-- Autoloads:
  |     GameState (game_state.gd)   <-- parsed entity state + signals
  |     DojoBridge (dojo_bridge.gd) <-- ToriiClient wrapper, tx helpers
  |
  |-- Main scene
  |     ToriiClient node        <-- gRPC connection to Torii
  |     DojoSessionAccount node <-- Cartridge Controller session
  |     SceneSwitcher           <-- swaps between Connection and Dungeon
  |
  |-- Connection scene          <-- wallet auth flow (state machine)
  |     +-- AuthBrowser         <-- embedded CEF browser for in-game passkey/social login
  |
  |-- Dungeon scene             <-- 3D diamond layout, player mesh, camera
  |     +-- CombatUI (CanvasLayer) <-- HP bars, buttons, stamina
```

**Data flow:**
1. `ToriiClient` subscribes to entity updates via gRPC streaming
2. Callbacks fire in `DojoBridge` -> parses Dictionary -> updates `GameState`
3. `GameState` emits signals (`character_updated`, `fight_updated`, etc.)
4. Scene scripts (`dungeon_view.gd`, `combat_ui.gd`) react to signals and update visuals
5. UI buttons call `DojoBridge` tx helpers -> encode calldata -> execute via `DojoSessionAccount`

---

## Testing

### Contract Tests

```bash
sozo test
```

19 tests covering:
- spawn (initial state, game counter, multiple games)
- choose (left/right/non-fork revert)
- start (creates fight, no-mobs revert, already-active revert, already-cleared revert)
- cast (damage, stamina, dead-mob revert, no-stamina revert, no-fight revert)
- finish (mob damage, stamina reset, zone clear, auto-advance, player death, no-fight revert)
- Full integration: complete dungeon run via left path
- Full integration: complete dungeon run via right path

### Client Validation

```bash
cd client && timeout 60 godot --headless --quit 2>&1
```

Must exit cleanly with no errors.

---

## AI Tooling (for contributors using AI agents)

### Godot MCP server

We use [godot-mcp](https://github.com/Coding-Solo/godot-mcp) for direct Godot editor integration (scene management, node manipulation, project inspection) instead of static skill files. Add it to your `~/.config/opencode/opencode.json`:

```json
{
  "mcp": {
    "godot": {
      "type": "local",
      "command": ["npx", "@coding-solo/godot-mcp"]
    }
  }
}
```

### Dojo & Controller skills

```bash
# Dojo skills (12 skills -- models, systems, deploy, testing, etc.)
npx skills add dojoengine/book -y

# Controller + Slot skills (15 skills -- wallet, sessions, deploy, paymaster, etc.)
npx skills add cartridge-gg/docs -y
```

---

## Roadmap

- [x] **PoC**: Core loop (spawn, navigate, fight, clear) -- contracts + client
- [ ] **v2.1**: Multiple hero classes, skill trees
- [ ] **v2.2**: Procedural dungeon generation
- [ ] **v2.3**: Async MMO (shared world, trading, PvP)
- [ ] **v2.4**: Loot, progression, leaderboard

See [`PLAN.md`](PLAN.md) for the detailed implementation plan.

---

## License

MIT
