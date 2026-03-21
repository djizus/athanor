# Athanor v2 — Tactical Dungeon Crawler

## Overview

Athanor pivots from a grimoire-race idle game to an **onchain tactical dungeon crawler**. Players spawn a hero, navigate a branching diamond-shaped dungeon graph, and fight mobs in turn-based combat. Built with Dojo (Cairo contracts) and Godot 4 (3D client with fixed isometric camera). Solo dungeons for PoC — async MMO features (shared world, trading, PvP) come later.

The alchemy fantasy theme carries forward: the dungeon is the Athanor furnace, zones are alchemical chambers, and the hero descends deeper into the Great Work.

## Goals

- Prove the core gameplay loop: spawn → navigate → fight → clear dungeon
- Validate Dojo + Godot 4 integration via `godot-dojo` SDK (gRPC streaming, session accounts)
- Establish contract architecture for turn-based tactical combat onchain
- Ship a playable PoC on Slot (Katana + Torii)

## Non-Goals

- MMO features (multiplayer interaction, shared world, trading, PvP) — deferred to v2.1+
- Multiple hero classes — PoC uses 1 class only
- Skills beyond auto-attack — skill tree comes later
- Loot/progression system — PoC just proves the combat loop
- Leaderboard / competitive ranking
- Mobile/web export (desktop-first for PoC)
- AI asset generation pipeline (use placeholder assets, integrate godogen later)

## Assumptions and Constraints

- Dojo 1.8.0, Cairo 2.15.x, Scarb workspace
- Godot 4.3+ (required by godot-dojo v0.7.4)
- `lonewolftechnology/godot-dojo` v0.7.4 for Torii gRPC + Cartridge Controller integration
- Cartridge Controller for wallet (session keys, passkey auth)
- Torii for indexing (gRPC streaming subscriptions, not polling)
- No typed GDScript bindings from Dojo — raw Dictionary API; plan a wrapper layer
- Game-components (Provable Games) integration optional for PoC — can add later
- VRF optional for PoC — can use pseudo-random fallback (vrf_address = zero)

---

## Game Design (PoC)

### Player Stats

| Stat | Value | Notes |
|------|-------|-------|
| Health | 100 | Regens partially after clearing a zone |
| Power | 10 | Damage dealt per auto-attack |
| Stamina | 100 | Spent on actions, regens on `finish()` |
| Auto-Attack Cost | 30 stamina | Only skill in PoC |

### Dungeon Graph (Diamond / Branching)

```
        [Zone 1: Spawn]
           /        \
    [Zone 2a]    [Zone 2b]      ← 1 mob each
           \        /
        [Zone 3]                ← 2 mobs
           |
        [Zone 4]                ← 4 mobs (final)
```

- 4 zones in a diamond DAG — player picks path via `choose(direction)`
- Zone 1 is spawn (no combat)
- Zone 2a/2b each have 1 mob — player picks one branch
- Zone 3 has 2 mobs — convergence point
- Zone 4 has 4 mobs — final room, clearing = dungeon complete
- Hardcoded graph for PoC (procedural generation later)

### Mob Stats

| Stat | Value |
|------|-------|
| Health | 20 |
| Power | 5 (damage per turn to player) |

### Combat Flow (Turn-Based)

```
1. Player enters zone → calls start()
   └─ Contract creates Fight entity, spawns N mobs with packed HP

2. Player's turn:
   └─ cast(mob_id, skill_id=AA) → spend 30 stamina, deal 10 damage to mob
   └─ Can cast multiple times per turn if stamina allows (3 attacks max at 100 stamina)

3. Player calls finish() → ends player turn
   └─ All surviving mobs attack player (5 damage each)
   └─ Player regens stamina (full reset? partial?)
   └─ If all mobs dead → combat ends, player regens some health

4. If player HP ≤ 0 → dungeon failed
   If all mobs in zone dead → zone cleared, can choose(direction) to next zone
   If zone 4 cleared → dungeon complete
```

### Contract Actions

| Action | Params | Logic |
|--------|--------|-------|
| `spawn(class_id)` | u8 | Create Character + Dungeon models. Hardcoded dungeon graph. Place player in Zone 1. |
| `choose(direction)` | u8 (0=left, 1=right) | Move player to next zone. Assert current zone's combat is resolved. Validate edge exists in graph. |
| `start()` | — | Begin combat in current zone. Create Fight entity with packed mob HP. |
| `cast(mob_id, skill_id)` | u8, u8 | Spend stamina, deal damage to target mob. Assert fight is active, mob alive, enough stamina. |
| `finish()` | — | End player turn. Mobs attack. Regen stamina. If all mobs dead, end fight + regen health. Check dungeon completion. |

---

## Technical Design

### Data Model (Dojo ECS)

