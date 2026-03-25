# Project Memory

## 2026-03-24 — Phase 0 foundation setup

- In this repo, run `godot --headless --import` at least once before strict parse checks/tests; otherwise many addon class_name types may fail to resolve during startup.
- `godot --headless --quit` currently exits 0 with a persistent warning about `res://addons/top_down/scenes/autoloads/music.tscn` invalid UID fallback for the OGG path.
- SceneTree tests should avoid mutating captured locals inside inline signal lambdas for counters; connecting signals to explicit methods on `self` is reliable for pass/fail accounting.
- `GridUtils.flood_fill_reachable` accepts `Array[Vector2i]` for blocked cells, so tests must pass a typed array (not raw `[]`).

## 2026-03-24 — Workstream B ability system notes

- GDScript typed exported arrays (e.g., `@export var abilities:Array[AbilityResource]`) reject plain untyped literals in tests; assign through a typed local (`var abilities:Array[AbilityResource] = [...]`) before setting property.
- In headless SceneTree script tests, pass/fail output can be fully successful while Godot still prints template UID warning plus `ObjectDB instances leaked` resource warnings at exit; this did not block exit status in current setup.

## 2026-03-24 — Workstream C enemy AI + telegraph notes

- Typed function parameters like `add_telegraph(cells:Array[Vector2i], ...)` also reject raw literal arrays in tests (`[Vector2i(...)]` inferred as untyped `Array`); create a typed local first (`var cells:Array[Vector2i] = [...]`).
- For deterministic enemy movement in this codebase, test expectations for chase favored stepping on the shorter delta axis first (with X as tie-break) in the `(0,0)->(3,4)` case.

## 2026-03-24 — Workstream A grid/turn notes

- `GridMovement.set_blocked_cells(cells:Array[Vector2i])` and similar typed-array APIs require typed locals in tests (`var blocked:Array[Vector2i] = [...]`); inline literals can raise runtime argument type errors.
- `TurnManager` coroutine can stay await-based by awaiting only player-end signals and performing enemy/resolve synchronously in the same resume cycle, making headless SceneTree tests deterministic without extra frame waits.

## 2026-03-24 — Merge phase integration notes

- `CombatManager` now owns the tactical loop wiring and should be started with `start_combat(player_node, enemy_nodes, combat_grid)`; it creates all subsystem nodes internally (turn/move/ability/targeting/telegraph/enemy resolver) and emits `combat_finished(player_won)`.
- Telegraph visuals are easy to accidentally clear because `GridMovement.refresh_reachable()` calls `combat_grid.clear_overlay()`; re-apply active telegraph highlights after movement/ability refresh if both overlays must coexist.
- For template integration, attaching `CombatRoomSetup` to an inherited room scene (`scenes/combat/room_combat_01.tscn`) avoids editing addon room templates while still wiring `fight_mode` transitions.

## 2026-03-24 — Standalone tactical room activation notes

- `actor.tscn` is not directly safe for runtime tactical spawn with its default `CharacterStates` node; it errors on missing `idle` animation in this project setup. Remove `CharacterStates` before adding actor to tree, and use `child.free()` (not `queue_free()`) for pre-tree stripping.
- In Godot 4.5, `Camera2D` activation should use `enabled = true`; setting `current` on `Camera2D` throws invalid assignment.
- `combat_hud.tscn` default bottom margin can clip the stamina bar in 1280x720 captures; expanding `Root/BottomMargin.offset_top` (e.g. `-156`) and enabling percentage text makes stamina visibility explicit for QA screenshots.

## 2026-03-24 — Tactical room sprite/wall fixes

- `tactical_room.gd` enemy spawns should pass scene-specific `PackedScene`s (zombie/slime/zombie_crawler) into `_spawn_actor()`; reusing `actor.tscn` for all combatants makes enemies visually identical to the player.
- Enemy template scenes include runtime nodes not present in `actor.tscn` (`ZombieInput`, `SlashAttack`, `ActiveEnemy`, `SlimeSplit`, `BloodTrail`, `PoolNode`); strip these before adding spawned tactical actors to avoid template AI/weapon logic running in turn-based mode.
- For tactical obstacle visuals, `tileset_isometric_walls.tres` with `source_id=0` and atlas `(1,1)` produces raised block-like walls, while `(0,0)` appears too flat for room obstacles.

## 2026-03-24 — Ability targeting + death crash fixes

- `CombatManager` did not wire `AbilityManager.ability_selected/ability_cancelled`; result was no ability range overlay despite selection in HUD. Restoring these signal handlers and drawing `CombatGrid.STATE_ABILITY_RANGE` fixes target feedback.
- Movement overlay is destructive (`grid_movement.refresh_reachable()` clears grid overlay). When cancelling ability targeting, re-run movement overlay refresh then redraw telegraphs to restore normal player-turn view.
- Right-click/Esc cancel for targeting can be handled centrally in `CombatManager._unhandled_input`; gate it by `_input_enabled` and non-null selected ability.
- `ActorDamage` in `addons/top_down` can call `play_managed()` on null exported sound resources in stripped/variant actor setups. Guard `sound_resource_damage`/`sound_resource_dead` (and optional death VFX dependencies) to prevent Nil method calls during death.

## 2026-03-25 — Interactive QA harness notes

- `SceneTree` scripts cannot call `get_viewport()` directly in this setup; use `root.get_camera_2d()` / `root.get_visible_rect()` for input-coordinate conversion helpers.
- Runtime combat nodes in `tactical_room.tscn` (`CombatManager`, `CombatGrid`, `CombatHUD`) are created in room `_ready()`, so a harness resolving them in `_initialize()` may see nulls; re-resolve during early `_process()` frames.
- Clicking grid tiles via scripted mouse events may not target intended cells if camera transform assumptions are off; in observed run, click choreographed for `(2,2)` actually moved player to `(4,4)` and consumed 60 stamina total before frame 30.
- Current turn loop can present `PLAYER_TURN` by frame 80 after `End Turn` because enemy+resolve phases complete quickly within the loop; frame-based assertions for `ENEMY_TURN` should be sampled earlier or polled over a short window.

## 2026-03-26 — Combat result overlay integration notes

- Added reusable `GameResultScreen` as `CanvasLayer` scene/script (`scenes/combat/game_result_screen.tscn`, `scripts/ui/game_result_screen.gd`) with `show_result(player_won)` API and `continue/retry/menu` signals; starts hidden and fades in overlay/content.
- `tactical_room.gd` now listens to `CombatManager.combat_finished` and spawns the result overlay; continue/retry both reload current scene, menu changes to `res://scenes/main_menu.tscn`.
- `combat_room_setup.gd` now spawns the same overlay on `combat_finished`; continue exits fight mode (`fight_mode=false`) and clears overlay, retry reloads scene, menu returns to main menu.
