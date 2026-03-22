# Athanor v2 — PoC Implementation Plan

## Overview

Onchain tactical dungeon crawler on Starknet. Players spawn a hero, navigate a branching diamond-shaped dungeon, and fight mobs in turn-based combat. Built with Dojo (Cairo contracts) and Godot 4 (3D client, fixed isometric camera). This plan covers the PoC: contracts first, then a minimal Godot client to prove the Dojo integration.

## Goals

- Prove the core gameplay loop: spawn → navigate → fight → clear dungeon
- Validate Dojo + Godot 4 integration via `godot-dojo` SDK (gRPC streaming, session accounts)
- Establish contract architecture for turn-based tactical combat onchain
- Ship a playable PoC on Slot (Katana + Torii)

## Non-Goals

- MMO features (shared world, trading, PvP) — deferred
- Multiple hero classes or skills beyond auto-attack
- Loot, progression, leaderboard
- Mobile/web export
- Game-components (Provable Games) integration — deferred
- Polished visuals or asset pipeline

## Assumptions and Constraints

- Dojo 1.8.0, Cairo 2.15.x, Scarb workspace
- Godot 4.3+ (required by godot-dojo v0.7.4)
- `lonewolftechnology/godot-dojo` v0.7.4 for Torii gRPC + Cartridge Controller
- No VRF for PoC (no randomness needed — combat is deterministic)
- No game-components wrapper — raw Dojo system
- Repository migration (Phase 0) is already complete

---

## Requirements

### Functional

- Player spawns a hero with health=100, power=10, stamina=100
- Diamond dungeon graph: spawn → fork (2a/2b) → converge (3) → final (4)
- Turn-based combat: player casts 1-3 auto-attacks (30 stamina each), then finishes turn
- Mobs attack simultaneously on finish: `total_damage = alive_mobs × 5`
- Stamina fully resets on finish()
- No health regen between zones (attrition across dungeon)
- Auto-advance when zone has single exit; choose() only at forks
- Player dies (HP ≤ 0) → dungeon failed
- Clear zone 4 → dungeon complete

### Non-Functional

- Contracts compile and pass all tests via `sozo build && sozo test`
- Full game loop verifiable via `sozo execute` on local Katana
- Godot client connects to Torii, syncs state, sends transactions
- Turn-based latency tolerance: 1-3s per action is acceptable

---

## Technical Design

### Data Model (Dojo ECS)

```cairo
// Key: (player_address, game_id)
// game_id = per-player counter, incremented on each spawn
#[dojo::model]
struct Character {
    #[key]
    player: ContractAddress,
    #[key]
    game_id: u32,
    class_id: u8,             // 0 for PoC (single class)
    health: u16,              // Current HP, starts at 100
    max_health: u16,          // 100
    power: u16,               // 10 (damage per auto-attack)
    stamina: u16,             // Current stamina, starts at 100
    max_stamina: u16,         // 100
    current_zone: u8,         // 0-4 (zone index)
}

#[dojo::model]
struct Dungeon {
    #[key]
    player: ContractAddress,
    #[key]
    game_id: u32,
    zones_cleared: u8,        // Bitmap: bit i = zone i cleared
    completed: bool,          // All zones cleared
    failed: bool,             // Player died
}

// Fight is per-zone, created on start(), destroyed on fight end
#[dojo::model]
struct Fight {
    #[key]
    player: ContractAddress,
    #[key]
    game_id: u32,
    #[key]
    zone_id: u8,
    mob_count: u8,            // Number of mobs in this zone
    mob_healths: u64,         // Packed: 4 mobs × 16 bits each (max 65535 HP)
    mob_power: u16,           // 5 for PoC (same for all mobs)
    active: bool,             // true while fight in progress
}

// Per-player game counter (to generate game_id)
#[dojo::model]
struct PlayerState {
    #[key]
    player: ContractAddress,
    game_count: u32,          // Incremented on each spawn
}
```

### Dungeon Graph (Hardcoded)

