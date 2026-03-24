# Turn-Based Tactical Combat System — Client Implementation Plan

## Overview

Convert the nezvers/Godot-GameTemplate real-time arena shooter into an Into the Breach–style turn-based tactical combat system running locally in Godot 4.6. When the player enters an arena (`fight_mode` BoolResource becomes true), the game switches from real-time WASD exploration to an 8×8 isometric grid where movement and abilities cost stamina. Enemies telegraph their attacks 1 turn ahead, giving the player one full turn to reposition. All combat logic runs locally in GDScript (offline-first); future onchain integration via Dojo contracts is out of scope for this plan.

## Goals

- Implement complete turn-based combat loop: PLAYER_TURN → ENEMY_TURN → RESOLVE
- Build 8×8 isometric grid overlay aligned with existing 32×16 tile system
- Replace weapon system with 3 abilities: Strike (melee), Dash (movement+damage), Guard (defensive)
- Convert template enemies: Zombie→Brute (melee), Slime→Caster (ranged), create Flanker (from zombie_crawler base)
- Implement Into the Breach–style telegraph system (enemy intents visible 1 turn ahead)
- Implement stamina economy: 100 max, refills each turn, movement=10/tile, abilities=15–30
- Preserve real-time WASD exploration outside combat
- Follow template patterns: ValueResource signals, ResourceNode composition, InstanceResource pooling
- TDD approach: write tests before implementation for all logic systems

## Non-Goals

- Onchain/Dojo contract integration (future plan)
- Dojo bridge, Torii subscriptions, or Cartridge auth
- More than 3 abilities (Cleave and Fireball deferred to post-M1)
- Procedural room generation or multi-room dungeon flow
- Production art pipeline (use existing template sprites + recolors)
- Multiplayer or leaderboard systems
- Save/load of combat state
- Modifying `great_games_library` addon scripts

## Assumptions and Constraints