```cairo
#[dojo::model]
struct Character {
    #[key]
    id: felt252,              // = player address or game ID
    class_id: u8,             // Hero class (0 for PoC)
    health: u16,
    max_health: u16,
    power: u16,
    stamina: u16,
    max_stamina: u16,
    current_zone: u8,         // Which zone the player is in (0-3)
    dungeon_id: felt252,      // Link to dungeon
}

#[dojo::model]
struct Dungeon {
    #[key]
    id: felt252,
    owner: ContractAddress,
    // Zone adjacency — hardcoded for PoC
    // Packed zone data: mob counts per zone
    zones: felt252,           // Packed: [0 mobs, 1 mob, 1 mob, 2 mobs, 4 mobs]
    zones_cleared: u8,        // Bitmap of cleared zones
    completed: bool,
    started_at: u64,
}

#[dojo::model]
struct Fight {
    #[key]
    dungeon_id: felt252,
    #[key]
    zone_id: u8,
    mob_count: u8,
    mob_healths: felt252,     // Packed: N mob HPs (20 each, 8 bits per mob)
    mob_power: u16,           // Same for all mobs in zone
    active: bool,
    turn: u8,                 // Turn counter
}
```

### Dungeon Graph Representation

For PoC, hardcode the diamond:

```cairo
// Zone adjacency as a simple lookup
// zone_id => (left_child, right_child) where 0xFF = no child
const GRAPH: [(u8, u8); 5] = [
    (1, 2),     // Zone 0 (spawn) → Zone 1, Zone 2
    (3, 3),     // Zone 1 → Zone 3 (converge)
    (3, 3),     // Zone 2 → Zone 3 (converge)
    (4, 4),     // Zone 3 → Zone 4 (final)
    (0xFF, 0xFF), // Zone 4 → end
];

const ZONE_MOB_COUNTS: [u8; 5] = [0, 1, 1, 2, 4];
```

### Events

| Event | Fields |
|-------|--------|
| `CharacterSpawned` | id, class_id, health, power, stamina |
| `ZoneEntered` | dungeon_id, zone_id |
| `FightStarted` | dungeon_id, zone_id, mob_count |
| `MobDamaged` | dungeon_id, zone_id, mob_id, damage, hp_after |
| `PlayerDamaged` | dungeon_id, zone_id, damage, hp_after |
| `FightEnded` | dungeon_id, zone_id, player_hp_after |
| `DungeonCompleted` | dungeon_id, owner |
| `DungeonFailed` | dungeon_id, owner |

### Architecture (Godot Client)

```
Godot 4.3+ Project
├── addons/godot-dojo/            # SDK (from releases)
├── scenes/
│   ├── main.tscn                 # Entry point, ToriiClient + DojoSessionAccount nodes
│   ├── dungeon.tscn              # 3D dungeon view (isometric camera, zone nodes)
│   ├── combat.tscn               # Combat UI overlay (mob HP bars, action buttons)
│   └── hud.tscn                  # CanvasLayer HUD (player stats, stamina bar)
├── scripts/
│   ├── connection.gd             # Cartridge Controller auth flow
│   ├── torii_sync.gd             # Entity subscription + state management
│   ├── dungeon_controller.gd     # Dungeon navigation, zone transitions
│   ├── combat_controller.gd      # Combat flow, cast/finish actions
│   ├── dojo_wrapper.gd           # Typed wrapper over Dictionary API
│   └── camera_rig.gd             # Fixed isometric camera
└── project.godot
```

**Torii state sync flow:**
1. `ToriiClient` subscribes to Character, Dungeon, Fight entities filtered by player address
2. On entity update callback → parse Dictionary → update local game state
3. GDScript wrapper layer converts raw Dictionaries to typed classes
4. Scene nodes react to state changes (health bars, zone highlights, mob sprites)

---

## Implementation Plan

### Phase 0: Repository Migration (Serial — Must Complete First)

**Prerequisite for:** All subsequent phases

| Task | Description | Output |
|------|-------------|--------|
| 0.1 | Tag current main as `game-jam-viii` and create branch | `git tag game-jam-viii && git branch game-jam-viii` |
| 0.2 | Create fresh `main` branch (orphan) with clean history | New empty main branch |
| 0.3 | Initialize Scarb workspace + Dojo config (Scarb.toml, dojo_dev.toml) | Compiling empty project |
| 0.4 | Initialize Godot 4 project in `client/` | `project.godot`, Godot opens clean |
| 0.5 | Install `godot-dojo` v0.7.4 SDK into `client/addons/godot-dojo/` | SDK available in editor |
| 0.6 | Install godogen + godot-task skills into `.claude/skills/` (or `.agents/skills/`) | Skills loadable by AI agents |
| 0.7 | Write README.md with new scope, setup instructions, skill install commands | Contributors can onboard |

