extends Node

signal command_pressed(action: String)

const TURN_ORDER_SLOTS := 8
const ZONE_CHILDREN := {0: [1, 2], 1: [3], 2: [3], 3: [4], 4: []}
const MINIMAP_POS := {
	0: Vector2(0.5, 0.1),
	1: Vector2(0.2, 0.4),
	2: Vector2(0.8, 0.4),
	3: Vector2(0.5, 0.7),
	4: Vector2(0.5, 0.95),
}

var combat_ctrl = null
var dungeon_view: Node2D
var targeting_system: Node2D

var hp_bar: ProgressBar
var hp_label: Label
var stamina_bar: ProgressBar
var stamina_label: Label
var target_name: Label
var target_hp_bar: ProgressBar
var target_hp_label: Label
var stats_label: Label
var turn_info: Label
var bottom_bar: PanelContainer
var minimap_draw: Control

var _turn_order_bar: HBoxContainer = null
var _turn_slots: Array[PanelContainer] = []
var _turn_slot_labels: Array[Label] = []
var _is_player_turn := true

var _command_panel: PanelContainer = null
var _cmd_buttons: Dictionary = {}
var _cmd_button_cycle: Array[Button] = []
var _selected_command_index := 0
var _stamina_preview_label: Label = null
var _status_icons_label: Label = null

var turn_status_label: Label = null

func build_ui(ui_root: Control) -> void:
	if bottom_bar != null:
		bottom_bar.visible = false
	_build_turn_order_bar(ui_root)
	_build_command_panel(ui_root)

func update_player_bars(in_combat: bool) -> void:
	var max_hp := int(game_state.character.get("max_health", 100))
	var hp := int(game_state.character.get("health", 0))
	var max_stamina := int(game_state.character.get("max_stamina", 100))
	var stamina: int = combat_ctrl.get_display_stamina() if in_combat else int(game_state.character.get("stamina", 0))

	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_label.text = "HP %d / %d" % [hp, max_hp]

	stamina_bar.max_value = max_stamina
	stamina_bar.value = stamina
	stamina_label.text = "Stamina %d / %d" % [stamina, max_stamina]

func show_combat_hud() -> void:
	combat_ctrl.sync_mock_stamina()
	set_turn_state(true, "Your Turn")
	if _command_panel != null:
		_command_panel.modulate.a = 0.0
		_command_panel.visible = true
		var tween := create_tween()
		tween.tween_property(_command_panel, "modulate:a", 1.0, 0.3)
	set_commands_enabled(true)
	set_selected_command_by_key("attack")
	update_turn_order()

func hide_combat_hud() -> void:
	if _command_panel != null:
		var tween := create_tween()
		tween.tween_property(_command_panel, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func(): _command_panel.visible = false)
	update_turn_order()

func set_target_visible(vis: bool) -> void:
	target_name.visible = vis
	target_hp_bar.visible = vis
	target_hp_label.visible = vis

func update_target_bar(mob_name: String = "") -> void:
	var mob_idx: int = combat_ctrl.first_alive_mob()
	if mob_idx < 0:
		target_name.text = ""
		target_hp_bar.value = 0
		target_hp_label.text = ""
		return
	var packed: int = combat_ctrl.parse_int(game_state.fight.get("mob_healths", 0))
	var mob_hp: int = combat_ctrl.unpack_mob_hp(packed, mob_idx)
	var max_hp := 20
	target_name.text = mob_name
	target_hp_bar.max_value = max_hp
	target_hp_bar.value = mob_hp
	target_hp_label.text = "%d / %d" % [mob_hp, max_hp]
	update_command_states()

