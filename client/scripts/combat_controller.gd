extends Node
class_name CombatController

signal request_commands_enabled(enabled: bool)
signal request_turn_state(is_player: bool, status: String)
signal request_stamina_update()
signal request_status_icons_update()
signal request_turn_order_update()
signal request_refresh()

const AA_COST := 30
const HEAVY_COST := 50

var dungeon_view: Node2D
var targeting_system: Node2D
var camera: Node
var stamina_bar: ProgressBar
var stamina_label: Label
var turn_info: Label
var turn_status_label: Label
var is_fighting_fn: Callable

var action_in_flight: bool = false
var _mock_stamina: int = -1
var _defending: bool = false
var auto_finishing: bool = false

func execute_attack() -> void:
	if not _is_fighting() or action_in_flight:
		return
	var stamina := get_display_stamina()
	if stamina < AA_COST:
		if turn_status_label != null:
			turn_status_label.text = "Not enough stamina"
		turn_info.text = "Not enough stamina"
		request_stamina_update.emit()
		return
	var target := _get_current_target()
	if target < 0:
		return
	audio_manager.play_sfx("sword_slash")
	action_in_flight = true
	request_commands_enabled.emit(false)
	request_turn_state.emit(true, "Attacking...")
	turn_info.text = "Attacking..."
	dojo_bridge.cast(game_state.get_game_id(), target, 0)
	if dungeon_view != null and dungeon_view.has_method("play_attack"):
		dungeon_view.play_attack(target)
		var mob_pos: Vector2 = dungeon_view.get_mob_world_position(target) if dungeon_view.has_method("get_mob_world_position") else Vector2.ZERO
		if mob_pos != Vector2.ZERO and dungeon_view.has_method("spawn_damage_number"):
			dungeon_view.spawn_damage_number(mob_pos, int(game_state.character.get("power", 10)))
		if mob_pos != Vector2.ZERO and dungeon_view.has_method("play_skill_vfx"):
			dungeon_view.play_skill_vfx("attack", mob_pos)
	if camera and camera.has_method("shake"):
		camera.shake(0.15, 0.2)
	_mock_stamina = maxi(0, stamina - AA_COST)
	update_stamina_display()

func execute_heavy() -> void:
	if not _is_fighting() or action_in_flight:
		return
	var stamina := get_display_stamina()
	if stamina < HEAVY_COST:
		if turn_status_label != null:
			turn_status_label.text = "Not enough stamina"
		turn_info.text = "Not enough stamina"
		request_stamina_update.emit()
		return
	var target := _get_current_target()
	if target < 0:
		return
	audio_manager.play_sfx("heavy_hit")
	action_in_flight = true
	request_commands_enabled.emit(false)
	request_turn_state.emit(true, "Heavy Attack!")
	turn_info.text = "Heavy Attack!"
	dojo_bridge.cast(game_state.get_game_id(), target, 0)
	if dungeon_view != null and dungeon_view.has_method("play_attack"):
		dungeon_view.play_attack(target)
		var mob_pos: Vector2 = dungeon_view.get_mob_world_position(target) if dungeon_view.has_method("get_mob_world_position") else Vector2.ZERO
		if mob_pos != Vector2.ZERO and dungeon_view.has_method("spawn_damage_number"):
			dungeon_view.spawn_damage_number(mob_pos, int(game_state.character.get("power", 10)) * 2, false, true)
		if mob_pos != Vector2.ZERO and dungeon_view.has_method("play_skill_vfx"):
			dungeon_view.play_skill_vfx("heavy", mob_pos)
	if camera and camera.has_method("shake"):
		camera.shake(6.0, 8.0)
	_mock_stamina = maxi(0, stamina - HEAVY_COST)
	update_stamina_display()

func execute_end_turn() -> void:
	if not _is_fighting() or action_in_flight:
		return
	if not bool(game_state.fight.get("active", false)):
		request_refresh.emit()
		return
	audio_manager.play_sfx("click")
	action_in_flight = true
	request_commands_enabled.emit(false)
	request_turn_state.emit(false, "Enemy Turn")
	turn_info.text = "Ending turn..."
	dojo_bridge.finish(game_state.get_game_id())
	if dungeon_view != null and dungeon_view.has_method("play_mob_turn"):
		dungeon_view.play_mob_turn()
		audio_manager.play_sfx("enemy_attack")
		var player_pos: Vector2 = dungeon_view.get_player_world_position() if dungeon_view.has_method("get_player_world_position") else Vector2.ZERO
		var alive_mobs := _count_alive_mobs()
		if player_pos != Vector2.ZERO and alive_mobs > 0 and dungeon_view.has_method("spawn_damage_number"):
			dungeon_view.spawn_damage_number(player_pos, alive_mobs * 5)
	if camera and camera.has_method("shake"):
		camera.shake(0.25, 0.3)
	request_turn_order_update.emit()