#### Migration Commands

```bash
# --- Shelve current work ---
cd /home/djizus/projects/athanor
git tag game-jam-viii          # Permanent tag for the grimoire-race version
git push origin game-jam-viii  # Push tag to remote

git checkout -b game-jam-viii  # Branch too (for easy checkout)
git push origin game-jam-viii  # Push branch

# --- Clean main for new direction ---
git checkout --orphan main-v2  # Orphan branch = no history
git rm -rf .                   # Remove all tracked files
git clean -fd                  # Remove untracked files

# (Re-add foundation files — Scarb.toml, dojo configs, .gitignore, README, PLAN.md)
git add .
git commit -m "Athanor v2: tactical dungeon crawler — fresh start"

git branch -D main             # Delete old local main
git branch -m main-v2 main     # Rename to main
git push origin main --force   # Force-push new main (⚠️ destructive to old main)
```

#### Skill Installation Commands (for contributors)

```bash
# --- Clone godogen skills ---
git clone --depth 1 https://github.com/htdt/godogen /tmp/godogen

# --- Install into project ---
mkdir -p .agents/skills/godogen .agents/skills/godot-task

# Copy godogen orchestrator skill
cp -r /tmp/godogen/skills/godogen/* .agents/skills/godogen/

# Copy godot-task executor skill (includes 862 Godot API docs)
cp -r /tmp/godogen/skills/godot-task/* .agents/skills/godot-task/

# --- Bootstrap API docs (if not already present) ---
bash .agents/skills/godot-task/tools/ensure_doc_api.sh

# --- Install godot-dojo SDK ---
# Download from: https://github.com/lonewolftechnology/godot-dojo/releases/tag/v0.7.4
# Extract addons/godot-dojo/ into client/addons/godot-dojo/

# --- Verify ---
ls .agents/skills/godogen/SKILL.md   # Should exist
ls .agents/skills/godot-task/SKILL.md # Should exist
ls client/addons/godot-dojo/          # Should contain plugin files
```

---

### Phase 1: Contracts — Core Models & Systems (Serial Foundation)

**Prerequisite for:** Phase 2 (client), Phase 3 (integration)

| Task | Description | Output |
|------|-------------|--------|
| 1.1 | Define all models: Character, Dungeon, Fight in `contracts/src/models/` | Models compile |
| 1.2 | Define types: ClassType, Direction, SkillType enums | Types compile |
| 1.3 | Define events: all 8 combat/dungeon events in `contracts/src/events/` | Events compile |
| 1.4 | Implement Store pattern (typed accessors for all models, event emitters) | Store compiles |
| 1.5 | Implement `spawn(class_id)` — create Character + Dungeon, hardcoded graph | `sozo build` passes |
| 1.6 | Implement `choose(direction)` — zone navigation with graph validation | `sozo build` passes |
| 1.7 | Implement `start()` — create Fight with packed mob HPs | `sozo build` passes |
| 1.8 | Implement `cast(mob_id, skill_id)` — damage mob, spend stamina, assertions | `sozo build` passes |
| 1.9 | Implement `finish()` — mob attacks, stamina regen, fight/dungeon completion | `sozo build` passes |
| 1.10 | Deploy to local Katana, verify full loop via `sozo execute` | All 5 actions work E2E |

---

### Parallel Workstreams

#### Workstream A: Godot Client — Scene & Camera Setup

**Dependencies:** Phase 0
**Can parallelize with:** Workstream B (starts after Phase 0, before contracts are done)

| Task | Description | Output |
|------|-------------|--------|
| A.1 | Set up Godot project: project.godot, window config, input actions, physics | Project opens in editor |
| A.2 | Create isometric camera rig (fixed 45° angle, orthographic or perspective) | Camera renders 3D scene |
| A.3 | Build dungeon scene: 4 zone platforms in diamond layout, path connections | Visual dungeon structure |
| A.4 | Player character placeholder (capsule/cube with health bar) | Character visible in scene |
| A.5 | Zone transition animations (player moves between zones on `choose`) | Smooth movement between zones |
| A.6 | Combat UI overlay: mob HP bars, action buttons (Attack, End Turn), stamina bar | UI renders correctly |

#### Workstream B: Godot Client — Dojo Integration Layer

**Dependencies:** Phase 0, godot-dojo SDK installed
**Can parallelize with:** Workstream A