```
Zone 0 (Spawn, 0 mobs)
  ├─ left(0)  → Zone 1 (1 mob)
  └─ right(1) → Zone 2 (1 mob)
Zone 1 → auto-advance → Zone 3 (2 mobs)
Zone 2 → auto-advance → Zone 3 (2 mobs)
Zone 3 → auto-advance → Zone 4 (4 mobs, final)
Zone 4 → dungeon complete
```

```cairo
// Constants
const ZONE_COUNT: u8 = 5;
const MOB_HEALTH: u16 = 20;
const MOB_POWER: u16 = 5;
const AA_COST: u16 = 30;

// Zone mob counts: [0, 1, 1, 2, 4]
fn zone_mob_count(zone_id: u8) -> u8 {
    match zone_id {
        0 => 0, 1 => 1, 2 => 1, 3 => 2, 4 => 4, _ => 0
    }
}

// Graph edges: zone_id → (left, right), 0xFF = no child
fn zone_children(zone_id: u8) -> (u8, u8) {
    match zone_id {
        0 => (1, 2),           // Fork: player chooses
        1 => (3, 0xFF),        // Single exit: auto-advance
        2 => (3, 0xFF),        // Single exit: auto-advance
        3 => (4, 0xFF),        // Single exit: auto-advance
        _ => (0xFF, 0xFF),     // Terminal
    }
}

fn is_fork(zone_id: u8) -> bool {
    let (left, right) = zone_children(zone_id);
    left != right && left != 0xFF && right != 0xFF
}
```

### Action State Machine

```
[SPAWNED]                    ← spawn(class_id)
    │
    ▼
[IN_ZONE: zone=0]           Player is in spawn zone (no combat)
    │
    │ choose(direction)      Only at forks (zone 0)
    ▼
[IN_ZONE: zone=1|2]         Entered zone with mobs
    │
    │ start()                Creates Fight entity
    ▼
[IN_FIGHT]                   Fight is active
    │
    │ cast(mob_id, AA)       Repeatable (1-3 times per turn)
    │ ...
    │ finish()               Mobs attack, stamina resets
    │   ├─ mobs remain → back to [IN_FIGHT]
    │   ├─ all mobs dead → zone cleared
    │   │   ├─ single exit → auto-advance to next [IN_ZONE]
    │   │   ├─ fork → wait for choose()
    │   │   └─ zone 4 → [DUNGEON_COMPLETE]
    │   └─ player HP ≤ 0 → [DUNGEON_FAILED]
    ▼
[DUNGEON_COMPLETE | DUNGEON_FAILED]
```

### Action Validation Rules

| Action | Preconditions | Effects |
|--------|---------------|---------|
| `spawn(class_id)` | — | Create PlayerState (if first), increment game_count, create Character + Dungeon, place in zone 0 |
| `choose(direction)` | Zone is fork, zone combat resolved (or no mobs), dungeon not completed/failed | Move to child zone. If child has 0 mobs and single exit, auto-advance recursively. |
| `start()` | In zone with mobs, no active fight, zone not cleared | Create Fight with packed mob HPs |
| `cast(mob_id, skill_id)` | Fight active, mob alive, stamina ≥ AA_COST, dungeon not failed | Spend stamina, deal power damage to mob. If mob HP ≤ 0, mark dead. |
| `finish()` | Fight active, dungeon not failed | All alive mobs attack simultaneously. Stamina resets to max. If all mobs dead: end fight, mark zone cleared, auto-advance if single exit. If player HP ≤ 0: mark dungeon failed. |

### Events

| Event | Fields | Emitted When |
|-------|--------|-------------|
| `CharacterSpawned` | player, game_id, class_id, health, power, stamina | spawn() |
| `DungeonCreated` | player, game_id | spawn() |
| `ZoneEntered` | player, game_id, zone_id | choose() or auto-advance |
| `FightStarted` | player, game_id, zone_id, mob_count | start() |
| `MobDamaged` | player, game_id, zone_id, mob_id, damage, remaining_hp | cast() |
| `MobDied` | player, game_id, zone_id, mob_id | cast() when mob HP → 0 |
| `PlayerDamaged` | player, game_id, damage, remaining_hp | finish() |
| `TurnEnded` | player, game_id, zone_id, turn_number | finish() |
| `FightEnded` | player, game_id, zone_id | finish() when all mobs dead |
| `DungeonCompleted` | player, game_id | finish() when zone 4 cleared |
| `DungeonFailed` | player, game_id | finish() when player HP ≤ 0 |

