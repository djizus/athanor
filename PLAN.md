# Athanor — Tactical RPG Implementation Plan

> **Last updated**: 2026-03-26 — Gap analysis + remaining work prioritization
>
> **Status**: Phase 0 + Workstreams A/B/C + Merge M.1–M.4 COMPLETE (57 tests passing).
> Game is partially playable via standalone `tactical_room.tscn`. Main game flow
> (menu → exploration → combat → victory) has integration gaps. This plan tracks
> remaining work to reach a fully playable demo.

---

## Table of Contents

1. [Overview](#overview)
2. [Implementation Status](#implementation-status)
3. [Known Bugs & Issues](#known-bugs--issues)
4. [Remaining Work — P0 Playable](#remaining-work--p0-playable-critical-path)
5. [Remaining Work — P1 Complete Loop](#remaining-work--p1-complete-loop)
6. [Remaining Work — P2 Polish](#remaining-work--p2-polish)
7. [Verification Approach](#verification-approach)
8. [Commit Strategy](#commit-strategy)
9. [Technical Design Reference](#technical-design-reference)
10. [Decision Log](#decision-log)

---

## Overview

Convert the nezvers/Godot-GameTemplate real-time arena shooter into an Into the Breach–style turn-based tactical combat system running locally in Godot 4.6. When the player enters an arena (`fight_mode` BoolResource becomes true), the game switches from real-time WASD exploration to an 8×8 isometric grid where movement and abilities cost stamina. Enemies telegraph their attacks 1 turn ahead, giving the player one full turn to reposition. All combat logic runs locally in GDScript (offline-first); future onchain integration via Dojo contracts is out of scope for this plan.

### Target Game Flow

```
1. Main Menu (Enter Dungeon / Settings / Quit)     ← EXISTS
2. Isometric dungeon room, WASD exploration         ← EXISTS (room_tactical_01)
3. Walk into arena trigger → doors close            ← PARTIAL (fight_mode hooks work)
4. TACTICAL COMBAT: 8×8 grid, turn-based            ← EXISTS (tactical_room)
   - Player turn: move (stamina), abilities, end turn
   - Enemy turn: move, telegraph attacks
   - Resolve: telegraphed damage applies
   - Repeat until win/lose
5. Combat ends → grid removed, doors open           ← NOT VERIFIED E2E
6. Victory → next room / Game Over → retry/menu     ← MISSING
```

---

## Implementation Status

### ✅ COMPLETE — Phase 0: Foundation (9/9 tasks)

| # | Task | Status | Files |
|---|------|--------|-------|
| 0.1 | Folder structure | ✅ DONE | `scripts/combat/`, `tests/`, `resources/combat/` |
| 0.2 | CombatEnums | ✅ DONE | `scripts/combat/combat_enums.gd` |
| 0.3 | StaminaResource | ✅ DONE | `scripts/resources/stamina_resource.gd` |
| 0.4 | StaminaResource tests | ✅ DONE | `tests/test_stamina.gd` (12 assertions) |
| 0.5 | CombatStatsResource | ✅ DONE | `scripts/resources/combat_stats_resource.gd` |
| 0.6 | AbilityResource | ✅ DONE | `scripts/resources/ability_resource.gd` |
| 0.7 | Ability .tres instances | ✅ DONE | `resources/combat/ability_{strike,dash,guard}.tres` |
| 0.8 | GridUtils | ✅ DONE | `scripts/combat/grid_utils.gd` |
| 0.9 | GridUtils tests | ✅ DONE | `tests/test_grid_utils.gd` (14 assertions) |

### ✅ COMPLETE — Workstream A: Combat Grid + Turn System (7/7 tasks)

| # | Task | Status | Files |
|---|------|--------|-------|
| A.1 | CombatGrid scene | ✅ DONE | `scripts/combat/combat_grid.gd`, `scenes/combat/combat_grid.tscn` |
| A.2 | GridCursor | ✅ DONE | `scripts/combat/grid_cursor.gd` |
| A.3 | TurnManager | ✅ DONE | `scripts/combat/turn_manager.gd` |
| A.4 | TurnManager tests | ✅ DONE | `tests/test_turn_manager.gd` (18 assertions) |
| A.5 | GridMovement | ✅ DONE | `scripts/combat/grid_movement.gd` |
| A.6 | GridMovement tests | ✅ DONE | `tests/test_grid_movement.gd` (14 assertions) |
| A.7 | CombatTransition | ✅ DONE | `scripts/combat/combat_transition.gd` |

### ✅ COMPLETE — Workstream B: Ability System (7/7 tasks)

| # | Task | Status | Files |
|---|------|--------|-------|
| B.1 | AbilityManager | ✅ DONE | `scripts/combat/ability_manager.gd` |
| B.2 | AbilityManager tests | ✅ DONE | `tests/test_ability_manager.gd` (18 assertions) |
| B.3 | AbilityTargeting | ✅ DONE | `scripts/combat/ability_targeting.gd` |
| B.4 | AbilityTargeting tests | ✅ DONE | `tests/test_ability_targeting.gd` (8 assertions) |
| B.5 | Strike effect | ✅ DONE | `scripts/combat/abilities/ability_strike.gd` |
| B.6 | Dash effect | ✅ DONE | `scripts/combat/abilities/ability_dash.gd` |
| B.7 | Guard effect | ✅ DONE | `scripts/combat/abilities/ability_guard.gd` |

### ✅ COMPLETE — Workstream C: Enemy AI + Telegraphs (10/10 tasks)

| # | Task | Status | Files |
|---|------|--------|-------|
| C.1 | EnemyGridAI base | ✅ DONE | `scripts/combat/enemy_grid_ai.gd` |
| C.2 | BruteAI | ✅ DONE | `scripts/combat/ai/brute_ai.gd` |
| C.3 | BruteAI tests | ✅ DONE | `tests/test_brute_ai.gd` (10 assertions) |
| C.4 | CasterAI | ✅ DONE | `scripts/combat/ai/caster_ai.gd` |
| C.5 | CasterAI tests | ✅ DONE | `tests/test_caster_ai.gd` (10 assertions) |
| C.6 | FlankerAI | ✅ DONE | `scripts/combat/ai/flanker_ai.gd` |
| C.7 | FlankerAI tests | ✅ DONE | `tests/test_flanker_ai.gd` (10 assertions) |
| C.8 | TelegraphSystem | ✅ DONE | `scripts/combat/telegraph_system.gd` |
| C.9 | TelegraphSystem tests | ✅ DONE | `tests/test_telegraph_system.gd` (12 assertions) |
| C.10 | EnemyTurnResolver | ✅ DONE | `scripts/combat/enemy_turn_resolver.gd` |

### ✅ COMPLETE — Merge Phase (4/6 tasks)

| # | Task | Status | Files |
|---|------|--------|-------|
| M.1 | CombatHUD | ✅ DONE | `scripts/ui/combat_hud.gd`, `scenes/combat/combat_hud.tscn` |
| M.2 | CombatManager orchestrator | ✅ DONE | `scripts/combat/combat_manager.gd` (655 lines) |
| M.3 | First encounter room | ✅ DONE | `scenes/combat/room_combat_01.tscn`, `room_tactical_01.tscn`, `tactical_room.tscn` |
| M.4 | Camera transitions | ✅ DONE | Integrated in `combat_manager.gd` lines 603–655 |
| M.5 | SFX + VFX hooks | ⚠️ PARTIAL | Tile flash VFX exist (`_spawn_tile_vfx`, `_flash_screen`), **no audio wired** |
| M.6 | Balance tuning pass | ⚠️ PARTIAL | Values set in .tres files, **no formal tuning** |

### Additional Work Completed (Not In Original Plan)

| Item | Status | Files |
|------|--------|-------|
| Main menu (Enter Dungeon / Settings / Quit) | ✅ DONE | `scripts/main_menu.gd`, `scenes/main_menu.tscn` |
| CombatRoomSetup (room_0 integration) | ✅ DONE | `scripts/combat/combat_room_setup.gd` |
| Standalone tactical room (direct combat test) | ✅ DONE | `scripts/combat/tactical_room.gd`, `scenes/combat/tactical_room.tscn` |
| Tactical launcher (dev shortcut) | ✅ DONE | `scripts/combat/tactical_launcher.gd` |
| Interactive QA harness | ✅ DONE | `tests/test_interactive_qa.gd` (13 assertions) |
| Full flow QA harness | ✅ DONE | `tests/test_full_flow_qa.gd` |
| Visual combat QA | ✅ DONE | `tests/test_visual_combat.gd` |
| WASD input actions (was missing) | ✅ FIXED | `project.godot` — up=W, down=S, left=A, right=D |
| Distinct enemy sprites in tactical_room | ✅ FIXED | `tactical_room.gd` uses zombie/slime/crawler scenes |
| Death crash null guards | ✅ FIXED | `ActorDamage` guards on nil sound/VFX resources |
| 480×270 viewport with 4× upscale | ✅ FIXED | `project.godot` display settings |
| Compact bottom-bar HUD | ✅ FIXED | `combat_hud.tscn` 72px bottom margin |

---

## Known Bugs & Issues

### 🔴 BUG-1: CombatRoomSetup spawns identical enemies (HIGH)
- **File**: `scripts/combat/combat_room_setup.gd` line 7–8, line 134
- **Issue**: `@export var enemy_scene` defaults to `actor.tscn`. All 3 spawned enemies use this same scene, making them visually identical to the player.
- **Impact**: The main game flow (Main Menu → Enter Dungeon → room_tactical_01) shows 3 identical actors. The zombie/slime/crawler fix in `tactical_room.gd` does NOT apply to this code path.
- **Fix**: Replace single `enemy_scene` export with per-archetype scene exports (zombie, slime, crawler). Mirror the stripping logic from `tactical_room.gd` lines 87–123.

### 🟡 BUG-2: HUD ability buttons show cramped two-line text (MEDIUM)
- **File**: `scripts/ui/combat_hud.gd` line 131, `scenes/combat/combat_hud.tscn` lines 73–144
- **Issue**: Button text is `"%s\nCost %d"` (e.g. "Strike\nCost 20") crammed into 80×28px at 11pt font. The user reported "Cost 0" labels — likely from an earlier build or from poor readability at small size.
- **Impact**: Abilities are hard to identify at a glance.
- **Fix**: Show only ability name on button, move cost to tooltip.

### 🟡 BUG-3: No victory/defeat screen (MEDIUM)
- **File**: `scripts/combat/combat_manager.gd` line 368–372
- **Issue**: `combat_finished(player_won)` signal emits but no UI reacts. `CombatRoomSetup._on_combat_finished` sets `fight_mode=false`, but no visual feedback.
- **Impact**: No sense of accomplishment or failure. No path to retry or continue.

### 🟡 BUG-4: Template weapon HUD visible during exploration (MEDIUM)
- **File**: `scenes/combat/room_tactical_01.tscn` (inherits room_0.tscn)
- **Issue**: room_0 includes WeaponManager and weapon HUD elements. These remain visible during exploration. CombatRoomSetup does not hide them.
- **Impact**: Confusing — player sees ammo/weapon indicators for a turn-based tactical game.

### 🟢 BUG-5: Exploration → combat → exploration loop not E2E tested (LOW)
- **Files**: `combat_room_setup.gd`, `combat_transition.gd`
- **Issue**: The full signal chain (fight_mode=true → combat → fight_mode=false → exploration restored) has all hooks wired but has never been verified end-to-end.

---

## Remaining Work — P0: PLAYABLE (Critical Path)

> Goal: A player can launch the game, click Enter Dungeon, walk to the arena,
> fight enemies with abilities, win or lose, and see feedback. No crashes.

### P0.1 — Fix CombatRoomSetup enemy scene variety

**Problem**: `combat_room_setup.gd` uses single `enemy_scene` export (actor.tscn) for all enemies.

**Changes**:
- Edit `scripts/combat/combat_room_setup.gd`:
  - Replace `@export var enemy_scene:PackedScene` with three exports:
    ```gdscript
    @export var brute_scene:PackedScene = preload("res://addons/top_down/scenes/actors/zombie.tscn")
    @export var caster_scene:PackedScene = preload("res://addons/top_down/scenes/actors/slime.tscn")
    @export var flanker_scene:PackedScene = preload("res://addons/top_down/scenes/actors/zombie_crawler.tscn")
    ```
  - Update `_spawn_encounter_enemies()` to select scene by index:
    ```gdscript
    var scenes:Array[PackedScene] = [brute_scene, caster_scene, flanker_scene]
    var enemy_node:Node2D = scenes[min(i, scenes.size() - 1)].instantiate()
    ```
  - Add stripping for zombie/slime-specific nodes (ZombieInput, SlashAttack, ActiveEnemy, SlimeSplit, BloodTrail, PoolNode) matching `tactical_room.gd` lines 87–123

**Output files**: `scripts/combat/combat_room_setup.gd`
**Verification**: `cd client && godot --headless --export-release "Web" export/web/index.html` then Playwright screenshot of combat showing 3 distinct enemy sprites.
**Commit**: `fix(combat): use distinct enemy scenes in CombatRoomSetup`

---

### P0.2 — Verify WASD exploration works in room_tactical_01

**Problem**: The main game flow loads `room_tactical_01.tscn` (room_0 + CombatRoomSetup). WASD exploration must work before combat triggers.

**Changes**: Verification only — Playwright test.
- Export HTML5
- Playwright: navigate to localhost:8090, click "Enter Dungeon" button
- Wait for room to load
- Screenshot exploration state
- Verify player sprite is visible, HUD is not in combat mode

**Output files**: Playwright test script
**Verification**: Playwright screenshot shows exploration room with player visible.
**Commit**: `test(e2e): verify WASD exploration loads correctly`

---

### P0.3 — Verify arena trigger starts combat

**Problem**: ArenaStarter trigger zone should activate combat. Never tested via main game flow.

**Changes**: Extend P0.2 Playwright test.
- After entering dungeon, dispatch keyboard events (WASD) to move toward arena center
- Wait for combat to start (detect "YOUR TURN" text or grid overlay)
- Screenshot combat state

**Output files**: Extends P0.2 test
**Verification**: Playwright screenshot shows combat grid, "YOUR TURN" indicator, stamina bar, ability buttons.
**Commit**: `test(e2e): verify arena trigger starts combat mode`

---

### P0.4 — Verify ability targeting and execution

**Problem**: Ability targeting was reported as "unplayable" in earlier builds. Signal wiring was fixed but not re-verified.

**Changes**: Run `test_interactive_qa.gd` headless + extend Playwright test.
- In combat: click an ability button (Strike)
- Verify purple target tiles appear
- Click a target tile
- Verify stamina decreases
- Screenshot each state

**Output files**: Extends P0.3 test
**Verification**: `cd client && godot --headless --script res://tests/test_interactive_qa.gd` exits 0. Playwright screenshots show ability targeting.
**Commit**: `test(e2e): verify ability targeting and execution`

---

### P0.5 — Verify combat end restores exploration

**Problem**: After all enemies die, combat should end and exploration should resume. Never tested E2E.

**Changes**: Extend Playwright test or create headless scenario.
- After combat ends verify: grid overlay removed, "YOUR TURN" gone, player can move with WASD
- Screenshot post-combat state

**Output files**: Extends P0.4 test
**Verification**: Playwright screenshot shows exploration room without combat grid.
**Commit**: `test(e2e): verify combat end restores exploration`

---

### P0.6 — Run all existing unit tests (regression gate)

**Problem**: Need to verify all existing tests still pass before adding new features.

**Changes**: None — verification only.

**Verification**:
```bash
cd client
for test in tests/test_stamina.gd tests/test_grid_utils.gd tests/test_turn_manager.gd \
  tests/test_grid_movement.gd tests/test_ability_manager.gd tests/test_ability_targeting.gd \
  tests/test_brute_ai.gd tests/test_caster_ai.gd tests/test_flanker_ai.gd \
  tests/test_telegraph_system.gd; do
  echo "=== $test ==="
  godot --headless --script "res://$test"
  if [ $? -ne 0 ]; then echo "FAIL"; exit 1; fi
done
echo "All passed"
```
**Commit**: No commit (gate check only)

---

## Remaining Work — P1: COMPLETE LOOP

> Goal: The game has a clear win/lose state, the player can retry or continue,
> ability buttons are readable, and the template HUD doesn't leak through.

### P1.1 — Create GameResultScreen UI

**Problem**: No victory or defeat screen exists. Combat just ends silently.

**Changes**:
- Create `scripts/ui/game_result_screen.gd`:
  - Extends CanvasLayer
  - Shows "VICTORY" (green) or "DEFEAT" (red) centered text
  - 3 buttons: "Continue" (hidden on defeat), "Retry", "Menu"
  - Signals: `continue_pressed`, `retry_pressed`, `menu_pressed`
  - Method: `show_result(player_won:bool)` — sets text, shows/hides Continue
  - Fade-in animation (0.3s)
- Create `scenes/combat/game_result_screen.tscn`:
  - CanvasLayer > Control (full screen) > VBoxContainer centered
  - Large label (result text), 3 buttons in HBoxContainer
  - Semi-transparent dark overlay behind content

**Output files**: `scripts/ui/game_result_screen.gd`, `scenes/combat/game_result_screen.tscn`
**Verification**: `cd client && godot --headless --quit` exits 0; scene loads without errors.
**Commit**: `feat(ui): add GameResultScreen for victory/defeat`

---

### P1.2 — Wire GameResultScreen into combat flow

**Problem**: `combat_finished(player_won)` signal is emitted but no UI reacts.

**Changes**:
- Edit `scripts/combat/tactical_room.gd`:
  - Preload GameResultScreen scene
  - Connect `_combat_manager.combat_finished` → `_show_result(player_won)`
  - `continue_pressed` / `retry_pressed` → reload current scene
  - `menu_pressed` → `get_tree().change_scene_to_file("res://scenes/main_menu.tscn")`
- Edit `scripts/combat/combat_room_setup.gd`:
  - Same pattern: preload screen, connect `_combat_manager.combat_finished`
  - `continue_pressed` → set `fight_mode=false` and remove result screen
  - `retry_pressed` → reload full scene
  - `menu_pressed` → change to main menu

**Output files**: `scripts/combat/tactical_room.gd`, `scripts/combat/combat_room_setup.gd`
**Verification**: Playwright: kill all enemies → "VICTORY" screen appears → click "Menu" → returns to main menu.
**Commit**: `feat(combat): wire GameResultScreen to combat completion`

---

### P1.3 — Fix HUD ability button readability

**Problem**: Buttons show "Strike\nCost 20" in cramped 80×28px. Hard to read.

**Changes**:
- Edit `scripts/ui/combat_hud.gd` line 131:
  - Change: `button.text = "%s\nCost %d" % [ability.ability_name, ability.stamina_cost]`
  - To: `button.text = ability.ability_name`
  - Add: `button.tooltip_text = "%s — %d stamina\n%s" % [ability.ability_name, ability.stamina_cost, ability.description]`
- Edit `scenes/combat/combat_hud.tscn`:
  - Update default button text to just ability names: "Strike", "Dash", "Guard"

**Output files**: `scripts/ui/combat_hud.gd`, `scenes/combat/combat_hud.tscn`
**Verification**: Playwright screenshot of HUD showing readable single-word ability names.
**Commit**: `fix(ui): show ability names on buttons, move cost to tooltip`

---

### P1.4 — Hide template weapon HUD during tactical mode

**Problem**: room_0.tscn includes weapon HUD elements (ammo, weapon icon) irrelevant for tactical combat.

**Changes**:
- Edit `scripts/combat/combat_room_setup.gd`:
  - In `_disable_realtime_systems()`, find and hide weapon-related HUD nodes:
    ```gdscript
    var game_hud:CanvasLayer = _room_root.get_node_or_null("GameHUD")
    if game_hud != null:
        game_hud.visible = false
    ```
  - In `_enable_realtime_systems()`: restore visibility if needed (or leave hidden)
- Alternative: In `room_tactical_01.tscn`, override GameHUD visibility

**Output files**: `scripts/combat/combat_room_setup.gd`
**Verification**: Playwright screenshot of exploration phase showing no weapon indicators.
**Commit**: `fix(ui): hide template weapon HUD in tactical rooms`

---

### P1.5 — Write TDD test for GameResultScreen

**Problem**: Need automated verification that result screen shows correctly.

**Changes**:
- Create `tests/test_game_result_screen.gd`:
  - Test: instantiate GameResultScreen
  - Call `show_result(true)` → verify text contains "VICTORY"
  - Call `show_result(false)` → verify text contains "DEFEAT"
  - Verify "Continue" button hidden on defeat, visible on victory
  - Verify all 3 signals exist

**Output files**: `tests/test_game_result_screen.gd`
**Verification**: `cd client && godot --headless --script res://tests/test_game_result_screen.gd` exits 0.
**Commit**: `test(ui): add GameResultScreen unit tests`

---

### P1.6 — E2E Playwright test: full game loop

**Problem**: Need automated verification of the complete game flow.

**Changes**:
- Create Playwright test script that:
  1. Navigate to HTML5 export
  2. Click "Enter Dungeon"
  3. Wait for room to load
  4. Verify exploration state (screenshot)
  5. Send WASD keys to move toward arena
  6. Wait for combat to start
  7. Screenshot combat grid
  8. Click ability buttons, verify targeting
  9. Click "End Turn", verify enemy turn
  10. Repeat until combat ends (or timeout)
  11. Verify result screen appears
  12. Click "Menu", verify return to main menu

**Output files**: Playwright test file
**Verification**: Playwright test completes with all screenshots captured.
**Commit**: `test(e2e): add full game loop Playwright test`

---

## Remaining Work — P2: POLISH

> Goal: The game feels complete — multiple rooms, healing, sound effects, tuning.

### P2.1 — Health pickup between combats

**Problem**: Player HP carries over from combat with no way to heal.

**Changes**:
- Create `scripts/combat/health_pickup.gd`:
  - Extends Area2D
  - On body_entered: find player's HealthResource, heal 30 HP, queue_free()
  - Visual: pulsing green diamond sprite
- Create `scenes/combat/health_pickup.tscn`
- Place 1-2 pickups in room_tactical_01 exploration area

**Output files**: `scripts/combat/health_pickup.gd`, `scenes/combat/health_pickup.tscn`
**Verification**: Playwright: walk over pickup → HP increases.
**Commit**: `feat(gameplay): add health pickup for between-combat healing`

---

### P2.2 — Room transition to second encounter

**Problem**: After combat victory, no progression.

**Changes**:
- Create `scenes/combat/room_tactical_02.tscn` (inherit room_0 or room_1, add CombatRoomSetup with different enemy composition: 2 Brutes + 1 Caster)
- Edit GameResultScreen "Continue" handler to load next room scene

**Output files**: `scenes/combat/room_tactical_02.tscn`, modified `scripts/ui/game_result_screen.gd`
**Verification**: Playwright: win combat in room 1 → click Continue → loads room 2.
**Commit**: `feat(levels): add second tactical room with room transition`

---

### P2.3 — SFX hooks for combat actions

**Problem**: Combat is silent — no audio feedback.

**Changes**:
- Edit `scripts/combat/combat_manager.gd`:
  - On ability use: play attack sound (reuse template SoundResource)
  - On telegraph resolve: play impact sound
  - On guard: play shield sound
  - On damage/death: reuse template sounds

**Output files**: Modified `scripts/combat/combat_manager.gd`
**Verification**: Manual audio check or Playwright with audio detection.
**Commit**: `feat(combat): wire SFX into combat actions`

---

### P2.4 — Balance tuning pass

**Problem**: Combat values have not been formally tuned.

**Changes**:
- Target: combat lasts 4–6 turns, player survives 2 unmitigated telegraphs, each enemy dies in 3–4 Strikes, stamina allows ~2 moves + 1 ability per turn
- Update .tres resource files with tuned values

**Output files**: Modified `resources/combat/ability_*.tres`
**Verification**: Play 5 encounters. All feel fair but challenging.
**Commit**: `chore(combat): balance pass on stamina costs, HP, and damage`

---

### P2.5 — Stamina cost display scaling

**Problem**: Stamina cost numbers on grid tiles may be hard to read at combat zoom.

**Changes**:
- Edit `scripts/combat/combat_grid.gd` `show_tile_costs()`:
  - Scale font size for readability at combat zoom level

**Output files**: `scripts/combat/combat_grid.gd`
**Verification**: Playwright screenshot shows readable cost numbers.
**Commit**: `fix(ui): scale stamina cost display for combat zoom level`

---

## Verification Approach

### HTML5 Export + Playwright Pipeline

```bash
# 1. Export to HTML5
cd client && godot --headless --export-release "Web" export/web/index.html

# 2. Serve locally
python3 -m http.server 8090 --bind 127.0.0.1 --directory export/web &
SERVER_PID=$!

# 3. Run Playwright tests
npx playwright test tests/e2e/

# 4. Cleanup
kill $SERVER_PID
```

### Headless Unit Tests

```bash
cd client
for test in tests/test_*.gd; do
  case "$test" in
    *full_flow*|*interactive*|*visual*) continue ;;
  esac
  echo "=== Running $test ==="
  godot --headless --script "res://$test"
  if [ $? -ne 0 ]; then echo "FAILED: $test"; exit 1; fi
done
echo "All tests passed"
```

### Test Inventory

| Test File | Assertions | What It Tests |
|-----------|-----------|---------------|
| `test_stamina.gd` | 12 | StaminaResource spend/refill/signals |
| `test_grid_utils.gd` | 14 | Manhattan distance, bounds, flood fill |
| `test_turn_manager.gd` | 18 | Phase transitions, turn counting |
| `test_grid_movement.gd` | 14 | Reachable tiles, stamina cost, blocking |
| `test_ability_manager.gd` | 18 | Selection, cooldowns, stamina checks |
| `test_ability_targeting.gd` | 8 | ADJACENT/LINE/SELF targeting modes |
| `test_brute_ai.gd` | 10 | Chase, melee telegraph, blocked paths |
| `test_caster_ai.gd` | 10 | Kite, retreat, AOE telegraph |
| `test_flanker_ai.gd` | 10 | Flank position, fallback, telegraph |
| `test_telegraph_system.gd` | 12 | Add, resolve N+1, clear |
| `test_interactive_qa.gd` | 13 | Movement, targeting, guard, enemy turn |
| `test_full_flow_qa.gd` | — | Menu → dungeon → combat (frame-based) |
| `test_visual_combat.gd` | — | Visual capture of tactical room |
| **TOTAL** | **139+** | **10 unit + 3 integration** |

---

## Commit Strategy

### Remaining Commits (Ordered)

```
P0 — Playable (5 commits):
  P0.1  fix(combat): use distinct enemy scenes in CombatRoomSetup
  P0.2  test(e2e): verify WASD exploration loads correctly
  P0.3  test(e2e): verify arena trigger starts combat mode
  P0.4  test(e2e): verify ability targeting and execution
  P0.5  test(e2e): verify combat end restores exploration

P1 — Complete Loop (6 commits):
  P1.1  feat(ui): add GameResultScreen for victory/defeat
  P1.2  feat(combat): wire GameResultScreen to combat completion
  P1.3  fix(ui): show ability names on buttons, move cost to tooltip
  P1.4  fix(ui): hide template weapon HUD in tactical rooms
  P1.5  test(ui): add GameResultScreen unit tests
  P1.6  test(e2e): add full game loop Playwright test

P2 — Polish (5 commits):
  P2.1  feat(gameplay): add health pickup for between-combat healing
  P2.2  feat(levels): add second tactical room with room transition
  P2.3  feat(combat): wire SFX into combat actions
  P2.4  chore(combat): balance pass on stamina costs, HP, and damage
  P2.5  fix(ui): scale stamina cost display for combat zoom level
```

### Parallelization Guide

```
P0 tasks are serial (each verifies a prerequisite for the next).
P1.1 + P1.3 + P1.4 can parallelize (independent UI tasks).
P1.2 depends on P1.1 (wires the screen created in P1.1).
P1.5 depends on P1.1 (tests the screen created in P1.1).
P1.6 depends on P1.1 + P1.2 (needs result screen for full loop).
P2 tasks can mostly parallelize after P1 completes.
```

### Bisectability

Every commit must pass: `cd client && godot --headless --quit` (exits 0).
Test commits must pass their specific test command.

---

## Technical Design Reference

### Architecture — Scene Tree During Combat

```
Room (room_tactical_01.tscn = room_0.tscn + CombatRoomSetup)
├── Background/
│   ├── FloorLayer (existing TileMapLayer, 32×16 iso)
│   └── ObstacleLayer (existing TileMapLayer + StaticBody2D)
├── CombatGrid (spawned by CombatRoomSetup)
│   ├── GridOverlay (TileMapLayer — walkable/danger/selected/range tiles)
│   ├── GridCursor (Sprite2D — hover highlight on current mouse tile)
│   └── CostLabels (stamina costs on reachable tiles)
├── YSortedLayer/
│   ├── Player (CharacterBody2D, MoverTopDown2D DISABLED in combat)
│   └── Enemies (spawned by CombatRoomSetup, realtime nodes stripped)
├── CombatManager (spawned by CombatRoomSetup)
│   ├── TurnManager (phase state machine)
│   ├── GridMovement (player grid movement)
│   ├── AbilityManager (holds 3 abilities)
│   ├── AbilityTargeting (tile selection + preview)
│   ├── TelegraphSystem (computes + displays telegraphs)
│   ├── EnemyTurnResolver (executes AI + resolves telegraphs)
│   └── AbilityStrike / AbilityDash / AbilityGuard (effect scripts)
├── CombatRoomSetup (hooks fight_mode transitions)
├── CombatHUD (CanvasLayer — ability buttons, stamina bar, phase indicator)
├── GameResultScreen (CanvasLayer — victory/defeat overlay) ← NEW P1.1
└── [existing template nodes: MainCamera, ScreenEffects, GameHUD, etc.]
```

### Combat Values (Current)

| Parameter | Value | Notes |
|-----------|-------|-------|
| Grid size | 8×8 | 64 tiles, ~4 obstacles |
| Stamina max | 100 | Refills each player turn |
| Move cost | 10/tile | Manhattan distance |
| Strike | cost=20, dmg=15, range=1, CD=0 | Adjacent melee |
| Dash | cost=25, dmg=10, range=3, CD=1 | Line move + hit |
| Guard | cost=15, dmg=0, range=self, CD=2 | 50% damage reduction 1 turn |
| Brute HP | 50 | Chase AI, 20 dmg melee |
| Caster HP | 30 | Kite AI, 12 dmg 3×3 AOE |
| Flanker HP | 40 | Flank AI, 18 dmg melee |
| Player HP | 100 | Set in CombatManager._build_player_data() |

---

## Decision Log

| Decision | Rationale |
|----------|-----------|
| Two combat entry points (tactical_room + combat_room_setup) | tactical_room for rapid iteration/testing; combat_room_setup for real game flow. Keep both. |
| Main menu loads room_tactical_01 (room_0 + CombatRoomSetup) | Preserves template exploration → combat transition. |
| Distinct enemy scenes per archetype | zombie=Brute, slime=Caster, zombie_crawler=Flanker. Visual clarity. |
| GameResultScreen as CanvasLayer overlay | Doesn't require scene change. Can layer over combat or exploration. |
| Ability name only on buttons (not cost) | Readability at small sizes. Cost visible via tooltip and stamina bar context. |
| 480×270 viewport + 4× upscale | Pixel-art friendly. Matches template's intended resolution. |
| Hide weapon HUD (not remove) | Reversible. May want exploration weapons in future. |
| Health pickup as Area2D | Simplest implementation. Template already has AreaTransmitter pattern. |
| 3 abilities first (not 5) | Covers all targeting modes. Cleave + Fireball deferred to post-P2. |
| Deterministic AI (no randomness) | Into the Breach model. Player can predict enemy behavior. Easier to test. |
| 8×8 grid (not 12×12) | Tight positioning. Every tile matters. Fits single screen. u64 bitmap compatible. |
| Await-based TurnManager (not FSM polling) | Linear code flow. No _process() polling. Clean async animation handling. |

## Open Questions

- [x] ~~Should WASD input actions be defined?~~ — Yes, FIXED in project.godot
- [x] ~~Should enemies use distinct sprites?~~ — Yes, FIXED in tactical_room.gd. Still needs CombatRoomSetup fix (P0.1).
- [ ] Should "Continue" after victory load a new room or replay the same room?
  - **Default**: Reload same room for now (P1.2). New room in P2.2.
- [ ] Should stamina cost numbers be visible during targeting (not just movement)?
  - **Default**: Only during movement. Ability cost shown in tooltip.
- [ ] Post-P2: Add Cleave (cone AOE, cost=25, damage=12) and Fireball (radius AOE, cost=30, damage=18)?
  - **Deferred**: Focus on making 3 abilities polished first.
