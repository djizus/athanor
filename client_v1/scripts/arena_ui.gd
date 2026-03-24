extends Node

var _arena: Node
var _zone_title_label: Label = null

@onready var minimap_draw: Control = %MinimapDraw
@onready var hp_bar: ProgressBar = %HPBar
@onready var hp_label: Label = %HPLabel
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var stamina_label: Label = %StaminaLabel
@onready var zone_label: Label = %ZoneLabel
@onready var top_bar: PanelContainer = $"../UILayer/UIRoot/TopBar"
@onready var bottom_bar: PanelContainer = $"../UILayer/UIRoot/BottomBar"
@onready var target_name: Label = %TargetName
@onready var target_hp_bar: ProgressBar = %TargetHPBar
@onready var target_hp_label: Label = %TargetHPLabel

@onready var door_panel: PanelContainer = %DoorPanel
@onready var door_title: Label = %DoorTitle
@onready var left_door_button: Button = %LeftDoorButton
@onready var right_door_button: Button = %RightDoorButton
@onready var continue_button: Button = %ContinueButton

@onready var attack_button: Button = %AttackButton
@onready var end_turn_button: Button = %EndTurnButton
@onready var turn_info: Label = %TurnInfo

@onready var start_fight_button: Button = %StartFightButton

@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_title: Label = %ResultTitle
@onready var stats_label: Label = %StatsLabel
@onready var return_button: Button = %ReturnButton

func setup(arena: Node) -> void:
	_arena = arena

func refresh(state: int, _zone: int, _character: Dictionary, _fight: Dictionary, _dungeon: Dictionary) -> void:
	if _arena == null:
		return
	_update_player_bars()
	minimap_draw.queue_redraw()
	if state == _arena.ArenaState.FIGHTING:
		_update_target_bar()
		_update_mob_hp_bars()
	elif state == _arena.ArenaState.COMPLETED or state == _arena.ArenaState.FAILED:
		_update_stats()

func _update_player_bars() -> void:
	var max_hp := int(game_state.character.get("max_health", 100))
	var hp := int(game_state.character.get("health", 0))
	var max_stamina := int(game_state.character.get("max_stamina", 100))
	var stamina := int(game_state.character.get("stamina", 0))

	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_label.text = "HP %d / %d" % [hp, max_hp]

	stamina_bar.max_value = max_stamina
	stamina_bar.value = stamina
	stamina_label.text = "Stamina %d / %d" % [stamina, max_stamina]

func _show_combat_hud() -> void:
	bottom_bar.modulate.a = 0.0
	bottom_bar.visible = true
	var tween := create_tween()
	tween.tween_property(bottom_bar, "modulate:a", 1.0, 0.3)

func _hide_combat_hud() -> void:
	var tween := create_tween()
	tween.tween_property(bottom_bar, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): bottom_bar.visible = false)

func _set_target_visible(vis: bool) -> void:
	target_name.visible = vis
	target_hp_bar.visible = vis
	target_hp_label.visible = vis

func _update_target_bar() -> void:
	var mob_idx: int = int(_arena.combat_controller.first_alive_mob())
	if mob_idx < 0:
		target_name.text = ""
		target_hp_bar.value = 0
		target_hp_label.text = ""
		return
	var packed: int = _arena.combat_controller.parse_int(game_state.fight.get("mob_healths", 0))
	var mob_hp: int = int(_arena.combat_controller.unpack_mob_hp(packed, mob_idx))
	var max_hp := 20
	target_name.text = _zone_mob_name(int(game_state.character.get("current_zone", 0)))
	target_hp_bar.max_value = max_hp
	target_hp_bar.value = mob_hp
	target_hp_label.text = "%d / %d" % [mob_hp, max_hp]
	attack_button.disabled = _arena.combat_controller.first_alive_mob() < 0 or int(game_state.character.get("stamina", 0)) < _arena.AA_COST
	end_turn_button.disabled = false