### Mob HP Packing

```cairo
// Pack up to 4 mob HPs into u64 (16 bits each)
// mob 0 = bits 0-15, mob 1 = bits 16-31, mob 2 = bits 32-47, mob 3 = bits 48-63
fn pack_mob_healths(healths: Span<u16>) -> u64 { ... }
fn get_mob_health(packed: u64, mob_id: u8) -> u16 { ... }
fn set_mob_health(packed: u64, mob_id: u8, hp: u16) -> u64 { ... }
fn count_alive_mobs(packed: u64, mob_count: u8) -> u8 { ... }
```

### Client Architecture (Godot)

```
client/
├── addons/godot-dojo/            # SDK (download from releases)
├── scenes/
│   ├── main.tscn                 # Entry: ToriiClient + DojoSessionAccount + scene switcher
│   ├── connection.tscn           # Auth screen (connect wallet)
│   ├── dungeon.tscn              # 3D dungeon view (zones, player, camera)
│   └── combat_ui.tscn            # CanvasLayer: mob HP bars, action buttons, stamina bar, player HP
├── scripts/
│   ├── autoload/
│   │   ├── game_state.gd         # Singleton: current Character/Dungeon/Fight state
│   │   └── dojo_bridge.gd        # Singleton: ToriiClient wrapper, entity subscriptions, tx helpers
│   ├── connection.gd             # Auth flow (Controller session)
│   ├── dungeon_view.gd           # 3D zone rendering, player movement, zone highlights
│   ├── combat_ui.gd              # Combat HUD logic
│   └── camera_rig.gd             # Fixed isometric camera
├── resources/
│   └── (placeholder materials/meshes)
└── project.godot
```

**Torii sync flow:**
1. On connect: subscribe to `Character`, `Dungeon`, `Fight` entities where `player = my_address`
2. On entity update callback → `dojo_bridge.gd` parses Dictionary → updates `game_state.gd` singleton
3. `game_state.gd` emits signals (`character_updated`, `fight_updated`, `dungeon_updated`)
4. Scene scripts connect to signals and update visuals

---

## Implementation Plan

All phases are **serial** — contracts first, client second.

### Phase 1: Contract Foundation

**Prerequisite for:** All subsequent phases

| Task | Description | Output | Verify |
|------|-------------|--------|--------|
| 1.1 | Initialize Scarb workspace: `Scarb.toml` (workspace), `contracts/Scarb.toml` (package with dojo deps), `dojo_dev.toml` | `sozo build` runs (even if empty lib.cairo) |
| 1.2 | Define `contracts/src/lib.cairo` module tree: models, types, systems, events, helpers, store, constants | `sozo build` compiles |
| 1.3 | Define types: enums for `Direction` (Left/Right), `ClassType` (Warrior for PoC), `SkillType` (AutoAttack) | Types compile |
| 1.4 | Define constants: `ZONE_COUNT`, `MOB_HEALTH`, `MOB_POWER`, `AA_COST`, `MAX_HEALTH`, `MAX_STAMINA`, `POWER`, zone_mob_count(), zone_children(), is_fork() | Constants compile |
| 1.5 | Define models: `Character`, `Dungeon`, `Fight`, `PlayerState` with keys and fields per Technical Design | Models compile |
| 1.6 | Implement packing helpers: `pack_mob_healths`, `get_mob_health`, `set_mob_health`, `count_alive_mobs` | Helpers compile |
| 1.7 | Define all 11 events per Technical Design | Events compile |
| 1.8 | Implement Store: typed read/write for all models, event emit helpers | Store compiles |

### Phase 2: Contract Actions

**Dependencies:** Phase 1

