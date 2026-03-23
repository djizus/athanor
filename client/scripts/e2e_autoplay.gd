extends Node2D

var _step := 0
var _timer := 0.0
var _screenshots: Array[String] = []
var _last_action := ""
var _action_cooldown := 0.0

func _ready() -> void:
	game_state.character_updated.connect(_on_state_change)
	game_state.dungeon_updated.connect(_on_state_change)
	game_state.fight_updated.connect(_on_state_change)

	dojo_bridge.connect_torii()
	var pk: String = ProjectSettings.get_setting("dojo/config/account/private_key", "")
	var addr: String = ProjectSettings.get_setting("dojo/config/account/address", "")
	if not pk.is_empty() and not addr.is_empty():
		dojo_bridge.setup_burner(pk, addr)
		push_warning("[E2E] Burner connected: %s" % addr.left(12))
	dojo_bridge.pull_entities_snapshot()

func _on_state_change(_d: Dictionary = {}) -> void:
	_timer = 0.0

func _process(delta: float) -> void:
	_timer += delta
	_action_cooldown -= delta
	if _timer < 3.0 or _action_cooldown > 0:
		return
	_timer = 0.0
	_step += 1
	_run_step()

func _run_step() -> void:
	var has_char := not game_state.character.is_empty() and int(game_state.character.get("health", 0)) > 0
	var has_dungeon := not game_state.dungeon.is_empty()
	var fight_active := bool(game_state.fight.get("active", false))
	var zone := int(game_state.character.get("current_zone", 0))
	var completed := bool(game_state.dungeon.get("completed", false))
	var failed := bool(game_state.dungeon.get("failed", false))

	push_warning("[E2E step %d] char=%s dungeon=%s fight=%s zone=%d completed=%s failed=%s" % [
		_step, has_char, has_dungeon, fight_active, zone, completed, failed])
	_screenshot("step_%02d" % _step)

	if completed or failed:
		push_warning("[E2E] === RUN COMPLETE: %s ===" % ("COMPLETED" if completed else "FAILED"))
		_screenshot("final")
		push_warning("[E2E] Screenshots: %s" % str(_screenshots))
		get_tree().quit(0)
		return

	if not has_char:
		if _last_action == "spawn":
			push_warning("[E2E] Waiting for spawn... polling")
			dojo_bridge.pull_entities_snapshot()
			dojo_bridge._schedule_entity_poll()
			return
		push_warning("[E2E] Spawning...")
		dojo_bridge.spawn(0)
		_last_action = "spawn"
		_action_cooldown = 8.0
		return

	if not has_dungeon or game_state.dungeon.is_empty():
		push_warning("[E2E] Waiting for dungeon data...")
		dojo_bridge.pull_entities_snapshot()
		return

	if fight_active:
		var mob_count := int(game_state.fight.get("mob_count", 0))
		var packed: int = int(game_state.fight.get("mob_healths", 0))
		var alive := false
		for i in range(mob_count):
			if (packed >> (i * 16)) & 0xFFFF > 0:
				alive = true
				break
		if alive:
			var stamina := int(game_state.character.get("stamina", 0))
			if stamina >= 30:
				push_warning("[E2E] Attacking...")
				dojo_bridge.cast(game_state.get_game_id(), 0, 0)
				_action_cooldown = 6.0
			else:
				push_warning("[E2E] Finishing turn...")
				dojo_bridge.finish(game_state.get_game_id())
				_action_cooldown = 6.0
		else:
			push_warning("[E2E] All mobs dead, finishing...")
			dojo_bridge.finish(game_state.get_game_id())
			_action_cooldown = 6.0
		return

	var zones_cleared := int(game_state.dungeon.get("zones_cleared", 0))
	if zone == 0 or zones_cleared > 0:
		push_warning("[E2E] Choosing path (left=0)...")
		dojo_bridge.choose(game_state.get_game_id(), 0)
		_action_cooldown = 6.0
		return

	push_warning("[E2E] Starting fight...")
	dojo_bridge.start(game_state.get_game_id())
	_action_cooldown = 6.0

func _screenshot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := "/tmp/e2e_%s.png" % name
	img.save_png(path)
	_screenshots.append(path)
