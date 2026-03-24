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