| Task | Description | Output | Verify |
|------|-------------|--------|--------|
| 2.1 | Implement `spawn(class_id)` — create/increment PlayerState, create Character (100/10/100), create Dungeon, emit CharacterSpawned + DungeonCreated | `sozo build` passes |
| 2.2 | Implement `choose(direction)` — validate fork, validate combat resolved, move to child zone, emit ZoneEntered | `sozo build` passes |
| 2.3 | Implement `start()` — validate in zone with mobs + no active fight + zone not cleared, create Fight with packed mob HPs, emit FightStarted | `sozo build` passes |
| 2.4 | Implement `cast(mob_id, skill_id)` — validate fight active + mob alive + stamina ≥ AA_COST, deal damage, update packed HPs, emit MobDamaged (+ MobDied if HP=0) | `sozo build` passes |
| 2.5 | Implement `finish()` — calculate total mob damage, apply to player, reset stamina. If player dead: set dungeon.failed, emit DungeonFailed. If all mobs dead: end fight, mark zone cleared. If single exit: auto-advance (emit ZoneEntered). If zone 4: set dungeon.completed, emit DungeonCompleted. Emit TurnEnded + FightEnded + PlayerDamaged as appropriate. | `sozo build` passes |

### Phase 3: Contract Tests & Local Deployment

**Dependencies:** Phase 2

| Task | Description | Output | Verify |
|------|-------------|--------|--------|
| 3.1 | Write unit tests: spawn creates correct state, choose validates fork, start creates fight with right mob count, cast deals damage + spends stamina + reverts on dead mob, finish applies mob damage + resets stamina + handles zone clear + auto-advance + dungeon completion + player death | `sozo test` all pass |
| 3.2 | Write integration test: full dungeon run — spawn → choose(0) → start → cast×2 → finish → (auto-advance to zone 3) → start → cast×4 → finish×2 → (auto-advance to zone 4) → start → cast×8 → finish×3 → DungeonCompleted | `sozo test` passes |
| 3.3 | Write failure test: player gets killed in zone 4 (e.g., finish without killing mobs for several turns) → DungeonFailed | `sozo test` passes |
| 3.4 | Deploy to local Katana: `katana --dev` + `sozo migrate --dev` | Clean deployment |
| 3.5 | Manual E2E via sozo execute: run through full dungeon, verify events in Torii | All events appear correctly |

### Phase 4: Godot Client — Foundation

**Dependencies:** Phase 3 (contracts deployed to Katana)

| Task | Description | Output | Verify |
|------|-------------|--------|--------|
| 4.1 | Initialize Godot 4 project: `project.godot` in `client/`, window 1280×720, input actions (click, hotkeys) | `godot --headless --quit` no errors |
| 4.2 | Install godot-dojo v0.7.4: download release, place in `client/addons/godot-dojo/` | Plugin visible in editor |
| 4.3 | Create `main.tscn`: ToriiClient + DojoSessionAccount nodes, scene switcher script | Scene loads without errors |
| 4.4 | Create `connection.tscn` + `connection.gd`: Controller auth flow (generate key, open session URL, create session) | Wallet connects to local Katana |
| 4.5 | Create `dojo_bridge.gd` autoload: ToriiClient wrapper, entity subscriptions for Character/Dungeon/Fight, tx calldata helpers for all 5 actions | Autoload registers, connects to Torii |
| 4.6 | Create `game_state.gd` autoload: parsed entity state, signals (character_updated, dungeon_updated, fight_updated) | Autoload registers, signals defined |

### Phase 5: Godot Client — Game Scenes

**Dependencies:** Phase 4

| Task | Description | Output | Verify |
|------|-------------|--------|--------|
| 5.1 | Create `dungeon.tscn`: 3D scene with 5 zone platforms in diamond layout (MeshInstance3D boxes), path lines between zones, fixed isometric Camera3D | Scene renders dungeon layout |
| 5.2 | Create `dungeon_view.gd`: player capsule mesh on current zone, zone highlight on cleared/active/locked states, player movement tween on zone change | Player visually moves between zones |
| 5.3 | Create `combat_ui.tscn` + `combat_ui.gd`: CanvasLayer with mob HP bars (ProgressBar), Attack button, End Turn button, stamina bar, player HP bar | UI renders over 3D scene |
| 5.4 | Wire `dojo_bridge.gd` signals to `dungeon_view.gd` and `combat_ui.gd`: entity updates → visual state changes | Health bars update on Fight entity changes |
| 5.5 | Wire UI buttons to `dojo_bridge.gd` tx helpers: Spawn button → spawn(), zone click → choose(), Attack → cast(), End Turn → finish() | Buttons execute transactions |
| 5.6 | Add dungeon completion/failure overlay: simple Label + "Play Again" button on DungeonCompleted / DungeonFailed | End state displayed |