func update_mob_hp_bars() -> void:
	if dungeon_view == null:
		return
	var mob_count := int(game_state.fight.get("mob_count", 0))
	var packed: int = combat_ctrl.parse_int(game_state.fight.get("mob_healths", 0))
	for i in range(mob_count):
		var hp: int = combat_ctrl.unpack_mob_hp(packed, i)
		if dungeon_view.has_method("update_mob_hp"):
			dungeon_view.update_mob_hp(i, hp, 20)
		if dungeon_view.has_method("update_mob_visual"):
			dungeon_view.update_mob_visual(i, hp, 20)

func update_stats() -> void:
	var hp := int(game_state.character.get("health", 0))
	var max_hp := int(game_state.character.get("max_health", 100))
	var zones_cleared := int(game_state.dungeon.get("zones_cleared", 0))
	var cleared_count := 0
	for i in range(5):
		if (zones_cleared & (1 << i)) != 0:
			cleared_count += 1
	stats_label.text = "Zones cleared: %d / 5\nHP remaining: %d / %d" % [cleared_count, hp, max_hp]

func set_commands_enabled(enabled: bool) -> void:
	for btn in _cmd_buttons.values():
		if btn is Button:
			(btn as Button).disabled = not enabled
	if enabled:
		update_command_states()

func update_command_states() -> void:
	if _cmd_buttons.is_empty():
		return
	var stamina: int = combat_ctrl.get_display_stamina()
	var has_target: bool = combat_ctrl.first_alive_mob() >= 0
	(_cmd_buttons.get("attack") as Button).disabled = combat_ctrl.action_in_flight or stamina < combat_ctrl.AA_COST or not has_target
	(_cmd_buttons.get("heavy") as Button).disabled = combat_ctrl.action_in_flight or stamina < combat_ctrl.HEAVY_COST or not has_target
	(_cmd_buttons.get("defend") as Button).disabled = combat_ctrl.action_in_flight
	(_cmd_buttons.get("end_turn") as Button).disabled = combat_ctrl.action_in_flight

func set_turn_state(is_player_turn: bool, status_text: String) -> void:
	_is_player_turn = is_player_turn
	if turn_status_label != null:
		turn_status_label.text = status_text
		if is_player_turn:
			turn_status_label.add_theme_color_override("font_color", Color(0.831, 0.659, 0.286))
		else:
			turn_status_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	if _command_panel != null:
		_command_panel.self_modulate = Color(1.0, 1.0, 1.0) if is_player_turn else Color(0.72, 0.72, 0.72)
	update_status_icons()
	update_turn_order()

func update_turn_order() -> void:
	if _turn_slots.is_empty():
		return
	var alive_mobs := maxi(combat_ctrl.count_alive_mobs(), 1)
	var cycle := alive_mobs + 1
	for i in range(_turn_slots.size()):
		var slot := _turn_slots[i]
		var label := _turn_slot_labels[i]
		var is_player := (i % cycle) == 0
		label.text = "P" if is_player else "E"
		var current_index := 0 if _is_player_turn else mini(1, cycle - 1)
		var is_current := i == current_index
		if is_current:
			slot.modulate = Color(0.831, 0.659, 0.286) if _is_player_turn else Color(1.0, 0.3, 0.3)
		else:
			slot.modulate = Color(0.52, 0.52, 0.52)

func update_status_icons() -> void:
	if _status_icons_label == null:
		return
	var icons: Array[String] = []
	if combat_ctrl.is_defending():
		icons.append("🛡 Guard")
	icons.append("⚡ Ready" if _is_player_turn else "⏳ Waiting")
	_status_icons_label.text = "Status: %s" % " · ".join(icons)

func cycle_command_focus(direction: int) -> void:
	if _cmd_button_cycle.is_empty():
		return
	for _attempt in range(_cmd_button_cycle.size()):
		_selected_command_index = wrapi(_selected_command_index + direction, 0, _cmd_button_cycle.size())
		var btn := _cmd_button_cycle[_selected_command_index]
		if is_instance_valid(btn) and not btn.disabled:
			btn.grab_focus()
			break