- **Engine**: Godot 4.6, GDScript only
- **Branch**: `offline` — all combat runs locally
- **Tile system**: 32×16px isometric diamond tiles (TileShape=ISOMETRIC, TileLayout=STAGGERED)
- **Grid size**: 8×8 = 64 tiles. Obstacles cover ~20 tiles (~30% coverage)
- **Addon rules**: Do NOT modify `great_games_library`. MAY modify `top_down` addon scripts where necessary (it's the game template, not a library)
- **No new autoloads**: Follow template convention of passing resources through scenes
- **fight_mode BoolResource**: Existing combat trigger; ArenaStarter sets true on body_entered
- **Damage chain**: All damage flows through DamageDataResource.process() → HealthResource.add_hp()
- **AStarGrid2D**: Available via template's AstarGridResource wrapper
- **Task granularity**: Each task completable in 1–3 file operations with concrete outputs
- **Collision polygon**: Isometric diamond `PackedVector2Array(-16, 0, 0, 8, 16, 0, 0, -8)`

## Requirements

### Functional

- Player can move on grid tiles during PLAYER_TURN (click or WASD), costing 10 stamina per tile (Manhattan distance)
- Player can use 3 abilities with distinct targeting modes:
  - **Strike**: melee, range=1, adjacent tiles only, costs 20 stamina, deals 15 damage
  - **Dash**: line movement up to 3 tiles + hit at destination, costs 25 stamina, deals 10 damage
  - **Guard**: self-buff, costs 15 stamina, reduces next incoming damage by 50% for 1 turn
- Stamina (100 max) refills fully at start of each player turn
- Player can perform multiple actions per turn as long as stamina allows
- "End Turn" button (or key) advances to ENEMY_TURN
- Enemies telegraph attack zones during ENEMY_TURN (red overlay tiles)
- Telegraphed attacks resolve at start of NEXT ENEMY_TURN
- Enemy AI is deterministic:
  - Brute: move 1 tile toward player (shorter axis, X tiebreak), telegraph melee if adjacent
  - Caster: if distance < 3 retreat 1 tile, else stay; telegraph 3×3 AOE on player position
  - Flanker: move toward position behind player (opposite of player's last move), telegraph melee if adjacent
- Combat ends when all enemies are dead → fight_mode=false, doors open
- Combat fails when player HP reaches 0 → game over screen
- Real-time WASD exploration preserved outside combat

### Non-Functional

- Grid overlay renders at 60fps with no visual hitching during turns
- Turn transitions complete within 0.5s (no long waits)
- All combat logic is deterministic (same state → same outcome, no randomness in AI)
- Ability damage uses template DamageDataResource chain (compatibility with existing VFX/SFX)
- Each phase of implementation produces a runnable game (incremental buildability)
- Code follows template naming conventions (PascalCase classes, snake_case files)

## Technical Design

### Data Model — New Resources

```
StaminaResource (extends ValueResource)
├── value: int = 100
├── max_value: int = 100
├── Signals: stamina_spent(cost), stamina_refilled, stamina_depleted
├── Methods: spend(cost) → bool, can_spend(cost) → bool, refill()
└── Pattern: mirrors IntResource but with clamping + spend/refill semantics

CombatStatsResource (extends SaveableResource)
├── grid_pos: Vector2i = Vector2i(-1, -1)  # current grid position
├── faction: int = 0  # 0=player, 1=enemy
├── archetype: int = 0  # 0=player, 1=brute, 2=caster, 3=flanker
├── move_range: int = 10  # max tiles per turn (stamina/10)
├── is_guarding: bool = false  # Guard active?
├── guard_reduction: float = 0.5  # damage reduction when guarding
├── Signals: position_changed(old, new), guard_changed(active)
└── Pattern: attached to each actor via ResourceNode

AbilityResource (extends Resource)
├── ability_name: String
├── ability_id: int  # 0=Strike, 1=Dash, 2=Guard
├── stamina_cost: int
├── cooldown_turns: int
├── current_cooldown: int = 0
├── target_mode: int  # 0=ADJACENT, 1=LINE, 2=SELF
├── range_tiles: int
├── base_damage: float
├── icon: Texture2D
├── description: String
└── Methods: can_use(stamina) → bool, start_cooldown(), tick_cooldown()
```

### Architecture — Scene Tree During Combat

```
Room (existing room_template.tscn instance)
├── Background/
│   ├── FloorLayer (existing TileMapLayer, 32×16 iso)
│   └── ObstacleLayer (existing TileMapLayer + StaticBody2D)
├── CombatGrid (NEW — Node2D, added as child of Room)
│   ├── GridOverlay (TileMapLayer — walkable/danger/selected/range tiles)
│   ├── GridCursor (Sprite2D — hover highlight on current mouse tile)
│   └── TelegraphOverlay (TileMapLayer — enemy intent zones, red with pulse)
├── YSortedLayer/
│   ├── Player (existing CharacterBody2D, MoverTopDown2D DISABLED)
│   └── Enemies (existing actors, BotInput DISABLED, GridAI ENABLED)
├── CombatManager (NEW — Node, added as child of Room)
│   ├── TurnManager (NEW — Node, phase state machine)
│   ├── GridMovement (NEW — Node, handles player grid movement)
│   ├── AbilityManager (NEW — Node, holds 3 abilities)
│   ├── AbilityTargeting (NEW — Node, tile selection + preview)
│   ├── TelegraphSystem (NEW — Node, computes + displays telegraphs)
│   └── EnemyTurnResolver (NEW — Node, executes AI + resolves telegraphs)
├── CombatTransition (NEW — Node, hooks fight_mode → enable/disable systems)
├── GameHUD (existing CanvasLayer)
│   └── CombatHUD (NEW — Control, ability buttons + stamina bar + phase indicator)
└── [existing nodes: MainCamera, ScreenEffects, EnemyManager, etc.]
```

### Key Integration Points

| Existing System | Integration Method | Notes |
|---|---|---|
| `fight_mode` BoolResource | CombatTransition listens to `changed_true`/`changed_false` | Entry/exit hook for combat mode |
| `MoverTopDown2D` | Call `set_enabled_process(false)` on combat enter, `(true)` on exit | Disables real-time movement |
| `PlayerInput` | Call `set_enabled(false)` on combat enter, `(true)` on exit | Disables real-time input |
| `BotInput` | Call `set_enabled(false)` on combat enter | Disables real-time AI |
| `HealthResource` | Reuse directly — abilities deal damage via `add_hp(-dmg)` | Signals: `damaged`, `dead`, `hp_changed` |
| `DamageDataResource` | Create instances per ability, call `.process(target_resource_node)` | Preserves flash VFX, damage numbers, knockback |
| `ActorDamage` | Already listens to `health_resource.damaged`/`.dead` | Plays damage VFX/sounds automatically |
| `ActiveEnemy` | Reuse for enemy lifecycle tracking | `remove_self()` on death decrements enemy_count |
| `EnemyWaveManager` | Reuse `enemy_count_resource` for combat end detection | When count=0 → sets fight_mode=false |
| `AstarGridResource` | Reuse wrapper for pathfinding within 8×8 grid | Set solid cells for obstacles + occupied tiles |
| `ResourceNode` | Add `stamina` and `combat_stats` resources to player/enemy ResourceNodes | Follow existing pattern: `resource_node.get_resource("stamina")` |

### UX Flow

```
EXPLORATION (real-time WASD)
    │
    ▼ [Player enters ArenaStarter Area2D]
    │
fight_mode = true → CombatTransition activates
    │
    ├── Disable MoverTopDown2D, PlayerInput, BotInput
    ├── Snap player to nearest grid tile center
    ├── Spawn CombatGrid overlay (8×8)
    ├── Place enemies on grid tiles
    ├── Show CombatHUD (hide weapon HUD)
    └── Start TurnManager
          │
          ▼
    ┌─────────────────────────────────┐
    │         PLAYER_TURN             │
    │  • Stamina refills to 100       │
    │  • Resolve previous telegraphs  │
    │  • Show reachable tiles (blue)  │
    │  • Player clicks to move / aim  │
    │  • Player uses abilities        │
    │  • "End Turn" → next phase      │
    └────────────┬────────────────────┘
                 ▼
    ┌─────────────────────────────────┐
    │         ENEMY_TURN              │
    │  • Each enemy computes AI move  │
    │  • Enemies animate movement     │
    │  • Enemies create telegraphs    │
    │  • Show danger zones (red)      │
    │  • Auto-advance when done       │
    └────────────┬────────────────────┘
                 ▼
    ┌─────────────────────────────────┐
    │         RESOLVE                 │
    │  • Check win: all enemies dead? │
    │  • Check lose: player dead?     │
    │  • Tick cooldowns               │
    │  • Increment turn counter       │
    │  • → PLAYER_TURN (loop)         │
    └────────────┬────────────────────┘
                 ▼
    [Combat ends]
    │
    ├── fight_mode = false
    ├── Remove CombatGrid overlay
    ├── Re-enable MoverTopDown2D, PlayerInput
    ├── Restore exploration HUD
    └── Open arena doors
```

---

## Implementation Plan

### Task Contract

Every task in this plan follows these rules:
- **1–3 tool calls** maximum (file write/edit operations)
- **Concrete file outputs** listed explicitly
- **TDD**: logic tasks start with a test file; test runs RED first, then GREEN after implementation
- **Verification**: every task has a command to confirm success
- **Atomic commit**: one commit per task with a descriptive message
- **Incremental**: each phase produces a runnable project (`godot --headless --quit` exits 0)

### Test Harness Pattern

All logic tests use this pattern (no external test framework):
```gdscript
# tests/test_example.gd
extends SceneTree
func _init() -> void:
    var pass_count := 0
    var fail_count := 0
    # --- Test 1 ---
    if condition:
        pass_count += 1; print("  PASS: description")
    else:
        fail_count += 1; print("  FAIL: description — expected X, got Y")
    # --- Summary ---
    print("\n%d passed, %d failed" % [pass_count, fail_count])
    quit(1 if fail_count > 0 else 0)
```
Run: `cd client && godot --headless --script res://tests/test_example.gd`

---

### Serial Dependencies (Must Complete First)

#### Phase 0: Foundation
**Prerequisite for:** All subsequent workstreams

| # | Description | Output Files | Verification | Commit |
|---|-------------|-------------|--------------|--------|
| 0.1 | Create game-specific folder structure. All new code lives outside addons. | Directories: `scripts/combat/`, `scripts/combat/abilities/`, `scripts/combat/ai/`, `scripts/resources/`, `scripts/ui/`, `scenes/combat/`, `resources/combat/`, `tests/` | `ls client/scripts/combat client/tests client/resources/combat` — all exist | `chore: scaffold combat folder structure` |
| 0.2 | Create combat enums: Phase, Faction, Archetype, TargetMode, AbilityID. Standalone autoload-free const class. | `scripts/combat/combat_enums.gd` | `godot --headless --quit` exits 0 | `feat(combat): add combat enum constants` |
| 0.3 | Create StaminaResource extending ValueResource. Properties: `value:int`, `max_value:int`. Methods: `spend(cost)->bool`, `can_spend(cost)->bool`, `refill()`. Signals: `stamina_spent(cost)`, `stamina_refilled`, `stamina_depleted`. Clamps value to [0, max_value]. | `scripts/resources/stamina_resource.gd` | `godot --headless --quit` exits 0 | `feat(combat): add StaminaResource with spend/refill` |
| 0.4 | Write TDD tests for StaminaResource: initial value=100, spend(20)→value=80, spend(90)→false (insufficient), refill()→100, signals emitted correctly. | `tests/test_stamina.gd` | `godot --headless --script res://tests/test_stamina.gd` exits 0, prints "X passed, 0 failed" | `test(combat): add StaminaResource unit tests` |
| 0.5 | Create CombatStatsResource extending SaveableResource. Properties: `grid_pos:Vector2i`, `faction:int`, `archetype:int`, `move_range:int`, `is_guarding:bool`, `guard_reduction:float`. Signals: `position_changed(old_pos, new_pos)`, `guard_changed(active)`. | `scripts/resources/combat_stats_resource.gd` | `godot --headless --quit` exits 0 | `feat(combat): add CombatStatsResource for grid actors` |
| 0.6 | Create AbilityResource extending Resource. Properties: `ability_name:String`, `ability_id:int`, `stamina_cost:int`, `cooldown_turns:int`, `current_cooldown:int`, `target_mode:int`, `range_tiles:int`, `base_damage:float`, `description:String`. Methods: `can_use(current_stamina)->bool`, `start_cooldown()`, `tick_cooldown()`. | `scripts/resources/ability_resource.gd` | `godot --headless --quit` exits 0 | `feat(combat): add AbilityResource data class` |
| 0.7 | Create 3 ability .tres instances using AbilityResource. Strike: cost=20, cooldown=0, target_mode=ADJACENT, range=1, damage=15. Dash: cost=25, cooldown=1, target_mode=LINE, range=3, damage=10. Guard: cost=15, cooldown=2, target_mode=SELF, range=0, damage=0. | `resources/combat/ability_strike.tres`, `resources/combat/ability_dash.tres`, `resources/combat/ability_guard.tres` | `godot --headless --quit` exits 0 (resources load) | `feat(combat): add Strike, Dash, Guard ability resources` |
| 0.8 | Create GridUtils static class. Methods: `world_to_grid(world_pos, tile_map_layer)->Vector2i` (wraps `local_to_map`), `grid_to_world(grid_pos, tile_map_layer)->Vector2` (wraps `map_to_local`), `manhattan_distance(a, b)->int`, `get_adjacent_cells(pos)->Array[Vector2i]`, `is_in_bounds(pos, grid_size)->bool`, `flood_fill_reachable(start, max_cost, blocked_cells, grid_size)->Dictionary` (returns {cell: cost}). | `scripts/combat/grid_utils.gd` | `godot --headless --quit` exits 0 | `feat(combat): add GridUtils static coordinate/pathfinding helpers` |
| 0.9 | Write TDD tests for GridUtils: manhattan_distance((0,0),(3,4))=7, is_in_bounds((7,7), 8)=true, is_in_bounds((8,0), 8)=false, get_adjacent_cells((3,3)) returns 4 cells, flood_fill with no obstacles from center reaches correct tile count, flood_fill with blocked cell excludes it. | `tests/test_grid_utils.gd` | `godot --headless --script res://tests/test_grid_utils.gd` exits 0 | `test(combat): add GridUtils unit tests` |

---

### Parallel Workstreams

These workstreams can be executed independently after Phase 0.

#### Workstream A: Combat Grid + Turn System
**Dependencies:** Phase 0 (all tasks)
**Can parallelize with:** Workstreams B, C

This workstream builds the spatial grid, turn state machine, and mode transition.

| # | Description | Output Files | Verification | Commit |
|---|-------------|-------------|--------------|--------|
| A.1 | **CombatGrid scene**: Node2D with a child TileMapLayer (`GridOverlay`) configured to match existing isometric settings (32×16, diamond, staggered). The overlay uses 5 tile source IDs drawn programmatically at runtime via `_draw()` (colored diamonds): 0=walkable(blue,0.3α), 1=selected(yellow,0.5α), 2=danger(red,0.4α), 3=move_range(green,0.3α), 4=ability_range(purple,0.3α). Methods: `show_grid(origin:Vector2i, size:Vector2i)`, `hide_grid()`, `set_cell_state(pos, state)`, `clear_overlay()`, `highlight_cells(cells:Array[Vector2i], state:int)`. Stores grid_origin and grid_size. | `scripts/combat/combat_grid.gd`, `scenes/combat/combat_grid.tscn` | `godot --headless --quit` exits 0; scene instantiates without error | `feat(combat): add CombatGrid with isometric overlay` |
| A.2 | **GridCursor**: Sprite2D child of CombatGrid. Follows mouse position snapped to grid tiles via `GridUtils.world_to_grid()`. Shows yellow diamond highlight on hovered tile. Emits `tile_hovered(pos:Vector2i)` and `tile_clicked(pos:Vector2i)` signals. Respects grid bounds (only highlights valid tiles). Uses `_unhandled_input` for click detection. | `scripts/combat/grid_cursor.gd` (attached to Sprite2D in combat_grid.tscn) | Create `scenes/combat/test_grid_cursor.tscn` with CombatGrid + floor tilemap. Launch: `godot scenes/combat/test_grid_cursor.tscn`. Mouse hover shows yellow tile, click prints pos. | `feat(combat): add GridCursor with tile hover/click` |
| A.3 | **TurnManager**: Await-based coroutine state machine. Enum: IDLE, PLAYER_TURN, ENEMY_TURN, RESOLVE, COMBAT_OVER. Signals: `phase_changed(phase)`, `player_turn_started`, `enemy_turn_started`, `resolve_started`, `combat_ended(player_won)`. Methods: `start_combat()` begins the loop, `end_player_turn()` called by player (emits internal signal to advance), `_run_combat_loop()` async coroutine cycling phases. On RESOLVE: checks win/loss, ticks cooldowns, increments turn_count, loops or ends. | `scripts/combat/turn_manager.gd` | `godot --headless --script res://tests/test_turn_manager.gd` exits 0 | `feat(combat): add TurnManager with phase coroutine loop` |
| A.4 | **TurnManager TDD tests**: Test phase transitions: start→PLAYER_TURN, end_player_turn→ENEMY_TURN, after enemy phase→RESOLVE, resolve loops to PLAYER_TURN. Test combat_ended emitted when win/lose conditions met. Test turn_count increments each cycle. | `tests/test_turn_manager.gd` | `godot --headless --script res://tests/test_turn_manager.gd` exits 0 | `test(combat): add TurnManager phase transition tests` |
| A.5 | **GridMovement**: Handles player movement on grid. On PLAYER_TURN: computes reachable cells via `GridUtils.flood_fill_reachable()` using remaining stamina÷10. Highlights reachable cells (green overlay). On tile_clicked: if reachable, animates player to target (tween lerp 0.15s per tile along path), deducts stamina (manhattan_distance×10), updates CombatStatsResource.grid_pos, clears/recomputes overlay. Uses AStarGrid2D for path smoothing. Signals: `move_completed(from, to)`, `move_cancelled`. | `scripts/combat/grid_movement.gd` | `godot --headless --script res://tests/test_grid_movement.gd` exits 0 | `feat(combat): add GridMovement with stamina-based reachability` |
| A.6 | **GridMovement TDD tests**: Test reachable cells with 100 stamina (10 tiles in each direction from center), reachable shrinks with 30 stamina (3 tiles), blocked cells excluded, occupied cells excluded, stamina deducted correctly (move 3 tiles = 30 stamina), can't move with 0 stamina. | `tests/test_grid_movement.gd` | `godot --headless --script res://tests/test_grid_movement.gd` exits 0 | `test(combat): add GridMovement reachability tests` |
| A.7 | **CombatTransition**: Listens to `fight_mode` BoolResource. On `changed_true`: (1) find player node → call `MoverTopDown2D.set_enabled_process(false)` and `PlayerInput.set_enabled(false)`, (2) snap player to nearest grid tile, (3) instance CombatGrid as child of Room, (4) find enemies → disable `BotInput`, place on grid tiles, (5) instance CombatManager, (6) show CombatHUD, (7) call `TurnManager.start_combat()`. On `changed_false`: reverse all — destroy CombatGrid + CombatManager, re-enable real-time systems. | `scripts/combat/combat_transition.gd` | Add to existing room scene. Walk into ArenaStarter → verify: movement stops, grid appears, combat starts. Walk-through verification in editor. | `feat(combat): add CombatTransition hooking fight_mode` |

#### Workstream B: Ability System
**Dependencies:** Phase 0 (all tasks)
**Can parallelize with:** Workstreams A, C

This workstream replaces the weapon system with grid-targeted abilities.

| # | Description | Output Files | Verification | Commit |
|---|-------------|-------------|--------------|--------|
| B.1 | **AbilityManager**: Holds Array[AbilityResource] (3 abilities). Methods: `select_ability(index)`, `get_selected()->AbilityResource`, `use_ability(target_data:Dictionary)->bool` (checks stamina, applies cooldown, returns success), `tick_cooldowns()` (called at RESOLVE phase). Signals: `ability_selected(ability)`, `ability_used(ability, target_data)`, `ability_cancelled`. Reads StaminaResource from player's ResourceNode. | `scripts/combat/ability_manager.gd` | `godot --headless --script res://tests/test_ability_manager.gd` exits 0 | `feat(combat): add AbilityManager with selection and stamina` |
| B.2 | **AbilityManager TDD tests**: Test: select_ability(0) sets selected, use_ability deducts stamina, use_ability with insufficient stamina returns false, cooldown prevents use for N turns, tick_cooldowns reduces cooldown, all 3 abilities have correct costs. | `tests/test_ability_manager.gd` | `godot --headless --script res://tests/test_ability_manager.gd` exits 0 | `test(combat): add AbilityManager unit tests` |
| B.3 | **AbilityTargeting**: Computes valid target tiles per ability's target_mode. ADJACENT: 4 tiles around player within range (exclude blocked/OOB). LINE: 4 directional lines from player up to range (stop at blocked). SELF: player's own tile only. Highlights valid tiles (purple overlay). On mouse hover: shows preview shape. On click in valid tile: emits `target_confirmed(ability, cells:Array[Vector2i])`. On right-click/Esc: `target_cancelled`. | `scripts/combat/ability_targeting.gd` | Create test scene with grid + player + ability selection. Verify: selecting Strike shows 4 adjacent tiles, Dash shows 4 lines, Guard shows own tile. | `feat(combat): add AbilityTargeting with valid tile computation` |
| B.4 | **AbilityTargeting TDD tests**: Test valid tiles for each mode: ADJACENT at (4,4) returns [(3,4),(5,4),(4,3),(4,5)], ADJACENT at (0,0) returns only (1,0) and (0,1) (bounds check), LINE at (4,4) range=3 returns 4 lines of 3 cells each, LINE blocked at (4,2) stops north line at (4,3), SELF at (4,4) returns [(4,4)]. | `tests/test_ability_targeting.gd` | `godot --headless --script res://tests/test_ability_targeting.gd` exits 0 | `test(combat): add AbilityTargeting valid tile tests` |
| B.5 | **Strike ability effect**: On target_confirmed with Strike → deal 15 damage to enemy occupying target cell. Create DamageDataResource with base_damage=[{type=0, value=15}], critical_chance=0. Find enemy at cell via CombatStatsResource.grid_pos lookup. Call `damage_data.process(enemy_resource_node)`. This triggers the full template damage chain (flash, sounds, HP bar update, death). Emit `ability_resolved(ability, targets_hit)`. | `scripts/combat/abilities/ability_strike.gd` | Test in scene: Strike adjacent enemy → floating damage number appears, HP decreases by 15. | `feat(combat): implement Strike ability with template damage chain` |
| B.6 | **Dash ability effect**: On target_confirmed with Dash (directional line) → move player along the line to the farthest unoccupied tile (tween 0.1s/tile). If an enemy occupies the destination+1 cell, deal 10 damage to it. Update CombatStatsResource.grid_pos. If line is fully blocked (first tile occupied), dash fails (refund stamina). Uses same DamageDataResource.process() for damage. | `scripts/combat/abilities/ability_dash.gd` | Test: Dash north 3 tiles → player moves, enemy at end takes 10 damage. Dash into wall → stops at wall. | `feat(combat): implement Dash ability with movement + impact` |
| B.7 | **Guard ability effect**: On use → set player's `CombatStatsResource.is_guarding = true`. During damage resolution, if `is_guarding`, multiply incoming damage by `(1.0 - guard_reduction)` = 0.5. Guard clears at start of next PLAYER_TURN. Integration: modify damage flow to check `is_guarding` before applying — hook into HealthResource or create a DamageModifier node that intercepts `DamageResource.report_damage`. | `scripts/combat/abilities/ability_guard.gd` | Test: Guard → take 20 damage → only 10 HP lost. Next turn: Guard expires → take 20 → lose 20 HP. | `feat(combat): implement Guard ability with damage reduction` |

#### Workstream C: Enemy AI + Telegraphs
**Dependencies:** Phase 0 (all tasks)
**Can parallelize with:** Workstreams A, B

This workstream implements deterministic enemy behavior and the telegraph preview system.

| # | Description | Output Files | Verification | Commit |
|---|-------------|-------------|--------------|--------|
| C.1 | **EnemyGridAI base**: Abstract class for grid-based enemy decision-making. Method: `compute_intent(self_pos:Vector2i, player_pos:Vector2i, grid_state:Dictionary) -> Dictionary`. Returns `{move_to: Vector2i, telegraph_cells: Array[Vector2i], telegraph_damage: float}`. Grid state dictionary includes: blocked_cells, occupied_cells, grid_size. Each archetype subclass overrides `compute_intent`. | `scripts/combat/enemy_grid_ai.gd` | `godot --headless --quit` exits 0 | `feat(combat): add EnemyGridAI base class` |
| C.2 | **BruteAI** (Zombie→Brute): HP=50, move_range=1. `compute_intent`: (1) find closest tile toward player (manhattan, pick shorter axis, X-axis tiebreak), (2) if new position adjacent to player → telegraph = [player_pos], damage=20, (3) else telegraph = [] (didn't reach). Move toward player by reducing the axis with larger distance first. | `scripts/combat/ai/brute_ai.gd` | `godot --headless --script res://tests/test_brute_ai.gd` exits 0 | `feat(combat): implement BruteAI (chase + melee telegraph)` |
| C.3 | **BruteAI TDD tests**: Brute at (0,0), player at (3,4) → moves to (1,0) (X shorter). Brute at (1,0), player at (2,0) → moves to (2,0)? No — occupied. moves to (1,1) or stays. Brute at (1,0), player at (0,0) → adjacent → telegraph [(0,0)]. Brute blocked all sides → stays, no telegraph. | `tests/test_brute_ai.gd` | `godot --headless --script res://tests/test_brute_ai.gd` exits 0 | `test(combat): add BruteAI decision tests` |
| C.4 | **CasterAI** (Slime→Caster): HP=30, move_range=1, attack_range=5, AOE=3×3. `compute_intent`: (1) if manhattan_distance < 3 → retreat 1 tile away from player (opposite direction), (2) if distance ≥ 3 → stay, (3) telegraph = 3×3 area centered on player_pos (9 cells, clamped to grid bounds), damage=12. | `scripts/combat/ai/caster_ai.gd` | `godot --headless --script res://tests/test_caster_ai.gd` exits 0 | `feat(combat): implement CasterAI (kite + AOE telegraph)` |
| C.5 | **CasterAI TDD tests**: Caster at (4,4), player at (4,2) (distance=2<3) → retreats to (4,5). Caster at (4,4), player at (4,0) (distance=4≥3) → stays, telegraphs 3×3 around (4,0). Caster at (0,0), player at (0,4) → retreats OOB? → clamps to (0,0) stay. Telegraph near edge clips to grid bounds. | `tests/test_caster_ai.gd` | `godot --headless --script res://tests/test_caster_ai.gd` exits 0 | `test(combat): add CasterAI decision tests` |
| C.6 | **FlankerAI** (zombie_crawler→Flanker): HP=40, move_range=2. `compute_intent`: (1) compute flank_target = player_pos + (player_pos - player_last_move_direction) (behind player), (2) move up to 2 tiles toward flank_target, (3) if adjacent to player after move → telegraph = [player_pos], damage=18 (backstab bonus: +50% if attacking from behind). Fallback: if flank unreachable, behave like Brute (move toward player). | `scripts/combat/ai/flanker_ai.gd` | `godot --headless --script res://tests/test_flanker_ai.gd` exits 0 | `feat(combat): implement FlankerAI (flank + backstab telegraph)` |
| C.7 | **FlankerAI TDD tests**: Player at (4,4) last moved right→(4,4). Flank target is (3,4) (behind). Flanker at (1,4) → moves to (3,4). Now adjacent → telegraphs [(4,4)]. Flanker at (6,4) → flank at (3,4) → moves 2 tiles to (4,4)? Occupied by player → moves to (5,4), not adjacent → no telegraph. Fallback to Brute behavior. | `tests/test_flanker_ai.gd` | `godot --headless --script res://tests/test_flanker_ai.gd` exits 0 | `test(combat): add FlankerAI decision tests` |
| C.8 | **TelegraphSystem**: Manages telegraph display lifecycle. Stores Array of `{cells, damage, source_enemy, turn_created}`. Methods: `add_telegraph(cells, damage, source, turn)`, `get_active_telegraphs()->Array`, `resolve_telegraphs(current_turn)->Array` (returns telegraphs where turn_created < current_turn, removes them), `clear_all()`. Rendering: highlights telegraph cells on CombatGrid's TelegraphOverlay (red, 0.4 alpha for pending, pulses to 1.0 alpha when resolving). | `scripts/combat/telegraph_system.gd` | `godot --headless --script res://tests/test_telegraph_system.gd` exits 0 | `feat(combat): add TelegraphSystem with N→N+1 lifecycle` |
| C.9 | **TelegraphSystem TDD tests**: Add telegraph at turn 1 → active. Resolve at turn 1 → returns nothing (same turn). Resolve at turn 2 → returns telegraph, removes from active. Multiple telegraphs: only resolves matching turn. Clear removes all. | `tests/test_telegraph_system.gd` | `godot --headless --script res://tests/test_telegraph_system.gd` exits 0 | `test(combat): add TelegraphSystem lifecycle tests` |
| C.10 | **EnemyTurnResolver**: Orchestrates enemy phase. Method: `execute_enemy_turn(enemies, turn_manager, telegraph_system, combat_grid) -> void` (async). Steps: (1) resolve previous telegraphs — apply damage to actors standing in telegraph cells, (2) for each living enemy: compute_intent → animate move (tween) → add telegraph to system, (3) update grid overlay with new danger zones, (4) signal `enemy_turn_complete`. Processes enemies sequentially with 0.3s delay between each for visual clarity. | `scripts/combat/enemy_turn_resolver.gd` | Test scene: enemies take turns, damage applies, telegraphs appear. | `feat(combat): add EnemyTurnResolver with sequential execution` |

---

### Merge Phase

After parallel workstreams complete, these tasks integrate all systems.

#### Phase M: Integration + HUD + Polish
**Dependencies:** Workstreams A, B, C (all tasks)

| # | Description | Output Files | Verification | Commit |
|---|-------------|-------------|--------------|--------|
| M.1 | **CombatHUD**: Control node with: (1) StaminaBar (TextureProgressBar bound to StaminaResource.updated), (2) AbilityBar (HBoxContainer with 3 AbilityButton — shows icon, cost, cooldown overlay, selected highlight; click → AbilityManager.select_ability), (3) EndTurnButton (Button → TurnManager.end_player_turn), (4) PhaseIndicator (Label showing "YOUR TURN" / "ENEMY TURN" / "RESOLVING" bound to TurnManager.phase_changed), (5) TurnCounter (Label showing turn number). Positioned at bottom of screen. | `scripts/ui/combat_hud.gd`, `scenes/combat/combat_hud.tscn` | Launch test combat scene → HUD visible, stamina updates on move, abilities clickable, End Turn works, phase text changes. | `feat(ui): add CombatHUD with abilities, stamina, phase indicator` |
| M.2 | **CombatManager** (orchestrator): Composes TurnManager + GridMovement + AbilityManager + AbilityTargeting + TelegraphSystem + EnemyTurnResolver. Wires signals between them. On `player_turn_started`: refill stamina, compute reachable, enable grid input. On `ability_used`: execute effect, update grid. On `enemy_turn_started`: call EnemyTurnResolver.execute_enemy_turn(). On `resolve_started`: tick cooldowns, check win/lose. On `combat_ended`: signal CombatTransition. Manages the grid_state Dictionary (blocked/occupied cells) as single source of truth. | `scripts/combat/combat_manager.gd` | Create `scenes/combat/test_full_combat.tscn` — room with grid, player, 2 enemies. Full combat loop: move, strike, end turn, enemies act, telegraphs show, loop. | `feat(combat): add CombatManager orchestrator wiring all systems` |
| M.3 | **First encounter room**: Duplicate `room_0.tscn` as `room_combat_01.tscn`. Configure: 8×8 grid area within the existing room floor, ~20 obstacle tiles, 3 enemies (1 Brute at grid (6,1), 1 Caster at (5,6), 1 Flanker at (1,5)), player starts at (1,1). Add CombatTransition node. Wire fight_mode_resource. Adjust ArenaStarter trigger area to cover room entry. | `scenes/combat/room_combat_01.tscn` (or modify existing room) | Launch room scene → walk into trigger → combat starts → play full loop → kill all enemies → combat ends → can walk again. | `feat(combat): create first tactical encounter room` |
| M.4 | **Camera + transitions**: On combat start: tween camera to center of 8×8 grid, set zoom to fit entire grid on screen (calculate from grid_size × tile_size vs viewport). On combat end: tween camera back to follow player. Add screen flash on telegraph resolution (reuse template's ScreenEffects). Add 0.3s fade between exploration and combat. | Modify `combat_transition.gd`, add camera logic | Combat start: camera smoothly zooms to grid. Combat end: camera smoothly returns to player follow. | `feat(combat): add camera snap and transition effects` |
| M.5 | **SFX + VFX hooks**: On ability use: play attack VFX at target tile (reuse template's slash/explosion sprites from `addons/top_down/assets/`). On enemy telegraph resolve: play impact VFX + screen shake. On movement: play step sound. On guard: play shield VFX. Wire through template's SoundResource pattern. | Modify ability effect scripts + combat_manager.gd | Abilities play visual and audio feedback. Telegraph resolution has screen shake. | `feat(combat): wire SFX and VFX into combat actions` |
| M.6 | **Balance tuning pass**: Adjust all numeric values in .tres files based on playtesting. Document final values. Target: combat should last 4–6 turns with skilled play. Player should survive 2 unmitigated telegraphs. Each enemy should die in 3–4 Strikes. Stamina should allow ~2 moves + 1 ability per turn. | Modify .tres resource files | Play 5 combat encounters. Verify: game feels fair but challenging, stamina creates meaningful choices. | `chore(combat): balance pass on stamina costs, HP, and damage` |

---

## Testing and Validation

### Unit Tests (headless, automated)
| Test File | What It Tests | Run Command |
|-----------|--------------|-------------|
| `tests/test_stamina.gd` | StaminaResource: spend, refill, can_spend, signals, clamping | `godot --headless --script res://tests/test_stamina.gd` |
| `tests/test_grid_utils.gd` | GridUtils: manhattan, bounds, adjacency, flood_fill, blocked cells | `godot --headless --script res://tests/test_grid_utils.gd` |
| `tests/test_turn_manager.gd` | TurnManager: phase transitions, turn counting, win/lose | `godot --headless --script res://tests/test_turn_manager.gd` |
| `tests/test_grid_movement.gd` | GridMovement: reachable tiles, stamina cost, blocked cells | `godot --headless --script res://tests/test_grid_movement.gd` |
| `tests/test_ability_manager.gd` | AbilityManager: selection, stamina check, cooldowns | `godot --headless --script res://tests/test_ability_manager.gd` |
| `tests/test_ability_targeting.gd` | AbilityTargeting: valid tiles per mode, bounds, blocking | `godot --headless --script res://tests/test_ability_targeting.gd` |
| `tests/test_brute_ai.gd` | BruteAI: chase, melee telegraph, tiebreak, blocked | `godot --headless --script res://tests/test_brute_ai.gd` |
| `tests/test_caster_ai.gd` | CasterAI: kite, retreat, AOE telegraph, edge clamping | `godot --headless --script res://tests/test_caster_ai.gd` |
| `tests/test_flanker_ai.gd` | FlankerAI: flank position, backstab, fallback to brute | `godot --headless --script res://tests/test_flanker_ai.gd` |
| `tests/test_telegraph_system.gd` | TelegraphSystem: add, resolve N+1, clear, multiple | `godot --headless --script res://tests/test_telegraph_system.gd` |

### Run All Tests
```bash
cd client
for test in tests/test_*.gd; do
  echo "=== Running $test ==="
  godot --headless --script "res://$test"
  if [ $? -ne 0 ]; then echo "FAILED: $test"; exit 1; fi
done
echo "All tests passed"
```

### Integration Tests (manual, scene-based)
| Scene | What It Validates |
|-------|-------------------|
| `scenes/combat/test_grid_cursor.tscn` | Grid renders, cursor follows mouse, clicks register |
| `scenes/combat/test_full_combat.tscn` | Full combat loop: move, ability, end turn, enemy turn, telegraphs |
| `scenes/combat/room_combat_01.tscn` | Exploration → combat → win → exploration transition |

### Project Integrity Check
```bash
cd client && godot --headless --quit
# Must exit 0 at every phase of implementation
```

## Verification Checklist

After all tasks complete, verify these end-to-end:

- [ ] `cd client && godot --headless --quit` exits 0
- [ ] All 10 unit test files pass (run all tests script)
- [ ] Launch room_combat_01.tscn → walk freely with WASD
- [ ] Walk into ArenaStarter → combat mode activates
- [ ] Grid overlay appears (8×8 blue tiles, obstacles visible)
- [ ] Reachable tiles highlight green based on stamina
- [ ] Click reachable tile → player lerps to tile, stamina decreases
- [ ] Select Strike → adjacent tiles highlight purple → click enemy → damage applies
- [ ] Select Dash → directional lines show → click → player dashes + hits
- [ ] Select Guard → player tile highlights → click → guard icon appears
- [ ] Stamina bar in HUD updates correctly
- [ ] Ability cooldowns display and decrement properly
- [ ] End Turn → enemies move and telegraph danger zones (red tiles)
- [ ] Next turn: previous telegraphs resolve (damage to actors in zones)
- [ ] Brute chases player, Caster kites, Flanker flanks
- [ ] Kill all enemies → combat ends → grid disappears → WASD restored
- [ ] Player death → game over triggers (existing GameOverDetect)
- [ ] Camera centers on grid during combat, returns to follow on exit

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Isometric tile alignment issues (grid overlay doesn't match floor tiles) | Medium | High | Use same TileSet configuration as FloorLayer; test A.1 verifies alignment visually |
| Player position desync between grid and world coordinates | Medium | High | Single source of truth in CombatStatsResource.grid_pos; world position derived via GridUtils.grid_to_world() |
| DamageDataResource chain incompatible with grid-based targeting | Low | High | Damage chain is node-agnostic (works with ResourceNode); test B.5 validates early |
| TurnManager await chain breaks on rapid input | Medium | Medium | Disable input processing during phase transitions; TurnManager ignores input outside PLAYER_TURN |
| Enemy AI edge cases (corner positions, all paths blocked) | Medium | Medium | TDD tests cover edge cases explicitly; fallback behavior = stay in place |
| Performance with 64-tile grid overlay redraws | Low | Low | TileMapLayer is GPU-optimized; only redraw changed cells, not full grid |
| Template addon updates break integration | Low | Medium | Pin template version; don't modify great_games_library; minimize top_down changes |

## Commit Strategy

### Commit Order (Linear)
Execute in this order for a clean, bisectable history:

```
Phase 0 (serial, 9 commits):
  0.1  chore: scaffold combat folder structure
  0.2  feat(combat): add combat enum constants
  0.3  feat(combat): add StaminaResource with spend/refill
  0.4  test(combat): add StaminaResource unit tests
  0.5  feat(combat): add CombatStatsResource for grid actors
  0.6  feat(combat): add AbilityResource data class
  0.7  feat(combat): add Strike, Dash, Guard ability resources
  0.8  feat(combat): add GridUtils static coordinate/pathfinding helpers
  0.9  test(combat): add GridUtils unit tests

Workstream A (7 commits, can interleave with B/C):
  A.1  feat(combat): add CombatGrid with isometric overlay
  A.2  feat(combat): add GridCursor with tile hover/click
  A.3  feat(combat): add TurnManager with phase coroutine loop
  A.4  test(combat): add TurnManager phase transition tests
  A.5  feat(combat): add GridMovement with stamina-based reachability
  A.6  test(combat): add GridMovement reachability tests
  A.7  feat(combat): add CombatTransition hooking fight_mode

Workstream B (7 commits, can interleave with A/C):
  B.1  feat(combat): add AbilityManager with selection and stamina
  B.2  test(combat): add AbilityManager unit tests
  B.3  feat(combat): add AbilityTargeting with valid tile computation
  B.4  test(combat): add AbilityTargeting valid tile tests
  B.5  feat(combat): implement Strike ability with template damage chain
  B.6  feat(combat): implement Dash ability with movement + impact
  B.7  feat(combat): implement Guard ability with damage reduction

Workstream C (10 commits, can interleave with A/B):
  C.1   feat(combat): add EnemyGridAI base class
  C.2   feat(combat): implement BruteAI (chase + melee telegraph)
  C.3   test(combat): add BruteAI decision tests
  C.4   feat(combat): implement CasterAI (kite + AOE telegraph)
  C.5   test(combat): add CasterAI decision tests
  C.6   feat(combat): implement FlankerAI (flank + backstab telegraph)
  C.7   test(combat): add FlankerAI decision tests
  C.8   feat(combat): add TelegraphSystem with N→N+1 lifecycle
  C.9   test(combat): add TelegraphSystem lifecycle tests
  C.10  feat(combat): add EnemyTurnResolver with sequential execution

Merge Phase (6 commits, serial after workstreams):
  M.1  feat(ui): add CombatHUD with abilities, stamina, phase indicator
  M.2  feat(combat): add CombatManager orchestrator wiring all systems
  M.3  feat(combat): create first tactical encounter room
  M.4  feat(combat): add camera snap and transition effects
  M.5  feat(combat): wire SFX and VFX into combat actions
  M.6  chore(combat): balance pass on stamina costs, HP, and damage
```

### Parallelization Guide for Agents

Workstreams A, B, C can be assigned to 3 parallel agents after Phase 0 completes:
- **Agent 1**: Workstream A (grid + turns) — foundational spatial systems
- **Agent 2**: Workstream B (abilities) — player action system
- **Agent 3**: Workstream C (enemy AI + telegraphs) — enemy behavior system

Merge Phase M requires all three to complete first. Assign to a single agent.

### Bisectability

Every commit must pass: `cd client && godot --headless --quit` (project loads without errors).
Test commits must also pass their specific test: `godot --headless --script res://tests/test_X.gd`.

## Decision Log

| Decision | Rationale | Alternatives Considered |
|----------|-----------|------------------------|
| 3 abilities for first pass (not 5) | Covers all 3 targeting modes (adjacent, line, self) with minimum scope. Cleave + Fireball deferred to post-M1. | 5 abilities (too much for initial integration), 1 ability (insufficient variety) |
| Offline-first (no Dojo) | Fastest path to playable combat. Onchain authority can be layered later since all game logic is in well-defined manager classes. | Start with contracts first (blocked on tooling), hybrid online/offline (complexity) |
| 8×8 grid (not 12×12) | Into the Breach density — tight positioning, every tile matters. Fits single screen without zoom. u64 bitmap compatible. | 10×10 (middle ground), 12×12 (too sparse for 3-4 enemies + 1 player) |
| Await-based TurnManager (not FSM polling) | Code reads linearly matching mental model. No _process() polling overhead. Clean async animation handling. | State machine with _process (polling overhead), signals-only (spaghetti) |
| DamageDataResource reuse (not custom damage) | Template's damage chain gives us free VFX (flash, shake), damage numbers, death handling, knockback. Zero new damage code. | Custom damage system (loses template VFX), direct HP modification (no signals) |
| New code in client/scripts/ (not modifying addons) | Keeps template addon clean. Game-specific code separated. Easier to diff against upstream template. | Modify addons directly (pollutes template), create new addon (overkill) |
| TileMapLayer overlays (not Polygon2D draws) | Aligns with existing isometric tile system. Automatic coordinate conversion. GPU-optimized batch rendering. | Polygon2D _draw() calls (manual coordinate math, slower), Sprite2D per cell (too many nodes) |
| Deterministic AI (no randomness) | Into the Breach model — player can fully predict enemy behavior. Enables strategic depth. Easier to test. | Weighted random (less predictable), behavior trees (overkill for simple rules) |
| Stamina 100 max, move=10, abilities=15-30 | Nice round numbers for UI. Allows ~2 moves + 1 ability per turn, or 1 move + 2 abilities. Creates meaningful trade-offs. | AP-based (2-3 pips — less granular), mana+movement separate (more complex) |
| Sequential enemy execution (0.3s delay) | Visual clarity — player sees each enemy act individually. Matches Into the Breach pacing. | Simultaneous (confusing visually), instant (no feedback) |
| Zombie_crawler base for Flanker (not new from scratch) | Reuses existing scene structure, sprites, and animation framework. Only AI logic differs. | New enemy scene (more work), modify skeleton (doesn't exist) |
| Player snaps to nearest tile on combat enter | Clean transition. No ambiguous "between tiles" state. Simple implementation. | Free placement within tile (precision issues), choose your starting tile (extra UX step) |

## Open Questions

- [ ] Should Flanker backstab bonus apply based on player facing direction or last move direction?
  - **Default**: Last move direction (simpler to compute, no facing concept needed)
- [ ] How should overlapping telegraphs display? Stack colors or show highest-damage zone?
  - **Default**: Additive alpha (overlapping areas appear brighter/more dangerous)
- [ ] Should guard expire at start of PLAYER_TURN or at start of ENEMY_TURN?
  - **Default**: Start of next PLAYER_TURN (protects for exactly 1 enemy phase)
- [ ] Post-M1: Add Cleave (cone AOE, cost=25, damage=12) and Fireball (radius AOE, cost=30, damage=18)?