### Phase 6: Integration & Deployment

**Dependencies:** Phase 5

| Task | Description | Output | Verify |
|------|-------------|--------|--------|
| 6.1 | Full playtest on local Katana: spawn → choose → fight through all zones → complete dungeon | Game plays from start to finish |
| 6.2 | Test failure path: intentionally lose (finish without attacking) → DungeonFailed overlay | Death handled correctly |
| 6.3 | Deploy contracts to Slot: `sozo migrate --profile slot` | Clean deployment on Slot |
| 6.4 | Start Torii on Slot, point client to Slot RPC + Torii | Client connects to Slot |
| 6.5 | Smoke test on Slot: full dungeon run with Cartridge Controller | PoC validated on Slot |

---

## Testing and Validation

### Contract Tests (sozo test)
- spawn: creates Character with correct stats, Dungeon with zones_cleared=0, increments PlayerState.game_count
- spawn: second call creates game_id=2, doesn't interfere with game_id=1
- choose(0) at zone 0: moves to zone 1, emits ZoneEntered
- choose(1) at zone 0: moves to zone 2, emits ZoneEntered
- choose at non-fork zone: reverts
- choose before clearing zone combat: reverts
- start at zone with mobs: creates Fight with correct mob_count and packed HPs
- start at zone 0 (no mobs): reverts
- start when fight already active: reverts
- cast(0, AA): deals 10 damage, spends 30 stamina, emits MobDamaged
- cast when mob dead: reverts
- cast when insufficient stamina: reverts
- cast when no active fight: reverts
- finish: mobs deal simultaneous damage, stamina resets to 100, emits PlayerDamaged + TurnEnded
- finish when all mobs dead: ends fight, marks zone cleared, auto-advances if single exit
- finish when player HP ≤ 0: marks dungeon failed, emits DungeonFailed
- finish when zone 4 cleared: marks dungeon complete, emits DungeonCompleted
- full run: spawn → choose(0) → start → [cast×2 → finish] → auto-advance → start → [cast + finish]×2 → auto-advance → start → [cast + finish]×3 → DungeonCompleted

### Client Tests
- `godot --headless --quit`: no parse errors
- ToriiClient connects to local Torii instance
- Entity subscription fires on sozo execute spawn
- UI buttons trigger correct transaction calldata

---

## Verification Checklist

```bash
# Phase 1-2: Contracts compile
sozo build

# Phase 3: Tests pass
sozo test

# Phase 3: Deploy locally
katana --dev &
sozo migrate --dev

# Phase 3: Start Torii
torii --world <WORLD_ADDRESS> --rpc http://localhost:5050 &

# Phase 3: Manual E2E (example sozo execute calls)
sozo execute <actions_address> spawn -c 0
sozo execute <actions_address> choose -c 0
sozo execute <actions_address> start
sozo execute <actions_address> cast -c 0,0
sozo execute <actions_address> cast -c 0,0
sozo execute <actions_address> finish

# Phase 4-5: Client compiles
cd client && godot --headless --quit

# Phase 6: Full playtest
# Manual: open Godot, connect wallet, play through dungeon
```

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| godot-dojo SDK Dictionary API is brittle for complex models | High | Medium | Build typed wrapper early (Phase 4.5). Keep model fields simple (no nested structs). |
| Packed mob HP bit manipulation bugs in Cairo | Medium | High | Write exhaustive packing unit tests (Phase 3.1). Use 16-bit per mob for headroom. |
| Auto-advance logic creates unexpected state transitions | Medium | Medium | Explicit state machine in contract. Test each transition path. |
| Torii doesn't index compound-key models correctly | Low | High | Test entity subscription with compound keys in Phase 4.5. Fallback: use felt252 hash key. |
| Godot 4.3 + godot-dojo crash on entity callback | Medium | Medium | Test early in Phase 4.4. SDK is stable on 4.3 per docs. |
| Combat is too easy (25 HP total damage for full clear) | Low | Low | PoC validates the loop. Tune numbers (mob HP, mob power, mob count) later. |