func _update_mob_hp_bars() -> void:
	if _arena.dungeon_view == null:
		return
	var mob_count := int(game_state.fight.get("mob_count", 0))
	var packed: int = _arena.combat_controller.parse_int(game_state.fight.get("mob_healths", 0))
	for i in range(mob_count):
		var hp: int = int(_arena.combat_controller.unpack_mob_hp(packed, i))
		if _arena.dungeon_view.has_method("update_mob_hp"):
			_arena.dungeon_view.update_mob_hp(i, hp, 20)
		if _arena.dungeon_view.has_method("update_mob_visual"):
			_arena.dungeon_view.update_mob_visual(i, hp, 20)

func _zone_mob_name(zone_id: int) -> String:
	match zone_id:
		1: return "Ember Fiend"
		2: return "Aether Wraith"
		3: return "Sunken Horror"
		4: return "Crystal Guardian"
		_: return "Creature"

func _update_stats() -> void:
	var hp := int(game_state.character.get("health", 0))
	var max_hp := int(game_state.character.get("max_health", 100))
	var zones_cleared := int(game_state.dungeon.get("zones_cleared", 0))
	var cleared_count := 0
	for i in range(5):
		if (zones_cleared & (1 << i)) != 0:
			cleared_count += 1
	stats_label.text = "Zones cleared: %d / 5\nHP remaining: %d / %d" % [cleared_count, hp, max_hp]

func _draw_minimap() -> void:
	if minimap_draw == null:
		return
	var size := minimap_draw.size
	var radius := 10.0

	for zone_id in _arena.ZONE_CHILDREN.keys():
		var from_pos: Vector2 = _arena.MINIMAP_POS[zone_id] * size
		var children: Array = _arena.ZONE_CHILDREN[zone_id]
		for child_id in children:
			if _arena.MINIMAP_POS.has(child_id):
				var to_pos: Vector2 = _arena.MINIMAP_POS[child_id] * size
				minimap_draw.draw_line(from_pos, to_pos, Color(0.3, 0.28, 0.22, 0.6), 2.0)

	var current_zone := int(game_state.character.get("current_zone", 0))
	var zones_cleared := int(game_state.dungeon.get("zones_cleared", 0))

	for zone_id in _arena.MINIMAP_POS.keys():
		var pos: Vector2 = _arena.MINIMAP_POS[zone_id] * size
		var color: Color
		if zone_id == current_zone:
			color = Color(0.831, 0.659, 0.286, 1.0)
		elif (zones_cleared & (1 << zone_id)) != 0:
			color = Color(0.25, 0.5, 0.3, 1.0)
		else:
			color = Color(0.2, 0.2, 0.24, 0.6)

		minimap_draw.draw_circle(pos, radius, color)
		minimap_draw.draw_string(
			ThemeDB.fallback_font, pos + Vector2(-4, 5),
			str(zone_id), HORIZONTAL_ALIGNMENT_CENTER, -1, 12,
			Color(0.9, 0.9, 0.9, 0.8)
		)

func show_zone_title(title: String) -> void:
	var ui_root := get_node_or_null("../UILayer/UIRoot") as Control
	if ui_root == null:
		return

	if _zone_title_label == null or not is_instance_valid(_zone_title_label):
		_zone_title_label = Label.new()
		_zone_title_label.name = "ZoneTitleCard"
		_zone_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_zone_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_zone_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_zone_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_zone_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_zone_title_label.position = Vector2(0, 120)
		_zone_title_label.size = Vector2(ui_root.size.x, 96)
		_zone_title_label.add_theme_font_size_override("font_size", 34)
		_zone_title_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8, 1.0))
		_zone_title_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.95))
		_zone_title_label.add_theme_constant_override("outline_size", 10)
		ui_root.add_child(_zone_title_label)

	_zone_title_label.size = Vector2(ui_root.size.x, 96)
	_zone_title_label.text = title
	_zone_title_label.modulate.a = 0.0
	_zone_title_label.position.y = 140
	var tween := create_tween()
	tween.tween_property(_zone_title_label, "modulate:a", 1.0, 0.15)
	tween.parallel().tween_property(_zone_title_label, "position:y", 120.0, 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.2)
	tween.tween_property(_zone_title_label, "modulate:a", 0.0, 0.35)