func execute_defend() -> void:
	if not _is_fighting() or action_in_flight:
		return
	audio_manager.play_sfx("shield_block")
	_defending = true
	action_in_flight = true
	request_commands_enabled.emit(false)
	request_turn_state.emit(false, "Defending...")
	request_status_icons_update.emit()
	turn_info.text = "Defending..."
	if dungeon_view != null and dungeon_view.has_method("_play_sprite_anim"):
		var player_sprite := dungeon_view.get("_player_sprite") as AnimatedSprite2D
		dungeon_view._play_sprite_anim(player_sprite, "defend")
	dojo_bridge.finish(game_state.get_game_id())
	if dungeon_view != null and dungeon_view.has_method("play_mob_turn"):
		dungeon_view.play_mob_turn()
		var player_pos_fx: Vector2 = dungeon_view.get_player_world_position() if dungeon_view.has_method("get_player_world_position") else Vector2.ZERO
		if player_pos_fx != Vector2.ZERO and dungeon_view.has_method("play_skill_vfx"):
			dungeon_view.play_skill_vfx("defend", player_pos_fx)
		var player_pos: Vector2 = dungeon_view.get_player_world_position() if dungeon_view.has_method("get_player_world_position") else Vector2.ZERO
		var alive_mobs := _count_alive_mobs()
		var raw_damage := alive_mobs * 5
		var displayed_damage := int(raw_damage / 2)
		if player_pos != Vector2.ZERO and alive_mobs > 0 and dungeon_view.has_method("spawn_damage_number"):
			dungeon_view.spawn_damage_number(player_pos, displayed_damage, false, false, true)
	if camera and camera.has_method("shake"):
		camera.shake(2.0, 8.0)
	request_turn_order_update.emit()

func auto_finish(reason: String) -> void:
	if auto_finishing:
		return
	auto_finishing = true
	turn_info.text = reason
	if turn_status_label != null:
		turn_status_label.text = reason
	request_commands_enabled.emit(false)
	get_tree().create_timer(1.5).timeout.connect(func():
		auto_finishing = false
		if _is_fighting() and bool(game_state.fight.get("active", false)):
			dojo_bridge.finish(game_state.get_game_id())
		else:
			dojo_bridge.pull_entities_snapshot()
	)

func get_display_stamina() -> int:
	if _mock_stamina >= 0:
		return _mock_stamina
	return int(game_state.character.get("stamina", 0))

func sync_mock_stamina() -> void:
	_mock_stamina = int(game_state.character.get("stamina", 0))
	_defending = false
	request_status_icons_update.emit()

func is_defending() -> bool:
	return _defending

func _count_alive_mobs() -> int:
	var mob_count := int(game_state.fight.get("mob_count", 0))
	var packed: int = parse_int(game_state.fight.get("mob_healths", 0))
	var count := 0
	for i in range(mob_count):
		if unpack_mob_hp(packed, i) > 0:
			count += 1
	return count

func _get_current_target() -> int:
	if targeting_system != null and targeting_system.active and targeting_system.current_target >= 0:
		return targeting_system.current_target
	return first_alive_mob()

func update_stamina_display() -> void:
	var stamina := get_display_stamina()
	var max_st := int(game_state.character.get("max_stamina", 100))
	stamina_bar.max_value = max_st
	stamina_bar.value = stamina
	stamina_label.text = "Stamina %d / %d" % [stamina, max_st]
	request_stamina_update.emit()

func first_alive_mob() -> int:
	var mob_count := int(game_state.fight.get("mob_count", 0))
	var packed: int = parse_int(game_state.fight.get("mob_healths", 0))
	for i in range(mob_count):
		if unpack_mob_hp(packed, i) > 0:
			return i
	return -1

func unpack_mob_hp(packed: int, mob_id: int) -> int:
	return (packed >> (mob_id * 16)) & 0xFFFF

func parse_int(value: Variant) -> int:
	if value is int:
		return value
	if value is String:
		var text := String(value)
		if text.begins_with("0x"):
			return int("0x" + text.trim_prefix("0x"))
		if text.is_valid_int():
			return int(text)
	return 0

func count_alive_mobs() -> int:
	return _count_alive_mobs()

func _is_fighting() -> bool:
	return is_fighting_fn.is_valid() and bool(is_fighting_fn.call())