---

## Decision Log

| Decision | Rationale | Alternatives Considered |
|----------|-----------|------------------------|
| Stamina full reset on finish() | Simpler for PoC. 3 attacks per turn is consistent. Future skills with different costs will create resource pressure naturally. | Partial regen (+50) — adds tactical depth but complicates PoC |
| No health regen between zones | Attrition is the primary difficulty mechanic. Efficient play in early zones matters for zone 4. | Partial heal (+20) — too forgiving for 4-zone dungeon |
| Multi-cast before finish | Matches bal7hazar's design. Player dumps 1-3 actions then mobs respond. Natural turn rhythm. | Strict 1 action per finish — too slow, more tx overhead |
| Simultaneous mob attack | Sum damage, one HP check. Simplest implementation. Which mob "killed" the player doesn't matter for PoC. | Sequential — more events but same outcome |
| Player address + game counter keys | Multiple dungeons per player (history). game_count in PlayerState is cheap. | Player address only (1 active) — blocks replay. Auto-increment global ID — no player scoping. |
| Auto-advance on single exit | Reduces unnecessary choose() calls (Zone 1→3, 2→3, 3→4). choose() only at actual forks (Zone 0). | Always require choose() — 4 extra transactions per run for no tactical value |
| Skip game-components for PoC | No NFT minting overhead, simpler contract surface. Add structured settings/lifecycle in v2.1. | Include — proven in v1 but adds pre_action/post_action complexity |
| Contracts first, then client | Client needs real Torii data to test against. No mock layer to maintain. | Parallel — faster but higher integration risk with untested SDK |
| 16-bit mob HP packing (u64) | 4 mobs × 16 bits = 64 bits. Fits in u64 cleanly. Headroom for mobs with >255 HP in future. | 8-bit (u32) — caps at 255 HP per mob. felt252 — overkill for 4 mobs. |

---

# Cartridge In-Client Authentication (No External Browser) Implementation Plan

## Overview

Replace the current `OS.shell_open(session_url)` browser-based Controller authorization with an in-client authentication flow in Godot 4.6. The primary target is a pure in-game onboarding path using controller.c capabilities exposed by the existing godot-dojo GDExtension (`DojoController`), while keeping a fallback path for compatibility.

## Goals

- Eliminate the external browser popup from the default player authentication flow.
- Validate whether `DojoController` exposes headless account/session APIs needed for fully in-client auth.
- Keep compatibility with existing transaction flow (`DojoSessionAccount.execute`) and policy model.
- Define a funding/paymaster path so newly created headless accounts can transact immediately.

## Non-Goals

- Rewriting gameplay state sync, Torii subscriptions, or combat flow.
- Building a full social/passkey identity migration UX in this iteration.
- Guaranteeing Cartridge identity continuity if the selected mode is headless account creation.

## Assumptions and Constraints

- Godot client uses `godot-dojo` v0.7.4 GDExtension with `DojoSessionAccount`, `ControllerHelper`, and `DojoController` classes.
- Current auth flow in `client/scripts/autoload/dojo_bridge.gd` uses `create_from_subscribe` + external browser URL approval.
- Game currently targets Slot/Katana URLs; production target may include Sepolia and possibly mainnet.
- Player preference questions were asked and are currently unresolved; plan includes decision gates for both outcomes.

## Requirements

### Functional

- In-client auth flow must not call `OS.shell_open()` in the primary path.
- Auth flow must produce a usable account/session for executing `spawn`, `choose`, `start`, `cast`, `finish`.
- Session/account metadata must still be persisted in `user://controller_session.json` (extended schema allowed).
- Existing resume flow must continue to work after app restart.

### Non-Functional

- First-time auth UX should complete in <10 seconds on healthy network.
- Clear on-screen status/error states for: creating account, funding check, signup, session ready, retry.
- Safe fallback if headless flow unsupported on a platform build.

## Technical Design

### Approach Analysis (Three Options)