func set_selected_command_by_key(key: String) -> void:
	if _cmd_buttons.is_empty() or not _cmd_buttons.has(key):
		return
	var target_btn := _cmd_buttons[key] as Button
	for i in range(_cmd_button_cycle.size()):
		if _cmd_button_cycle[i] == target_btn:
			_selected_command_index = i
			break

func confirm_selected_command() -> void:
	if _cmd_button_cycle.is_empty():
		return
	var btn := _cmd_button_cycle[_selected_command_index]
	if is_instance_valid(btn) and not btn.disabled:
		btn.emit_signal("pressed")

func cancel_command_selection() -> void:
	if targeting_system != null and targeting_system.active and targeting_system.has_method("_set_target"):
		targeting_system._set_target(-1)
	if turn_status_label != null and _is_player_turn:
		turn_status_label.text = "Your Turn"

func draw_minimap() -> void:
	if minimap_draw == null:
		return
	var size := minimap_draw.size
	var base_radius := 10.0
	var pulse_t := sin(Time.get_ticks_msec() * 0.003)
	var pulse_radius := lerpf(10.0, 14.0, (pulse_t + 1.0) * 0.5)

	for zone_id in ZONE_CHILDREN.keys():
		var from_pos: Vector2 = MINIMAP_POS[zone_id] * size
		var children: Array = ZONE_CHILDREN[zone_id]
		for child_id in children:
			if MINIMAP_POS.has(child_id):
				var to_pos: Vector2 = MINIMAP_POS[child_id] * size
				minimap_draw.draw_line(from_pos, to_pos, Color(0.3, 0.28, 0.22, 0.6), 2.0)

	var current_zone := int(game_state.character.get("current_zone", 0))
	var zones_cleared := int(game_state.dungeon.get("zones_cleared", 0))

	for zone_id in MINIMAP_POS.keys():
		var pos: Vector2 = MINIMAP_POS[zone_id] * size
		var color: Color
		var node_radius := base_radius
		if zone_id == current_zone:
			color = Color(0.831, 0.659, 0.286, 1.0)
			node_radius = pulse_radius
		elif (zones_cleared & (1 << zone_id)) != 0:
			color = Color(0.3, 0.55, 0.35, 1.0)
		else:
			color = Color(0.15, 0.15, 0.18, 0.5)

		minimap_draw.draw_circle(pos + Vector2(0, 1.0), node_radius + 2.0, Color(0.02, 0.02, 0.02, 0.45))
		minimap_draw.draw_circle(pos, node_radius, color)

		minimap_draw.draw_string(
			ThemeDB.fallback_font,
			pos + Vector2(-4, 5),
			str(zone_id),
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			12,
			Color(0.9, 0.9, 0.9, 0.8)
		)

func get_command_panel() -> PanelContainer:
	return _command_panel

func _on_cmd_hover(name: String, cost: String) -> void:
	if _stamina_preview_label == null:
		return
	if cost.is_empty():
		_stamina_preview_label.text = ""
		_stamina_preview_label.remove_theme_color_override("font_color")
		return
	var cost_val := int(cost.replace(" ST", ""))
	var remaining: int = combat_ctrl.get_display_stamina() - cost_val
	_stamina_preview_label.text = "%s\nCost: %s\nRemaining: %d ST" % [name, cost, maxi(remaining, 0)]
	if remaining < 0:
		_stamina_preview_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		_stamina_preview_label.remove_theme_color_override("font_color")

func _on_cmd_unhover() -> void:
	if _stamina_preview_label == null:
		return
	_stamina_preview_label.text = ""
	_stamina_preview_label.remove_theme_color_override("font_color")

