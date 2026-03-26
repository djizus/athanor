# Athanor v2 — Combat System Redesign Plan

> **Last updated**: 2026-03-26 — Complete combat redesign
> **Status**: Design finalized. Ready for implementation.
> **Branch**: `offline` (builds on existing combat prototype with 57 passing tests)

---

## Table of Contents

1. [Overview](#overview)
2. [Goals](#goals)
3. [Non-Goals](#non-goals)
4. [Assumptions and Constraints](#assumptions-and-constraints)
5. [Game Design](#game-design)
6. [Combat Values Reference](#combat-values-reference)
7. [Architecture](#architecture)
8. [Implementation Plan](#implementation-plan)
9. [Testing Strategy](#testing-strategy)
10. [Commit Strategy](#commit-strategy)
11. [Risk Assessment](#risk-assessment)
12. [Decision Log](#decision-log)
13. [Open Questions](#open-questions)

---

## Overview

Redesign Athanor's tactical combat into an expression-heavy system with bump displacement,
escalating stamina, and deterministic enemy telegraphing. The player has a toolkit of 5 abilities
and movement that physically pushes enemies around the board. Stamina starts tight (80/turn) and
grows through kills (+10) and energy orb pickups (+20), building each combat to a crescendo. Three
rooms with scaling grid sizes (6×6 → 7×7 → 8×8) form a single run. Solo hero now, architected
for future squad expansion.

**Design pillars:**
- **Into the Breach**: Deterministic enemy telegraphing. Full information. The board is a puzzle.
- **Attack of the Astrals**: Movement has consequences. Walking into enemies displaces them.
- **Inkbound**: Shared stamina resource for movement + abilities. Escalating power curve.

---

## Goals

- Expression-heavy combat: multiple valid approaches per turn, "I found a cool thing" moments
- Bump displacement: walking into enemies pushes them 1 tile, enabling board manipulation
- Escalating stamina: kills and energy orbs grant bonus stamina mid-turn for crescendo moments
- 5 abilities from a draft pool (hardcoded selection for prototype): Strike, Dash, Heal, Shove, Slam
- 5 enemy archetypes: Brute, Caster, Flanker, Heavy (immovable), Puller (forced movement)
- 3-room progression with scaling grid size and difficulty
- Deterministic AI: all enemy behavior predictable, no randomness
- TDD: every new system has tests written before implementation
- Atomic commits: every commit passes all tests and is independently bisectable

---

## Non-Goals

- Onchain/Dojo integration (future)
- Roguelite draft UI (architecture supports it, UI deferred)
- Squad mode gameplay (architecture supports it, deferred)
- Audio/SFX (deferred to post-prototype polish)
- Between-room shop, upgrades, or healing pickups
- Procedural level generation (rooms are hand-designed)
- Multiplayer / co-op
- Status effects beyond Heal (burn, freeze, etc. are future)
- Chain bumps (bump A into B, B moves further — future)

---

## Assumptions and Constraints

- Godot 4.5.2, GDScript only
- Pixel art: 16×16 base sprites, 480×270 viewport at 4× upscale (1920×1080)
- All combat is client-side/offchain for now
- Deterministic: no RNG in combat resolution
- Keep `combat_manager` orchestrator pattern (signal-driven, await-based turns)
- Build on existing codebase: 13 test files, 57+ passing tests, working grid/ability/AI systems
- Target: playable 3-room prototype, not feature-complete game

---

## Game Design

### Core Identity

Athanor is an **expression-heavy tactical RPG**. Enemies show you exactly what they will do
next turn (telegraphs). You have a toolkit of movement and 5 abilities to creatively dismantle
their plans. There are multiple valid solutions to each board state — the fun is discovering
the creative one. Combat builds to a crescendo: early turns are tight and scrappy, but as you
kill enemies and collect energy orbs, your stamina grows, enabling bigger combo chains.

The three player verbs:
1. **Move** — costs stamina (10/tile). Walking INTO an enemy bumps them 1 tile. Repositions
   both you and the enemy. The board rearranges.
2. **Abilities** — cost stamina (20-35). Deal damage, push enemies, heal yourself. The primary
   tools for expression.
3. **End Turn** — confirm your actions. Telegraphs resolve, then enemies act.

### Turn Flow

**Phase order**: `PLAYER_ACTION → RESOLVE → ENEMY_ACTION` (repeating)

This ordering guarantees that bumps pay off: the player pushes an enemy into a telegraph zone,
and the very next thing that happens is RESOLVE — no enemy movement in between.

```
COMBAT START:
  Place grid, obstacles, player, enemies
  Initial ENEMY_ACTION: enemies move into position, create first telegraphs
  → Player sees telegraphs before their first turn

MAIN LOOP (each round):
  ┌─ PLAYER_ACTION ─────────────────────────────────────────┐
  │  Stamina refills to 80 (base)                           │
  │  Player sees enemy telegraphs from previous round       │
  │  Player can (in any order, repeatedly):                 │
  │    • Move (10 stamina/tile, bump on collision)          │
  │    • Use ability (20-35 stamina, cooldown-gated)        │
  │    • Collect energy orb (walk over: +20 stamina)        │
  │  Kills during this phase: +10 stamina instantly         │
  │  Player clicks "End Turn" when done                     │
  └─────────────────────────────────────────────────────────┘
           │
           ▼
  ┌─ RESOLVE ───────────────────────────────────────────────┐
  │  1. PULL telegraphs resolve first:                      │
  │     - Player dragged toward Puller source               │
  │     - Blocked by obstacles (stops early)                │
  │  2. DAMAGE telegraphs resolve second:                   │
  │     - Damage applied to all units in telegraph tiles    │
  │     - Player position may have changed from pull        │
  │  3. Process deaths → spawn energy orbs at death tiles   │
  │  4. Tick ability cooldowns (-1 each)                    │
  │  5. Win check: all enemies dead → next room or victory  │
  │  6. Lose check: player HP ≤ 0 → defeat                 │
  └─────────────────────────────────────────────────────────┘
           │
           ▼
  ┌─ ENEMY_ACTION ──────────────────────────────────────────┐
  │  For each surviving enemy (deterministic order):        │
  │    1. AI computes intent based on current board state   │
  │    2. Enemy moves to computed position                  │
  │    3. Enemy creates telegraph (visible next PLAYER turn)│
  │  All AI is deterministic: same inputs → same outputs    │
  └─────────────────────────────────────────────────────────┘
           │
           ▼
  Loop back to PLAYER_ACTION
```

**Why PULL resolves before DAMAGE**: The Puller drags the player to a new position. THEN damage
telegraphs fire at their placed tiles. This means a Pull can drag you OUT of a damage zone (lucky)
or INTO one (devastating). The player must consider: "where will the pull leave me, and is that
tile in a damage zone?" This creates the richest puzzle interactions.

### Stamina Economy

| Parameter        | Value      | Notes                                           |
|------------------|------------|-------------------------------------------------|
| Base per turn    | 80         | Refills at start of each PLAYER_ACTION          |
| Movement cost    | 10 / tile  | Manhattan pathfinding, no diagonals             |
| Kill bonus       | +10        | Instant, same turn. Enables follow-up actions.  |
| Energy orb value | +20        | Must walk over to collect. Movement incentive.  |
| Orb spawn        | Death tile | Appears where enemy died. Persists 2 turns.    |
| Collision damage | 5          | Free damage from bump into wall/obstacle/enemy  |

**The crescendo math:**
- Turn 1: 80 stamina = ~2 moves + 1-2 abilities. Tight.
- Kill an enemy with Strike: 80 - 10 (move) - 20 (Strike) = 50, +10 (kill) = 60 remaining.
- Walk over orb: 60 - 10 (move) + 20 (orb) = 70. Another full ability available.
- Two kills in one turn: 80 + 20 (kills) + 20 (orb) = 120 effective budget. Crescendo.

### Bump Displacement

**Core rule**: Moving INTO an occupied tile pushes that unit 1 tile in your movement direction.

| Scenario                              | Player Position         | Enemy Position         | Damage       |
|---------------------------------------|------------------------|------------------------|--------------|
| Bump into open tile                   | Enemy's old tile       | 1 tile in move dir     | 0            |
| Bump → enemy hits wall/obstacle       | 1 tile short of enemy  | Stays put              | 5 to enemy   |
| Bump → enemy hits another enemy       | 1 tile short of first  | Both stay put          | 5 to each    |
| Bump → enemy is Heavy (immovable)     | 1 tile short of Heavy  | Stays put              | 5 to Heavy   |
| Move into empty tile (normal move)    | Destination tile       | N/A                    | 0            |

**Bump does NOT cost extra stamina.** It's a natural consequence of movement. The 10/tile cost
covers the bump. Collision damage (5) is free bonus damage — a reward for clever positioning.

**No chain bumps for prototype**: Enemy A bumped into Enemy B → both take 5 damage, neither
moves further. Chain bumps (A pushes B, B pushes C) are a future addition.

**Pathfinding change**: Enemy tiles are valid movement destinations (not blockers). When the
player's path ends at an enemy tile, bump logic triggers. Obstacle tiles remain impassable.

### Abilities

5 ability slots drawn from a draft pool. Prototype always uses the same loadout.

| # | Name      | Cat.    | Target   | Range | Cost | CD | Damage | Effect                                                |
|---|-----------|---------|----------|-------|------|----|--------|-------------------------------------------------------|
| 1 | **Strike**| Attack  | ADJACENT | 1     | 20   | 0  | 15     | Hit one adjacent enemy. No cooldown. Bread and butter. |
| 2 | **Dash**  | Mobility| LINE     | 3     | 25   | 1  | 10     | Move up to 3 tiles in cardinal dir. Hit first enemy.   |
| 3 | **Heal**  | Utility | SELF     | 0     | 25   | 3  | 0      | Restore 20 HP. Only healing in the game. Not spammable.|
| 4 | **Shove** | Control | ADJACENT | 1     | 20   | 1  | 5      | Push adjacent enemy 2 tiles away from player.          |
| 5 | **Slam**  | Attack  | SELF/AOE | 0     | 35   | 2  | 10     | Hit ALL adjacent enemies + push each 1 tile away.      |

**Ability interactions with bump:**
- **Dash** stops at first enemy and deals damage. Does NOT bump (it's an ability, not walking).
- **Shove** pushes 2 tiles (not 1 like bump). If blocked at tile 1 or 2, collision damage applies.
- **Slam** pushes each adjacent enemy 1 tile away from player. Multiple enemies can collide.

**Combo examples:**
- Shove Enemy A into telegraph zone → Strike Enemy B → Dash to orb → end turn → RESOLVE kills A
- Move to bump Enemy A into Enemy B (5 dmg each) → Slam to push Enemy C into wall (5+10 dmg) → collect orb
- Heal (25 stamina) → move 3 tiles to bump Caster into corner (30 stamina) → Strike Caster (20 stamina) → kill → +10 bonus → remaining: 80-25-30-20+10 = 15 stamina

**Draft pool architecture (not built yet, designed for):**
- Eventually ~15-20 abilities in the pool
- Player drafts 5 between rooms (or before a run)
- Must include ≥1 Attack, ≥1 Control to ensure minimum viability
- AbilityResource data format already supports this — loadout is just an Array[AbilityResource]

### Enemy Archetypes

| # | Name        | HP  | Speed   | Bumpable | Telegraph Shape | Telegraph Effect  | AI Behavior                                     |
|---|-------------|-----|---------|----------|-----------------|-------------------|-------------------------------------------------|
| 1 | **Brute**   | 50  | 2/turn  | Yes      | Adjacent (melee) | 20 DAMAGE         | Chase player (manhattan, deterministic axis)     |
| 2 | **Caster**  | 30  | 1/turn  | Yes      | 3×3 AOE on player| 12 DAMAGE         | Kite (retreat if distance < 3, else stay)        |
| 3 | **Flanker** | 40  | 2/turn  | Yes      | Adjacent (melee) | 18 DAMAGE         | Flank behind player's last move direction        |
| 4 | **Heavy**   | 70  | 1/turn  | **No**   | Cross (+) pattern| 25 DAMAGE         | Slow chase. Immovable. Must fight or avoid.      |
| 5 | **Puller**  | 35  | 1/turn  | Yes      | 3×3 zone on player| 2-tile PULL       | Maintain distance ≥3. Forces player movement.    |

**Heavy details:**
- `is_immovable = true` on CombatStatsResource
- Cannot be bumped or Shoved. Blocks bump chains.
- Still takes collision damage (5) when OTHER enemies are bumped INTO it.
- Cross telegraph: center tile + 4 cardinal tiles = 5 tiles total, centered on player position.
- Slow but lethal. Forces the player to spend abilities (can't just bump it away).

**Puller details:**
- Telegraph type is PULL, not DAMAGE. No HP lost from pull itself.
- On RESOLVE: player is forcibly moved 2 tiles toward Puller's current position.
- Movement blocked by obstacles (player stops early). Not blocked by enemies (passes through).
- Counter-play: move off the pull zone, bump Puller to change pull direction, or kill it.
- Combined with Caster AOE: Puller drags you, then Caster AOE fires at your new position.
  Or: Puller drags you OUT of Caster AOE (emergent friendly-fire between enemies).

**AI determinism:**
All AI uses the same pattern: `compute_intent(self_pos, player_pos, grid_state) → Dictionary`.
Same inputs always produce same outputs. Player can fully predict enemy behavior.

### Room Progression

| Room | Grid   | Obstacles | Enemies                                 | Difficulty | Teaches                                           |
|------|--------|-----------|-----------------------------------------|------------|---------------------------------------------------|
| 1    | **6×6**| 6-8       | 2 Brute + 1 Caster                      | Easy       | Movement, telegraphs, basic abilities              |
| 2    | **7×7**| 8-10      | 1 Brute + 1 Flanker + 1 Heavy           | Medium     | Bump displacement, immovable enemies, flanking     |
| 3    | **8×8**| 10-12     | 1 Heavy + 1 Puller + 2 Flanker          | Hard       | Forced movement, multi-threat, bump combos         |

- **Win condition**: Kill all enemies in each room. Survive (don't let HP reach 0).
- **Between rooms**: No healing. Player HP carries over. Heal ability is the only HP recovery.
- **After Room 3**: Victory screen → return to menu.
- **On death**: Defeat screen → "Retry" (restart from Room 1) or "Menu".
- **No timer, no turn limit.** The player can take as long as they want.

### Grid and Visuals

| Parameter             | Value             | Notes                                          |
|-----------------------|-------------------|-------------------------------------------------|
| Grid sizes            | 6×6, 7×7, 8×8    | Per-room. Parameterized in CombatGrid.           |
| Tile size             | 32×16 (iso)       | Existing pixel art. Isometric projection.        |
| Viewport              | 480×270 at 4×     | Pixel-perfect. Existing setting.                 |
| Obstacle count        | 6-12 per room     | Scaled with grid size. Hand-placed.              |
| Movement overlay      | Green gradient     | Existing. Darker = more stamina cost.            |
| Telegraph overlay     | Red pulsing        | Existing. Damage zones pulse 0.35-0.55 alpha.   |
| Pull telegraph overlay| Blue pulsing + arrow| NEW. Distinct from damage. Arrow toward Puller. |
| Energy orb visual     | Yellow pulsing     | NEW. Distinct from damage/movement overlays.     |
| Ability range overlay | Purple             | Existing. Valid targets for selected ability.     |
| Bump indicator        | Orange flash       | NEW. Brief flash on bumped enemy tile.           |
| Heavy visual          | Larger/darker sprite| NEW. Must read as "immovable" at a glance.      |

---

## Combat Values Reference

All tunable values in one place for balance passes.

| Category     | Parameter            | Value  | Unit          |
|--------------|----------------------|--------|---------------|
| **Stamina**  | Base per turn        | 80     | stamina       |
|              | Move cost            | 10     | stamina/tile  |
|              | Kill bonus           | 10     | stamina       |
|              | Orb pickup bonus     | 20     | stamina       |
|              | Orb lifetime         | 2      | turns         |
| **Collision**| Bump collision damage | 5     | HP            |
| **Player**   | Max HP               | 100    | HP            |
| **Strike**   | Cost / CD / Damage   | 20/0/15| stam/turns/HP |
| **Dash**     | Cost / CD / Damage   | 25/1/10| stam/turns/HP |
| **Heal**     | Cost / CD / Heal     | 25/3/20| stam/turns/HP |
| **Shove**    | Cost / CD / Damage   | 20/1/5 | stam/turns/HP |
|              | Push distance        | 2      | tiles         |
| **Slam**     | Cost / CD / Damage   | 35/2/10| stam/turns/HP |
|              | Push distance        | 1      | tile (each)   |
| **Brute**    | HP / Speed / Damage  | 50/2/20| HP/tiles/HP   |
| **Caster**   | HP / Speed / Damage  | 30/1/12| HP/tiles/HP   |
| **Flanker**  | HP / Speed / Damage  | 40/2/18| HP/tiles/HP   |
| **Heavy**    | HP / Speed / Damage  | 70/1/25| HP/tiles/HP   |
| **Puller**   | HP / Speed / Pull    | 35/1/2 | HP/tiles/tiles|

---

## Architecture

### Scene Tree During Combat

```
TacticalRoom (or RoomCombat via CombatRoomSetup)
├── CombatGrid (parameterized: 6×6, 7×7, or 8×8)
│   ├── GridOverlay (TileMapLayer — walkable/danger/pull/ability tiles)
│   ├── GridCursor (Sprite2D — hover highlight)
│   └── CostLabels (stamina cost numbers on reachable tiles)
├── EnergyOrbs (Node2D container)                               ← NEW
│   └── EnergyOrb × N (Sprite2D + Area2D, pulsing yellow)
├── YSortedLayer/
│   ├── Player (CharacterBody2D, realtime movement disabled)
│   └── Enemies × N (CharacterBody2D, realtime nodes stripped)
├── CombatManager (orchestrator, 700+ lines)
│   ├── TurnManager (phase loop: PLAYER → RESOLVE → ENEMY)     ← REORDERED
│   ├── GridMovement (A* pathfinding + bump detection)          ← MODIFIED
│   ├── BumpSystem (displacement + collision logic)             ← NEW
│   ├── EnergyOrbSystem (spawn, pickup, expiry)                 ← NEW
│   ├── AbilityManager (5 ability slots, cooldowns)             ← EXPANDED
│   ├── AbilityTargeting (ADJACENT/LINE/SELF + directional)
│   ├── TelegraphSystem (DAMAGE + PULL types)                   ← EXTENDED
│   ├── EnemyTurnResolver (AI execution + telegraph creation)
│   ├── AbilityStrike / AbilityDash / AbilityHeal              ← Heal replaces Guard
│   ├── AbilityShove / AbilitySlam                              ← NEW
│   ├── BruteAI / CasterAI / FlankerAI                         (existing)
│   └── HeavyAI / PullerAI                                     ← NEW
├── RoomSequencer (manages 3-room progression)                  ← NEW
├── CombatHUD (CanvasLayer — 5 ability buttons, HP/stamina)     ← UPDATED
└── GameResultScreen (CanvasLayer — victory/defeat overlay)
```

### Key Systems and Signals

```
BumpSystem:
  signal bump_occurred(bumper_pos, target_pos, push_dir, blocked:bool)
  signal collision_damage(target_id, damage)

EnergyOrbSystem:
  signal orb_spawned(grid_pos, value)
  signal orb_collected(grid_pos, value)
  signal orb_expired(grid_pos)

TelegraphSystem (extended):
  signal telegraph_added(data)    # data includes type: DAMAGE or PULL
  signal telegraph_resolved(data) # pull data includes direction + distance

RoomSequencer:
  signal room_started(room_index, grid_size, enemy_composition)
  signal room_cleared(room_index)
  signal run_completed()
  signal run_failed()

CombatManager (updated):
  signal combat_started()
  signal combat_finished(player_won:bool)
  signal stamina_changed(current, max)  # for HUD updates
```

### Extension Points for Future

| Feature         | Extension Point                                          |
|-----------------|----------------------------------------------------------|
| Squad mode      | CombatManager uses `units:Array`, not single `player`     |
| Draft UI        | AbilityManager.set_loadout(abilities:Array[AbilityResource]) |
| New abilities   | Create script + .tres, add to ability pool               |
| New enemies     | Create AI script extending EnemyGridAI, add to spawner   |
| Status effects  | Add `status_effects:Array[Dictionary]` to CombatStatsResource |
| Terrain types   | Add `tile_type:int` to grid cells (PIT, FIRE, ICE)       |
| Chain bumps     | Extend BumpSystem.compute_displacement() with recursion   |
| Onchain sync    | Replace local state with Torii entity updates             |

---

## Implementation Plan

### Phase 0: Foundation (Serial — Must Complete First)

**Prerequisite for**: All workstreams

These minimal changes unblock all parallel work.

| #   | Task                            | Test Changes                                   | Implementation Changes                           | Output Files                                     |
|-----|---------------------------------|------------------------------------------------|--------------------------------------------------|--------------------------------------------------|
| 0.1 | Parameterize grid size          | `test_grid_utils.gd`: test 6×6, 7×7, 8×8      | `combat_grid.gd`: `@export var grid_size:int=8`  | `combat_grid.gd`, `grid_utils.gd`, tests         |
|     |                                 | bounds checks with variable sizes              | `grid_utils.gd`: all funcs take `grid_size` param|                                                  |
| 0.2 | Reorder turn phases             | `test_turn_manager.gd`: verify new phase order | `turn_manager.gd`: loop = PLAYER→RESOLVE→ENEMY   | `turn_manager.gd`, tests                         |
|     |                                 | PLAYER→RESOLVE→ENEMY cycle                     | Add initial ENEMY_ACTION at combat start          |                                                  |
| 0.3 | Foundation data changes         | `test_stamina.gd`: verify 80 base refill       | `stamina_resource.gd`: default max=80             | `stamina_resource.gd`, `combat_stats_resource.gd`|
|     |                                 | `test_ability_manager.gd`: test 5 slots        | `combat_stats_resource.gd`: add `is_immovable`    | `ability_manager.gd`, tests                      |
|     |                                 |                                                | `ability_manager.gd`: support 5 ability slots     |                                                  |

**Commits:**
```
0.1  refactor(grid): parameterize grid size for variable room dimensions
0.2  refactor(turns): reorder phases to PLAYER→RESOLVE→ENEMY for bump payoff
0.3  refactor(foundation): base stamina 80, immovable flag, 5 ability slots
```

**Verification:**
```bash
cd client && godot --headless --script res://tests/test_grid_utils.gd && \
godot --headless --script res://tests/test_turn_manager.gd && \
godot --headless --script res://tests/test_stamina.gd && \
godot --headless --script res://tests/test_ability_manager.gd
```

---

### Parallel Workstreams

After Phase 0, these 4 workstreams can execute independently.

```
Phase 0 ──┬── Workstream A: Bump Displacement
           ├── Workstream B: Escalating Stamina + Orbs
           ├── Workstream C: New Abilities (Heal, Shove, Slam)
           └── Workstream D: New Enemy Types (Heavy, Puller)
                     │
                     ▼
              Merge Phase: Room Progression + Integration
                     │
                     ▼
              Polish Phase: VFX, Visuals, Balance
```

---

#### Workstream A: Bump Displacement System

**Dependencies**: Phase 0 (grid parameterization, is_immovable flag)
**Can parallelize with**: B, C, D

| #   | Task                              | Description                                                         | Output                               |
|-----|-----------------------------------|---------------------------------------------------------------------|--------------------------------------|
| A.1 | Test bump displacement            | Write `test_bump_system.gd`:                                        | `tests/test_bump_system.gd`          |
|     |                                   | - Bump into open tile: enemy displaced, player takes enemy's tile   |                                      |
|     |                                   | - Bump into wall: enemy stays, takes 5 collision damage             |                                      |
|     |                                   | - Bump into enemy: both take 5 collision damage, neither moves      |                                      |
|     |                                   | - Bump into Heavy: player stops short, Heavy takes 5 damage         |                                      |
|     |                                   | - Normal move (empty tile): no bump triggered                       |                                      |
| A.2 | Implement BumpSystem              | Create `scripts/combat/bump_system.gd`:                             | `scripts/combat/bump_system.gd`      |
|     |                                   | - `compute_bump(mover_pos, target_pos, move_dir, grid_state) → Dict`|                                      |
|     |                                   | - Returns: {player_final_pos, enemy_final_pos, collision_damage,    |                                      |
|     |                                   |   bump_blocked:bool}                                                |                                      |
|     |                                   | - Checks is_immovable flag, wall/obstacle/enemy at push destination |                                      |
|     |                                   | - Emits bump_occurred signal                                        |                                      |
| A.3 | Integrate bump into movement      | Modify `grid_movement.gd`:                                          | `scripts/combat/grid_movement.gd`    |
|     |                                   | - Enemy tiles are valid destinations (not blocked for pathfinding)  |                                      |
|     |                                   | - On arrival at enemy tile, delegate to BumpSystem                  |                                      |
|     |                                   | - Apply collision damage via combat_manager                         |                                      |
|     |                                   | - Update grid overlay to show enemy tiles as bumpable (orange tint) |                                      |

**Commits:**
```
A.1  test(bump): add bump displacement system unit tests
A.2  feat(bump): implement BumpSystem with collision damage
A.3  feat(bump): integrate bump into grid movement and pathfinding
```

---

#### Workstream B: Escalating Stamina + Energy Orbs

**Dependencies**: Phase 0 (base stamina 80)
**Can parallelize with**: A, C, D

| #   | Task                              | Description                                                         | Output                               |
|-----|-----------------------------------|---------------------------------------------------------------------|--------------------------------------|
| B.1 | Test energy orb system            | Write `tests/test_energy_orb.gd`:                                   | `tests/test_energy_orb.gd`           |
|     |                                   | - Orb spawns at grid position with value 20                         |                                      |
|     |                                   | - Orb collected when player moves onto tile → +20 stamina           |                                      |
|     |                                   | - Orb expires after 2 turns → removed from grid                     |                                      |
|     |                                   | - Multiple orbs can coexist on different tiles                      |                                      |
| B.2 | Implement EnergyOrbSystem         | Create `scripts/combat/energy_orb_system.gd`:                       | `scripts/combat/energy_orb_system.gd`|
|     |                                   | - `spawn_orb(grid_pos:Vector2i, value:int=20)`                      |                                      |
|     |                                   | - `check_pickup(player_pos:Vector2i) → int` (returns bonus or 0)   |                                      |
|     |                                   | - `tick() → void` (decrement lifetime, remove expired)              |                                      |
|     |                                   | - Signals: orb_spawned, orb_collected, orb_expired                  |                                      |
| B.3 | Test kill bonus                   | Write `tests/test_kill_bonus.gd`:                                   | `tests/test_kill_bonus.gd`           |
|     |                                   | - Enemy death triggers +10 stamina to player                        |                                      |
|     |                                   | - Enemy death spawns orb at death tile                              |                                      |
|     |                                   | - Multiple kills in same turn stack bonuses                         |                                      |
| B.4 | Wire escalating stamina           | Connect signals in combat_manager:                                  | `scripts/combat/combat_manager.gd`   |
|     |                                   | - Enemy death → stamina.add_bonus(10), orb_system.spawn_orb(pos)   |                                      |
|     |                                   | - Player move → orb_system.check_pickup() → stamina.add_bonus()    |                                      |
|     |                                   | - RESOLVE phase → orb_system.tick()                                 |                                      |

**Commits:**
```
B.1  test(orbs): add energy orb spawn, pickup, and expiry tests
B.2  feat(orbs): implement EnergyOrbSystem
B.3  test(stamina): add kill bonus and orb-on-death tests
B.4  feat(stamina): wire escalating stamina into combat flow
```

---

#### Workstream C: New Abilities (Heal, Shove, Slam)

**Dependencies**: Phase 0 (5 ability slots)
**Can parallelize with**: A, B, D

| #   | Task                              | Description                                                         | Output                               |
|-----|-----------------------------------|---------------------------------------------------------------------|--------------------------------------|
| C.1 | Test Heal ability                 | Write `tests/test_ability_heal.gd`:                                 | `tests/test_ability_heal.gd`         |
|     |                                   | - Heal restores 20 HP to player                                    |                                      |
|     |                                   | - Heal does not exceed max HP                                       |                                      |
|     |                                   | - Costs 25 stamina, 3-turn cooldown                                 |                                      |
|     |                                   | - Target mode: SELF                                                 |                                      |
| C.2 | Implement Heal                    | `scripts/combat/abilities/ability_heal.gd` + `ability_heal.tres`    | ability script + resource            |
| C.3 | Test Shove ability                | Write `tests/test_ability_shove.gd`:                                | `tests/test_ability_shove.gd`        |
|     |                                   | - Push adjacent enemy 2 tiles away from player                      |                                      |
|     |                                   | - Direction = player → enemy vector                                 |                                      |
|     |                                   | - If blocked at tile 1: collision damage, enemy stops               |                                      |
|     |                                   | - If blocked at tile 2: collision damage, enemy stops at tile 1     |                                      |
|     |                                   | - Deals 5 base damage + any collision damage                        |                                      |
|     |                                   | - Cannot Shove Heavy (push fails, 5 damage still applies)          |                                      |
|     |                                   | - Costs 20 stamina, 1-turn cooldown                                 |                                      |
| C.4 | Implement Shove                   | `scripts/combat/abilities/ability_shove.gd` + `ability_shove.tres`  | ability script + resource            |
|     |                                   | Reuses BumpSystem.compute_bump() for push logic (2 tile version)    |                                      |
| C.5 | Test Slam ability                 | Write `tests/test_ability_slam.gd`:                                 | `tests/test_ability_slam.gd`         |
|     |                                   | - Damages all adjacent enemies (10 each)                            |                                      |
|     |                                   | - Pushes each 1 tile away from player                               |                                      |
|     |                                   | - If push blocked: +5 collision damage                              |                                      |
|     |                                   | - Heavy: damage applies (10), push fails, +5 collision              |                                      |
|     |                                   | - Costs 35 stamina, 2-turn cooldown                                 |                                      |
| C.6 | Implement Slam                    | `scripts/combat/abilities/ability_slam.gd` + `ability_slam.tres`    | ability script + resource            |
| C.7 | Replace Guard, update loadout     | Remove `ability_guard.gd` + `ability_guard.tres`                    | Updated combat_manager, removed files|
|     |                                   | Remove `is_guarding` logic from damage resolution                   |                                      |
|     |                                   | Set loadout: [Strike, Dash, Heal, Shove, Slam]                     |                                      |

**Commits:**
```
C.1  test(abilities): add Heal ability tests
C.2  feat(abilities): implement Heal ability
C.3  test(abilities): add Shove ability tests (push 2 tiles + collision)
C.4  feat(abilities): implement Shove ability
C.5  test(abilities): add Slam ability tests (AOE + push)
C.6  feat(abilities): implement Slam ability
C.7  refactor(abilities): replace Guard with Heal, set 5-ability loadout
```

---

#### Workstream D: New Enemy Types (Heavy, Puller)

**Dependencies**: Phase 0 (is_immovable flag)
**Can parallelize with**: A, B, C

| #   | Task                              | Description                                                         | Output                               |
|-----|-----------------------------------|---------------------------------------------------------------------|--------------------------------------|
| D.1 | Extend telegraph types            | Add `telegraph_type` field (DAMAGE=0, PULL=1) to telegraph data     | `scripts/combat/telegraph_system.gd` |
|     |                                   | Test: DAMAGE telegraph applies damage as before                     | `tests/test_telegraph_system.gd`     |
|     |                                   | Test: PULL telegraph moves player toward source, no damage          |                                      |
|     |                                   | Test: PULL resolves before DAMAGE in same resolve phase             |                                      |
|     |                                   | Test: PULL blocked by obstacle (player stops early)                 |                                      |
| D.2 | Test Heavy AI                     | Write `tests/test_heavy_ai.gd`:                                     | `tests/test_heavy_ai.gd`            |
|     |                                   | - Moves 1 tile/turn toward player (slow chase)                      |                                      |
|     |                                   | - is_immovable = true on its CombatStatsResource                    |                                      |
|     |                                   | - Telegraphs cross (+) pattern centered on player: 5 tiles, 25 dmg  |                                      |
|     |                                   | - Cross clamped to grid bounds                                      |                                      |
| D.3 | Implement Heavy AI                | Create `scripts/combat/ai/heavy_ai.gd`:                             | `scripts/combat/ai/heavy_ai.gd`     |
|     |                                   | - Extends EnemyGridAI                                               |                                      |
|     |                                   | - compute_intent(): slow chase + cross telegraph                    |                                      |
|     |                                   | - Sets is_immovable on initialization                               |                                      |
| D.4 | Test Puller AI                    | Write `tests/test_puller_ai.gd`:                                    | `tests/test_puller_ai.gd`           |
|     |                                   | - Maintains distance ≥ 3 from player (retreat if closer)            |                                      |
|     |                                   | - Telegraphs 3×3 PULL zone centered on player position              |                                      |
|     |                                   | - Pull moves player 2 tiles toward Puller position                  |                                      |
|     |                                   | - Pull type = PULL (not DAMAGE)                                     |                                      |
| D.5 | Implement Puller AI               | Create `scripts/combat/ai/puller_ai.gd`:                            | `scripts/combat/ai/puller_ai.gd`    |
|     |                                   | - Extends EnemyGridAI                                               |                                      |
|     |                                   | - compute_intent(): maintain distance + pull telegraph              |                                      |
|     |                                   | - telegraph_type = PULL, pull_distance = 2, pull_source = self_pos  |                                      |

**Commits:**
```
D.1  feat(telegraph): add PULL type with resolve-before-damage ordering
D.2  test(ai): add Heavy enemy AI tests (immovable, cross telegraph)
D.3  feat(ai): implement Heavy enemy AI
D.4  test(ai): add Puller enemy AI tests (maintain distance, pull zone)
D.5  feat(ai): implement Puller enemy AI with forced movement
```

---

### Merge Phase: Room Progression + Integration

**Dependencies**: Workstreams A, B, C, D (all complete)

| #   | Task                              | Description                                                         | Output                               |
|-----|-----------------------------------|---------------------------------------------------------------------|--------------------------------------|
| M.1 | Room sequencer                    | Create `scripts/combat/room_sequencer.gd`:                          | `room_sequencer.gd`                  |
|     |                                   | - Stores 3 room configs: grid_size, obstacles, enemy_composition    |                                      |
|     |                                   | - Signals: room_started, room_cleared, run_completed, run_failed    |                                      |
|     |                                   | - On room_cleared: advance to next room or emit run_completed       |                                      |
|     |                                   | - On player death: emit run_failed                                  |                                      |
| M.2 | Room configurations               | Define 3 room configs (resource files or dictionaries):             | Room config data                     |
|     |                                   | - Room 1: 6×6, 6-8 obstacles, [Brute, Brute, Caster]               |                                      |
|     |                                   | - Room 2: 7×7, 8-10 obstacles, [Brute, Flanker, Heavy]             |                                      |
|     |                                   | - Room 3: 8×8, 10-12 obstacles, [Heavy, Puller, Flanker, Flanker]  |                                      |
|     |                                   | - Obstacle positions hand-designed per room                         |                                      |
| M.3 | Integrate all v2 systems          | Wire into combat_manager.gd:                                        | `combat_manager.gd` (major update)   |
|     |                                   | - BumpSystem into movement flow                                     |                                      |
|     |                                   | - EnergyOrbSystem into kill/move/resolve hooks                      |                                      |
|     |                                   | - New abilities (Heal, Shove, Slam) into ability execution          |                                      |
|     |                                   | - Heavy/Puller AI into enemy spawning + archetype detection         |                                      |
|     |                                   | - PULL telegraph resolution into resolve phase                      |                                      |
|     |                                   | - Variable grid size from room config                               |                                      |
| M.4 | Update HUD for 5 abilities        | Expand combat_hud.gd:                                               | `combat_hud.gd`, `combat_hud.tscn`  |
|     |                                   | - 5 ability buttons (adjust size/spacing to fit 480px width)        |                                      |
|     |                                   | - Show orb count or indicator on HUD                                |                                      |
|     |                                   | - Room indicator (1/3, 2/3, 3/3)                                    |                                      |
| M.5 | Victory/defeat screens            | Create `scripts/ui/game_result_screen.gd`:                          | `game_result_screen.gd` + `.tscn`   |
|     |                                   | - "VICTORY" after Room 3 cleared                                    |                                      |
|     |                                   | - "DEFEAT" on player death                                          |                                      |
|     |                                   | - Buttons: "Retry" (Room 1), "Menu"                                 |                                      |
|     |                                   | - Wire to room_sequencer signals                                    |                                      |
| M.6 | Integration test                  | Write `tests/test_full_run.gd`:                                     | `tests/test_full_run.gd`            |
|     |                                   | - Verify Room 1 loads at 6×6 with correct enemies                   |                                      |
|     |                                   | - Verify Room 2 loads at 7×7 after Room 1 cleared                   |                                      |
|     |                                   | - Verify Room 3 loads at 8×8 after Room 2 cleared                   |                                      |
|     |                                   | - Verify victory after Room 3 cleared                               |                                      |
|     |                                   | - Verify defeat screen on player death                              |                                      |

**Commits:**
```
M.1  feat(rooms): add RoomSequencer for 3-room progression
M.2  feat(rooms): define room configs with scaling grid and enemy compositions
M.3  feat(combat): integrate bump, orbs, new abilities, new enemies into combat manager
M.4  feat(ui): expand HUD to 5 abilities + room indicator
M.5  feat(ui): add victory/defeat screens with retry flow
M.6  test(e2e): verify full 3-room progression and win/lose conditions
```

---

### Polish Phase

**Dependencies**: Merge phase complete

| #   | Task                              | Description                                                         |
|-----|-----------------------------------|---------------------------------------------------------------------|
| P.1 | Bump VFX                         | Screen shake on collision. Orange flash on bumped tile.              |
| P.2 | Energy orb visual                 | Pulsing yellow diamond sprite. Fade-out on expiry.                  |
| P.3 | Pull telegraph visual             | Blue pulsing zone + arrow pointing toward Puller.                   |
| P.4 | Heavy visual distinction          | Larger sprite or distinct color/outline for "immovable" read.       |
| P.5 | Obstacle layouts                  | Hand-design obstacle positions for each room. Test for solvability. |
| P.6 | Balance pass                      | Play 10+ runs. Tune values in Combat Values Reference table.        |

**Commits:**
```
P.1  feat(vfx): add bump collision screen shake and tile flash
P.2  feat(vfx): add energy orb pulsing visual and expiry fade
P.3  feat(vfx): add pull telegraph blue zone with directional arrow
P.4  feat(vfx): add Heavy enemy visual distinction
P.5  feat(rooms): hand-design obstacle layouts for 3 rooms
P.6  chore(balance): tuning pass on stamina, damage, HP values
```

---

## Testing Strategy

### TDD Flow

Every new system follows:
1. **Write test** — define expected behavior as assertions
2. **Run test** — verify it fails (red)
3. **Implement** — write minimum code to pass
4. **Run test** — verify it passes (green)
5. **Commit** — atomic commit with test + implementation

### Test Inventory

| Test File                     | System                  | Key Assertions                                    | New? |
|-------------------------------|-------------------------|---------------------------------------------------|------|
| `test_grid_utils.gd`         | Grid math               | Variable grid sizes (6,7,8), bounds, flood fill   | MOD  |
| `test_turn_manager.gd`       | Phase loop              | PLAYER→RESOLVE→ENEMY order, initial ENEMY phase   | MOD  |
| `test_stamina.gd`            | Stamina resource        | Base 80, refill, add_bonus method                 | MOD  |
| `test_ability_manager.gd`    | Ability state           | 5 slots, cooldowns, stamina validation            | MOD  |
| `test_bump_system.gd`        | Bump displacement       | Open/wall/enemy/Heavy collision scenarios          | NEW  |
| `test_energy_orb.gd`         | Energy orbs             | Spawn, collect (+20), expire after 2 turns        | NEW  |
| `test_kill_bonus.gd`         | Kill rewards            | +10 stamina on kill, orb spawn at death tile      | NEW  |
| `test_ability_heal.gd`       | Heal ability            | Restore 20 HP, cap at max, cost 25, CD 3          | NEW  |
| `test_ability_shove.gd`      | Shove ability           | Push 2 tiles, collision at 1/2, Heavy immune      | NEW  |
| `test_ability_slam.gd`       | Slam ability            | AOE damage, push away, multi-enemy                | NEW  |
| `test_heavy_ai.gd`           | Heavy AI                | Slow chase, cross telegraph, immovable            | NEW  |
| `test_puller_ai.gd`          | Puller AI               | Maintain distance, PULL zone, forced movement     | NEW  |
| `test_telegraph_system.gd`   | Telegraph lifecycle     | PULL type, resolve order (PULL before DAMAGE)     | MOD  |
| `test_brute_ai.gd`           | Brute AI                | Existing tests still pass                         | -    |
| `test_caster_ai.gd`          | Caster AI               | Existing tests still pass                         | -    |
| `test_flanker_ai.gd`         | Flanker AI              | Existing tests still pass                         | -    |
| `test_ability_targeting.gd`  | Target calc             | Existing + new Shove directional                  | MOD  |
| `test_grid_movement.gd`      | Pathfinding             | Enemy tiles as valid destinations                 | MOD  |
| `test_full_run.gd`           | 3-room progression      | Room transitions, win/lose, grid size scaling     | NEW  |

**Target: 20+ test files, 200+ assertions.**

### Verification Checklist

```bash
# Run all unit tests (headless, < 30 seconds total)
cd client
for test in tests/test_*.gd; do
  case "$test" in
    *full_flow*|*interactive*|*visual*|*full_run*) continue ;;
  esac
  echo "=== Running $test ==="
  timeout 10 godot --headless --script "res://$test"
  if [ $? -ne 0 ]; then echo "FAILED: $test"; exit 1; fi
done
echo "All unit tests passed"

# Run integration test
godot --headless --script res://tests/test_full_run.gd

# Verify export still works
godot --headless --export-release "Web" export/web/index.html
```

---

## Commit Strategy

### All Commits (Ordered)

```
Phase 0 — Foundation (3 commits, serial):
  0.1  refactor(grid): parameterize grid size for variable room dimensions
  0.2  refactor(turns): reorder phases to PLAYER→RESOLVE→ENEMY
  0.3  refactor(foundation): base stamina 80, immovable flag, 5 ability slots

Workstream A — Bump (3 commits, parallel with B/C/D):
  A.1  test(bump): add bump displacement system unit tests
  A.2  feat(bump): implement BumpSystem with collision damage
  A.3  feat(bump): integrate bump into grid movement and pathfinding

Workstream B — Escalating Stamina (4 commits, parallel with A/C/D):
  B.1  test(orbs): add energy orb spawn, pickup, and expiry tests
  B.2  feat(orbs): implement EnergyOrbSystem
  B.3  test(stamina): add kill bonus and orb-on-death tests
  B.4  feat(stamina): wire escalating stamina into combat flow

Workstream C — New Abilities (7 commits, parallel with A/B/D):
  C.1  test(abilities): add Heal ability tests
  C.2  feat(abilities): implement Heal ability
  C.3  test(abilities): add Shove ability tests
  C.4  feat(abilities): implement Shove ability
  C.5  test(abilities): add Slam ability tests
  C.6  feat(abilities): implement Slam ability
  C.7  refactor(abilities): replace Guard with Heal, set 5-ability loadout

Workstream D — New Enemies (5 commits, parallel with A/B/C):
  D.1  feat(telegraph): add PULL type with resolve-before-damage ordering
  D.2  test(ai): add Heavy enemy AI tests
  D.3  feat(ai): implement Heavy enemy AI
  D.4  test(ai): add Puller enemy AI tests
  D.5  feat(ai): implement Puller enemy AI

Merge — Integration (6 commits, serial after A/B/C/D):
  M.1  feat(rooms): add RoomSequencer for 3-room progression
  M.2  feat(rooms): define room configs with scaling difficulty
  M.3  feat(combat): integrate all v2 systems into combat manager
  M.4  feat(ui): expand HUD to 5 abilities + room indicator
  M.5  feat(ui): add victory/defeat screens with retry flow
  M.6  test(e2e): verify full 3-room progression

Polish (6 commits):
  P.1  feat(vfx): bump collision feedback
  P.2  feat(vfx): energy orb visual
  P.3  feat(vfx): pull telegraph visual
  P.4  feat(vfx): Heavy visual distinction
  P.5  feat(rooms): hand-design obstacle layouts
  P.6  chore(balance): tuning pass
```

**Total: 34 atomic commits.**

### Parallelization Guide

```
Phase 0 is strictly serial (each task builds on previous).

After Phase 0, 4 workstreams run in parallel:
  A (3 commits) ─┐
  B (4 commits) ─┤
  C (7 commits) ─┼── all independent, no cross-dependencies
  D (5 commits) ─┘

Merge phase starts when ALL 4 workstreams complete.
  M.1-M.2 can parallelize (sequencer + room configs are independent)
  M.3 depends on M.1 + M.2
  M.4-M.5 can parallelize with M.3 (UI work is independent of combat wiring)
  M.6 depends on M.3 + M.4 + M.5

Polish can start after M.3 (visual work doesn't need full integration test).
  P.1-P.4 can parallelize (independent VFX tasks)
  P.5 depends on P.6-level playtesting
  P.6 depends on all other polish
```

### Bisectability Rule

Every commit must pass: `cd client && godot --headless --quit` (exits 0).
Test commits must pass their specific test.
No commit may break existing tests that are not being intentionally modified.

---

## Risk Assessment

| Risk                                              | Likelihood | Impact | Mitigation                                                     |
|---------------------------------------------------|------------|--------|----------------------------------------------------------------|
| Turn flow reorder breaks existing tests           | High       | Medium | Phase 0.2 updates all turn_manager tests. Run full suite.      |
| Bump pathfinding makes enemies unreachable        | Medium     | High   | Enemy tiles are destinations, not waypoints. Test edge cases.   |
| Escalating stamina snowballs (one kill = win)     | Medium     | Medium | Base 80 is tight. Kill bonus is only +10. Tune in P.6.         |
| Puller + Caster combo is unfun (unavoidable dmg)  | Medium     | Medium | PULL resolves before DAMAGE, so pull CAN save player. Tune.    |
| Heavy with 70 HP is a slog to kill                | Low        | Medium | Player has 5 abilities. Shove still deals 5 dmg. Tune HP.     |
| 5 abilities don't fit in HUD at 480px width       | Medium     | Low    | Reduce button width or use icon-only buttons. Test in M.4.     |
| Variable grid size breaks isometric rendering     | Low        | High   | CombatGrid already uses grid_to_world formula. Test 6/7/8.     |
| Guard removal makes game too hard (no DR)         | Medium     | Medium | Heal compensates. 20 HP/use, CD 3. Tune amount in P.6.        |
| Room 3 (4 enemies, 8×8) is too chaotic            | Low        | Medium | Hand-design obstacle layout (P.5) to create natural zones.     |

---

## Decision Log

| Decision                                       | Rationale                                                  | Alternatives Considered                  |
|------------------------------------------------|------------------------------------------------------------|------------------------------------------|
| Expression-heavy over puzzle-heavy             | User preference. Multiple valid solutions > one correct.   | Pure ItB puzzle, AotA full movement-atk  |
| Hybrid movement (bump, not move-as-attack)     | Movement has consequences but abilities are primary tools. | Full AotA (move=attack), ItB (no bump)   |
| Bump (not swap) displacement model             | More readable than swap. Clear push direction.             | AotA swap, shoulder-check on adjacent    |
| PLAYER→RESOLVE→ENEMY turn order                | Guarantees bump-into-telegraph payoff. No gap.             | Current PLAYER→ENEMY→RESOLVE             |
| Escalating stamina (not flat 100)              | Creates crescendo. Rewards aggression.                     | Flat 100/turn, flat 80/turn, decreasing  |
| Base 80 stamina (down from 100)                | Tight start makes crescendo feel earned.                   | 60 (too tight), 100 (no crescendo)       |
| +10 kill bonus (instant, same turn)            | Enables chain turns. "One more action" feeling.            | +20 (too generous), next-turn-only       |
| +20 orb value, 2-turn lifetime                 | Movement incentive. Must collect actively.                 | +10 (too small), permanent orbs          |
| Heal replaces Guard                            | No between-room healing. Only HP recovery in game.         | Keep Guard + add Heal (6 abilities)      |
| Heal: 20 HP, 25 cost, CD 3                    | ~1 use per 4 turns. Meaningful but not spammable.          | 30 HP/CD 4, 15 HP/CD 2                   |
| Shove pushes 2 tiles (not 1 like bump)         | Distinct from bump. More displacement power.               | 1 tile (same as bump), 3 tiles (OP)      |
| Heavy is immovable                             | Forces direct combat. Creates "wall" enemies.              | Reduced bump (moves 0.5 tiles? No.)      |
| Puller telegraph is PULL not DAMAGE            | Forced movement is a novel threat type.                    | Damage + pull combo (too powerful)        |
| PULL resolves before DAMAGE                    | Creates emergent interactions (pull out of/into damage).   | DAMAGE first (pull is irrelevant)        |
| No chain bumps for prototype                   | Simpler to implement and predict.                          | Full chain (domino effect)               |
| Collision damage = 5 (flat)                    | Simple. Rewards bumping without being primary damage.      | Scaled by HP, 0 (too weak), 10 (too much)|
| Scaling grid: 6→7→8                            | Tighter early rooms, spacious late rooms.                  | Fixed 8×8 (too spacious for 3 enemies)   |
| 3 rooms, no healing between                    | Heal ability creates resource management across run.       | Healing pickups, shop between rooms      |
| Solo hero, squad architecture                  | Playable now. Arrays/dicts, not hardcoded "player".        | Squad now (scope too large)              |
| Draft pool architecture, hardcoded selection   | Future-proofed without building draft UI.                  | Hardcoded only (no architecture)         |
| 5 collision damage to Heavy when bumped INTO   | Gives player bump-chain-into-Heavy as damage strategy.     | 0 damage (boring), full damage (no point)|
| Deterministic AI (no randomness)               | ItB model. Player can predict. Easier to test.             | Weighted random (XCOM-style)             |

---

## Open Questions

- [ ] Should Dash bump enemies it hits, or just damage? (Current: damage only, no bump)
- [ ] Should energy orbs be visible through fog/obstacles, or only when in line of sight?
- [ ] Should the Puller's pull be blocked by other enemies, or pass through them?
  - **Default**: Pass through (only obstacles block). Makes pull more threatening.
- [ ] Should Slam's push interact with bump collision (push enemy A into enemy B = collision)?
  - **Default**: Yes, same collision rules apply. Slam into a cluster = chain collision damage.
- [ ] What happens if Puller pulls player onto an energy orb tile? Auto-collect?
  - **Default**: Yes, auto-collect on any movement (voluntary or forced).
- [ ] Room obstacle layouts: randomly placed or hand-designed?
  - **Default**: Hand-designed for prototype (P.5). Procedural generation is a future feature.
- [ ] Should the 3-room run persist player cooldowns between rooms?
  - **Default**: No, cooldowns reset each room. Stamina resets. Only HP carries over.
- [ ] Post-prototype: add Cleave (cone AOE) and Fireball (radius AOE) to draft pool?
  - **Deferred**: Focus on 5 abilities first.
</pre>