| Task | Description | Output |
|------|-------------|--------|
| B.1 | Connection scene: ToriiClient + DojoSessionAccount nodes, auth flow | Connects to Katana |
| B.2 | Typed GDScript wrapper: Character, Dungeon, Fight classes over Dictionary | Wrapper parses entities |
| B.3 | Entity subscription: subscribe to Character/Dungeon/Fight updates | State syncs on changes |
| B.4 | Transaction helpers: calldata encoding for spawn, choose, start, cast, finish | Transactions execute |
| B.5 | Event subscription: combat events (MobDamaged, PlayerDamaged, etc.) | Events trigger UI updates |

---

### Phase 3: Integration & Polish

**Dependencies:** Phase 1, Workstreams A + B

| Task | Description | Output |
|------|-------------|--------|
| 3.1 | Wire contract actions to Godot UI buttons (spawn → choose → start → cast → finish) | Full loop playable |
| 3.2 | React to Torii entity updates: health bars, mob death, zone clear visual feedback | State reflected in 3D |
| 3.3 | Dungeon completion screen (simple "You Win" / "You Died" overlay) | End state handled |
| 3.4 | Deploy to Slot (Katana + Torii) | Playable on Slot |
| 3.5 | Smoke test: full dungeon run from spawn to completion | PoC validated |

---

## Testing and Validation

### Contract Tests
- `spawn` creates Character with correct stats + Dungeon with graph
- `choose(0)` moves to left child, `choose(1)` to right child
- `choose` reverts if zone combat not resolved
- `start` creates Fight with correct mob count and HP
- `cast` deals correct damage, spends stamina, reverts if dead mob or no stamina
- `finish` applies mob damage, regens stamina, ends fight when mobs dead
- Full loop: spawn → choose(0) → start → cast×N → finish → choose → ... → clear zone 4

### Client Tests
- Godot opens project without errors: `timeout 60 godot --headless --quit 2>&1`
- ToriiClient connects to local Torii
- Session account authenticates with Controller
- Entity subscription fires on state change
- UI updates reflect entity state

---

## Verification Checklist

```bash
# Contracts
sozo build                                          # Clean compilation
sozo test                                           # Unit tests pass
sozo migrate --dev                                  # Deploys to Katana
sozo execute <contract> spawn -c 0                  # Creates character

# Client
cd client && timeout 60 godot --headless --quit     # No parse errors
# Manual: open Godot, connect wallet, play through dungeon
```

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| godot-dojo SDK immaturity (no typed bindings, basic error handling) | High | Medium | Build typed GDScript wrapper early (Workstream B.2). Keep contract interface simple. |
| gRPC streaming latency too high for turn-based UX | Low | Medium | Turn-based is forgiving. Can fall back to polling via `entities()` query. |
| Godot 4.3 compatibility issues with SDK | Medium | High | Pin SDK version, test early. SDK tested against 4.3. |
| Diamond graph too simple for engagement | Low | Low | Hardcoded graph is intentionally simple for PoC. Procedural generation is v2.1. |
| Force-pushing main loses contributor work | Medium | High | Coordinate with team before push. Tag preserves all history. |

---

## Open Questions

- [ ] Stamina regen on `finish()`: full reset to 100, or partial (e.g., +50)?
- [ ] Health regen between zones: how much? Fixed amount or percentage?
- [ ] Do mobs attack in a specific order or all simultaneously on `finish()`?
- [ ] Should `cast` be callable multiple times before `finish`, or strictly one action per turn?
- [ ] Mob power scaling: all mobs identical (power=5) or varied per zone?
- [ ] Will game-components (Provable Games) be integrated for PoC, or deferred?

---

## Decision Log

| Decision | Rationale | Alternatives Considered |
|----------|-----------|------------------------|
| Completely fresh contracts | Grimoire-race models are fundamentally different from tactical combat. No reusable logic. | Fork and evolve — rejected because every model needs replacement |
| Godot 4 + fixed isometric camera | Matches tactical RPG genre. godot-dojo SDK requires 4.3+. Fixed camera simpler than free. | 2D top-down (simpler but less visual impact), Full 3D (too much effort for PoC) |
| Hardcoded diamond graph | Simplest possible branching structure. Proves `choose(direction)` works. | Linear (no branching to test), Procedural (too complex for PoC) |
| 1 class, 1 skill (AA) | Minimal viable combat. Proves the turn loop. Classes/skills are additive later. | 2-3 classes (too much contract surface for PoC) |
| Solo dungeons, no MMO | Reduces scope to pure gameplay validation. Async MMO is layered on top. | Shared leaderboard (adds complexity without validating combat) |
| godot-dojo SDK (not custom) | Official community SDK, actively maintained, handles Torii gRPC + Controller auth. | Raw HTTP/gRPC from GDScript (massive effort), Rust native (wrong stack) |
| godogen skills for AI-assisted dev | 862 Godot API docs + scene generation patterns + GDScript reference. Major productivity boost for agents. | No skills (agents hallucinate GDScript), Custom docs (duplicate effort) |