| Approach | Browser Needed | Keeps Existing Cartridge Account | Complexity | Recommended Use |
|---|---:|---:|---:|---|
| 1. Headless `ControllerAccount::new_headless` via `DojoController` | No | No (new account model) | Medium | **Recommended default** for “no popup ever” UX |
| 2. `create_from_subscribe` (current) | Yes (first time) | Yes | Low | Keep as fallback/legacy mode |
| 3. `SessionAccount::init/create` with externally obtained session data | No | Depends on source | High (needs external broker/QR/backend) | Phase-2 optional enhancement |

### Recommendation

Implement a **dual-mode architecture** with **Headless-first** and **Subscribe fallback**:

1. **Primary:** Headless in-client account creation via `DojoController` (Approach 1) to fully remove browser popup.
2. **Fallback:** Existing `create_from_subscribe` path kept behind a feature flag for platforms/builds where headless APIs are unavailable.
3. **Future Optional:** External session-broker path (Approach 3) if product later requires existing Cartridge identity continuity without browser.

### Architecture

```text
Connection UI
  -> dojo_bridge.start_auth(mode)
      -> HeadlessAuthProvider (new)
          -> DojoController (introspected API)
          -> create/load owner key
          -> create controller account
          -> signup if needed
          -> build session/account object for tx execution
      -> SessionCacheStore (extended metadata)
      -> dojo_bridge.current_player + session_ready signal

Fallback path:
  -> Existing ControllerHelper + DojoSessionAccount.create_from_subscribe
```

### UX Flow (No Browser)

1. Player taps **Connect**.
2. UI shows: “Creating secure local account…”
3. If no account exists: generate/store owner keypair and (optional) prompt username.
4. UI shows: “Registering account on Starknet…”
5. If funding required: show “Funding required / Sponsoring transaction…” with retry.
6. On success: “Connected” and transition to dungeon.

---

## Implementation Plan

### Serial Dependencies (Must Complete First)

#### Phase 0: API Discovery and Decision Gate
**Prerequisite for:** All implementation workstreams

| Task | Description | Output |
|------|-------------|--------|
| 0.1 | Introspect `DojoController` methods in runtime using `ClassDB.class_get_method_list("DojoController")` (debug script/tool scene) and document signatures/return shapes | `docs/controller-dojocontroller-api.md` with callable method map |
| 0.2 | Confirm whether methods cover headless lifecycle (owner init/new_headless/signup/execute/get_address/info) and whether they map to `controller.c` capabilities | Feasibility verdict: Headless Supported / Partial / Unsupported |
| 0.3 | Resolve product decision gate from user prefs: headless-only vs existing Cartridge continuity, network scope (Sepolia/mainnet), account style (guest vs username) | Decision record added to PLAN Decision Log |

---

### Parallel Workstreams

#### Workstream A: Auth Domain Refactor in `dojo_bridge.gd`
**Dependencies:** Phase 0
**Can parallelize with:** Workstreams B, C

| Task | Description | Output |
|------|-------------|--------|
| A.1 | Introduce `auth_mode` enum/config (`headless`, `subscribe_fallback`) and `start_auth()` orchestrator | Browser-independent auth entrypoint |
| A.2 | Implement `_auth_headless_start()` path using `DojoController` methods discovered in 0.1; remove direct `OS.shell_open()` from primary path | In-client auth implementation |
| A.3 | Keep `_auth_subscribe_start()` as fallback behind feature flag; default off in production | Backward-compatible fallback |
| A.4 | Extend cache schema to include headless account metadata (`auth_mode`, `username`, `owner_key_version`, optional `controller_address`) and migrate old cache safely | Versioned session/account cache |

#### Workstream B: Connection UX and Error Recovery
**Dependencies:** Phase 0
**Can parallelize with:** Workstreams A, C

| Task | Description | Output |
|------|-------------|--------|
| B.1 | Replace browser-oriented labels in `connection.gd` with in-client auth states/progress | Updated status machine and copy |
| B.2 | Add explicit transient states: `creating_account`, `registering`, `funding_check`, `ready`, `failed_retryable` | Better UX and diagnosability |
| B.3 | Add optional username capture UI (if chosen by decision gate) and guest autogeneration fallback | Player onboarding UI branch |