func _build_turn_order_bar(ui_root: Control) -> void:
	if ui_root == null:
		return
	_turn_order_bar = HBoxContainer.new()
	_turn_order_bar.name = "TurnOrderBar"
	_turn_order_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_turn_order_bar.position = Vector2(-170, 56)
	_turn_order_bar.add_theme_constant_override("separation", 4)
	for _i in range(TURN_ORDER_SLOTS):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(36, 36)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		slot.add_child(label)
		_turn_order_bar.add_child(slot)
		_turn_slots.append(slot)
		_turn_slot_labels.append(label)
	ui_root.add_child(_turn_order_bar)

func _build_command_panel(ui_root: Control) -> void:
	if ui_root == null:
		return
	_command_panel = PanelContainer.new()
	_command_panel.name = "CommandPanel"
	_command_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_command_panel.offset_top = -96
	_command_panel.offset_bottom = -8
	_command_panel.offset_left = 60
	_command_panel.offset_right = -60

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_command_panel.add_child(hbox)

	var player_info := hp_bar.get_parent().get_parent() as VBoxContainer
	if player_info == null:
		return
	if player_info.get_parent() != null:
		player_info.get_parent().remove_child(player_info)
	player_info.custom_minimum_size = Vector2(260, 0)
	hbox.add_child(player_info)
	_status_icons_label = Label.new()
	_status_icons_label.text = "Status: ⚡ Ready"
	player_info.add_child(_status_icons_label)

	var cmd_center := HBoxContainer.new()
	cmd_center.add_theme_constant_override("separation", 8)
	cmd_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cmd_center.alignment = BoxContainer.ALIGNMENT_CENTER

	_cmd_buttons["attack"] = _create_cmd_button("1 ⚔ Attack", "30 ST", "attack")
	_cmd_buttons["heavy"] = _create_cmd_button("2 ⚡ Heavy", "50 ST", "heavy")
	_cmd_buttons["defend"] = _create_cmd_button("3 🛡 Defend", "0 ST", "defend")
	_cmd_buttons["end_turn"] = _create_cmd_button("4 ⏭ End Turn", "", "end_turn")
	_cmd_button_cycle.clear()
	_cmd_button_cycle.append(_cmd_buttons["attack"] as Button)
	_cmd_button_cycle.append(_cmd_buttons["heavy"] as Button)
	_cmd_button_cycle.append(_cmd_buttons["defend"] as Button)
	_cmd_button_cycle.append(_cmd_buttons["end_turn"] as Button)

	for btn in _cmd_button_cycle:
		cmd_center.add_child(btn)
	hbox.add_child(cmd_center)

	var context := VBoxContainer.new()
	context.custom_minimum_size = Vector2(220, 0)
	context.size_flags_horizontal = Control.SIZE_SHRINK_END
	context.add_theme_constant_override("separation", 4)

	_stamina_preview_label = Label.new()
	_stamina_preview_label.text = ""
	_stamina_preview_label.custom_minimum_size = Vector2(200, 36)
	context.add_child(_stamina_preview_label)

	turn_status_label = Label.new()
	turn_status_label.text = "Your Turn"
	turn_status_label.add_theme_color_override("font_color", Color(0.831, 0.659, 0.286))
	context.add_child(turn_status_label)

	if turn_info.get_parent() != null:
		turn_info.get_parent().remove_child(turn_info)
	turn_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	turn_info.custom_minimum_size = Vector2(220, 0)
	context.add_child(turn_info)
	hbox.add_child(context)

	ui_root.add_child(_command_panel)
	_command_panel.visible = false

func _create_cmd_button(text: String, cost: String, key: String) -> Button:
	var btn := Button.new()
	btn.text = text + ("\n" + cost if not cost.is_empty() else "")
	btn.custom_minimum_size = Vector2(118, 60)
	btn.focus_mode = Control.FOCUS_ALL
	btn.pressed.connect(func() -> void: command_pressed.emit(key))
	btn.mouse_entered.connect(func() -> void: _on_cmd_hover(text, cost))
	btn.mouse_exited.connect(_on_cmd_unhover)
	btn.focus_entered.connect(func() -> void: set_selected_command_by_key(key))
	return btn
