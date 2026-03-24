# Project Memory

## 2026-03-24 — Phase 0 foundation setup

- In this repo, run `godot --headless --import` at least once before strict parse checks/tests; otherwise many addon class_name types may fail to resolve during startup.
- `godot --headless --quit` currently exits 0 with a persistent warning about `res://addons/top_down/scenes/autoloads/music.tscn` invalid UID fallback for the OGG path.
- SceneTree tests should avoid mutating captured locals inside inline signal lambdas for counters; connecting signals to explicit methods on `self` is reliable for pass/fail accounting.
- `GridUtils.flood_fill_reachable` accepts `Array[Vector2i]` for blocked cells, so tests must pass a typed array (not raw `[]`).