#### Workstream C: Funding + Paymaster Integration
**Dependencies:** Phase 0
**Can parallelize with:** Workstreams A, B

| Task | Description | Output |
|------|-------------|--------|
| C.1 | Define account activation strategy for headless signup tx (self-funded vs sponsored) per environment (local, Slot Sepolia, mainnet) | `docs/headless-funding-matrix.md` |
| C.2 | Integrate Slot paymaster configuration (if available) for signup + gameplay tx sponsorship; add runtime checks and clear errors when unavailable | Paymaster-aware tx submission flow |
| C.3 | Add preflight “can transact” check before entering gameplay | Prevents post-connect transaction failures |

---

### Merge Phase

#### Phase 4: Integration, Compatibility, and Cleanup
**Dependencies:** Workstreams A, B, C

| Task | Description | Output |
|------|-------------|--------|
| 4.1 | Integrate all auth/funding states and ensure `session_ready` signal semantics stay stable for scene switcher | End-to-end connect flow |
| 4.2 | Remove legacy focus-return auth completion hooks (`focus_entered` browser return coupling) when headless mode is active | Cleaner auth lifecycle |
| 4.3 | Add telemetry/logging tags for auth steps and failures (`[auth][headless]`, `[auth][funding]`) | Faster issue triage |

---

## Testing and Validation

- Unit-style script tests for cache migration and auth mode switching.
- Manual E2E scenarios:
  - Fresh install, no cache -> connect -> spawn -> cast/finish txs succeed.
  - Restart app -> resume session/account without re-auth.
  - Simulate funding/paymaster unavailable -> user gets actionable retry/error.
  - Fallback mode enabled -> existing browser flow still works.
- Network matrix:
  - Local Katana (dev)
  - Slot Sepolia deployment
  - (Optional) Mainnet dry-run config validation

## Rollout and Migration

- Stage 1: Ship behind `auth_mode=headless` feature flag defaulting to fallback on unknown platforms.
- Stage 2: Enable headless by default on validated platforms (Linux/macOS/Windows).
- Stage 3: Decide whether to remove subscribe flow entirely or keep as identity-continuity option.
- Rollback: flip config to `subscribe_fallback` without reverting gameplay code.

## Verification Checklist

```bash
# 1) Godot script parse check
cd client && godot --headless --quit

# 2) Auth smoke (manual in editor/runtime)
# - Connect shows no external browser launch
# - Account/session becomes valid
# - session cache file updated

# 3) Transaction smoke
# - spawn/start/cast/finish succeed from connected account

# 4) Resume smoke
# - Restart client; auth resumes without popup
```

Success criteria:
- No `OS.shell_open(...)` invocation on default auth path.
- Player reaches connected state and can submit transactions.
- Resume path works with new cache schema.

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| `DojoController` lacks required headless bindings in v0.7.4 | Medium | High | Phase 0 hard-gate; retain subscribe fallback |
| Headless signup requires funds and blocks onboarding | High | High | Slot paymaster sponsorship + preflight funding checks |
| Cross-platform extension behavior differs (desktop/mobile/web) | Medium | Medium | Enable per-platform rollout flags |
| Loss of existing Cartridge identity continuity | Medium | Medium | Keep fallback mode and communicate account model clearly |

## Open Questions

- [ ] Product choice: headless-first (new accounts) vs identity continuity with existing Cartridge accounts.
- [ ] Network scope at launch: Sepolia-only or Sepolia+mainnet.
- [ ] Onboarding preference: guest auto-generated only or username/recovery UX at connect.

## Decision Log (Auth Track)

| Decision | Rationale | Alternatives Considered |
|----------|-----------|------------------------|
| Use headless as primary path when supported | Only approach that guarantees no external browser popup | Keep `create_from_subscribe` only (fails UX requirement) |
| Preserve browser-based subscribe as fallback initially | Limits rollout risk while validating DojoController coverage | Hard cutover immediately |
| Add explicit funding/paymaster workstream | Headless accounts fail without activation/gas strategy | Defer funding concerns to later (creates broken first-run UX) |
