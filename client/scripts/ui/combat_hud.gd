class_name CombatHUD
extends CanvasLayer

signal ability_selected(index: int)
signal end_turn_requested
signal ability_cancelled

@export var combat_manager: CombatManager
@export var stamina_resource: StaminaResource
@export var health_resource: Resource

var ability_buttons: Array = []
var abilities: Array[AbilityResource] = []
var cooldowns: Array[int] = [0, 0, 0, 0, 0]
var selected_ability_index: int = -1

var _hp_bar: ProgressBar
var _stamina_bar: ProgressBar
var _phase_label: Label
var _zone_label: Label
var _enemy_panel: VBoxContainer
var _enemy_name_label: Label
var _enemy_hp_bar: ProgressBar
var _end_turn_button: Button

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	layer = 64
	_create_ui()
	_connect_runtime_signals()

func show_combat_ui() -> void:
	visible = true
	abilities = [
		AbilityResource.create_strike(),
		AbilityResource.create_dash(),
		AbilityResource.create_cleave(),
		AbilityResource.create_fireball(),
		AbilityResource.create_guard(),
	]
	selected_ability_index = -1
	for i: int in range(cooldowns.size()):
		cooldowns[i] = 0
	_populate_ability_buttons()
	_on_stamina_updated()
	_on_health_updated()
	if combat_manager != null:
		_on_phase_changed(combat_manager.current_phase)
	else:
		_on_phase_changed(CombatManager.Phase.PLAYER_TURN)
	clear_enemy_info()

func hide_combat_ui() -> void:
	selected_ability_index = -1
	abilities.clear()
	visible = false
	ability_cancelled.emit()

func _on_stamina_updated() -> void:
	if _stamina_bar == null or stamina_resource == null:
		return
	_stamina_bar.max_value = max(stamina_resource.max_stamina, 1)
	_stamina_bar.value = stamina_resource.value
	_refresh_ability_button_states()

func _on_health_updated() -> void:
	if _hp_bar == null or health_resource == null:
		return
	var max_hp_value: Variant = health_resource.get("max_hp")
	var hp_value: Variant = health_resource.get("hp")
	if max_hp_value == null or hp_value == null:
		return
	_hp_bar.max_value = max(float(max_hp_value), 1.0)
	_hp_bar.value = clamp(float(hp_value), 0.0, _hp_bar.max_value)

func _on_phase_changed(phase: int) -> void:
	if _phase_label == null:
		return
	match phase:
		CombatManager.Phase.PLAYER_TURN:
			_phase_label.text = "Your Turn"
		CombatManager.Phase.ENEMY_TURN:
			_phase_label.text = "Enemy Turn"
		_:
			_phase_label.text = "Resolving"
	_refresh_ability_button_states()

func _on_ability_pressed(index: int) -> void:
	if index < 0 or index >= abilities.size():
		return
	if selected_ability_index == index:
		selected_ability_index = -1
		ability_cancelled.emit()
	else:
		selected_ability_index = index
		ability_selected.emit(index)
	_refresh_ability_button_states()

func _on_end_turn_pressed() -> void:
	selected_ability_index = -1
	ability_cancelled.emit()
	end_turn_requested.emit()
	_refresh_ability_button_states()

func update_cooldowns(cooldowns_array: Array[int]) -> void:
	for i: int in range(cooldowns.size()):
		if i < cooldowns_array.size():
			cooldowns[i] = max(cooldowns_array[i], 0)
		else:
			cooldowns[i] = 0
	_refresh_ability_button_states()

func update_enemy_info(name: String, hp: int, max_hp: int) -> void:
	if _enemy_panel == null:
		return
	_enemy_name_label.text = name
	_enemy_hp_bar.max_value = max(max_hp, 1)
	_enemy_hp_bar.value = clamp(hp, 0, max_hp)
	_enemy_panel.visible = true

func clear_enemy_info() -> void:
	if _enemy_panel == null:
		return
	_enemy_name_label.text = ""
	_enemy_hp_bar.value = 0
	_enemy_hp_bar.max_value = 1
	_enemy_panel.visible = false

func _create_ui() -> void:
	var top_bar: HBoxContainer = HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_top = 12.0
	top_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_theme_constant_override("separation", 24)
	add_child(top_bar)

	_zone_label = Label.new()
	_zone_label.text = "Zone"
	top_bar.add_child(_zone_label)

	_enemy_panel = VBoxContainer.new()
	_enemy_panel.visible = false
	_enemy_panel.custom_minimum_size = Vector2(220, 0)
	top_bar.add_child(_enemy_panel)

	_enemy_name_label = Label.new()
	_enemy_name_label.text = ""
	_enemy_panel.add_child(_enemy_name_label)

	_enemy_hp_bar = ProgressBar.new()
	_enemy_hp_bar.max_value = 1
	_enemy_hp_bar.value = 0
	_enemy_hp_bar.custom_minimum_size = Vector2(220, 18)
	_enemy_panel.add_child(_enemy_hp_bar)

	var bottom_bar: HBoxContainer = HBoxContainer.new()
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_bottom = -16.0
	bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_bar.add_theme_constant_override("separation", 10)
	add_child(bottom_bar)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(180, 20)
	_hp_bar.max_value = 1
	_hp_bar.value = 1
	var hp_fill: StyleBoxFlat = StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.84, 0.22, 0.22, 1.0)
	_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	bottom_bar.add_child(_hp_bar)

	_stamina_bar = ProgressBar.new()
	_stamina_bar.custom_minimum_size = Vector2(180, 20)
	_stamina_bar.max_value = 1
	_stamina_bar.value = 1
	var stamina_fill: StyleBoxFlat = StyleBoxFlat.new()
	stamina_fill.bg_color = Color(0.22, 0.46, 0.86, 1.0)
	_stamina_bar.add_theme_stylebox_override("fill", stamina_fill)
	bottom_bar.add_child(_stamina_bar)

	for i: int in range(5):
		var btn: Button = _create_ability_button(i)
		bottom_bar.add_child(btn)

	_end_turn_button = Button.new()
	_end_turn_button.text = "End Turn"
	_end_turn_button.custom_minimum_size = Vector2(120, 72)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	bottom_bar.add_child(_end_turn_button)

	_phase_label = Label.new()
	_phase_label.text = "Resolving"
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.custom_minimum_size = Vector2(100, 24)
	bottom_bar.add_child(_phase_label)

func _connect_runtime_signals() -> void:
	if combat_manager != null:
		if !combat_manager.combat_started.is_connected(show_combat_ui):
			combat_manager.combat_started.connect(show_combat_ui)
		if !combat_manager.combat_ended.is_connected(hide_combat_ui):
			combat_manager.combat_ended.connect(hide_combat_ui)
		if !combat_manager.phase_changed.is_connected(_on_phase_changed):
			combat_manager.phase_changed.connect(_on_phase_changed)

	if stamina_resource != null:
		if !stamina_resource.updated.is_connected(_on_stamina_updated):
			stamina_resource.updated.connect(_on_stamina_updated)

	if health_resource != null and health_resource.has_signal("hp_changed"):
		var hp_callable: Callable = Callable(self, "_on_health_updated")
		if !health_resource.is_connected("hp_changed", hp_callable):
			health_resource.connect("hp_changed", hp_callable)
	if health_resource != null and health_resource.has_signal("max_hp_changed"):
		var max_hp_callable: Callable = Callable(self, "_on_health_updated")
		if !health_resource.is_connected("max_hp_changed", max_hp_callable):
			health_resource.connect("max_hp_changed", max_hp_callable)

func _create_ability_button(index: int) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(112, 72)
	button.clip_contents = true
	button.pressed.connect(func() -> void: _on_ability_pressed(index))

	var content: VBoxContainer = VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.grow_horizontal = Control.GROW_DIRECTION_BOTH
	content.grow_vertical = Control.GROW_DIRECTION_BOTH
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 2)
	button.add_child(content)

	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(24, 24)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(icon_rect)

	var name_label: Label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(name_label)

	var cost_label: Label = Label.new()
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(cost_label)

	var cooldown_label: Label = Label.new()
	cooldown_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cooldown_label.visible = false
	button.add_child(cooldown_label)

	button.set_meta("name_label", name_label)
	button.set_meta("cost_label", cost_label)
	button.set_meta("cooldown_label", cooldown_label)
	button.set_meta("icon_rect", icon_rect)
	ability_buttons.append(button)
	return button

func _populate_ability_buttons() -> void:
	for i: int in range(ability_buttons.size()):
		var button: Button = ability_buttons[i]
		var name_label: Label = button.get_meta("name_label")
		var cost_label: Label = button.get_meta("cost_label")
		var icon_rect: TextureRect = button.get_meta("icon_rect")
		if i < abilities.size():
			var ability: AbilityResource = abilities[i]
			name_label.text = ability.name
			cost_label.text = "Cost %d" % ability.stamina_cost
			icon_rect.texture = ability.icon
			button.visible = true
		else:
			name_label.text = ""
			cost_label.text = ""
			icon_rect.texture = null
			button.visible = false
	_refresh_ability_button_states()

func _refresh_ability_button_states() -> void:
	for i: int in range(ability_buttons.size()):
		var button: Button = ability_buttons[i]
		if i >= abilities.size():
			button.disabled = true
			continue

		var ability: AbilityResource = abilities[i]
		var can_pay: bool = stamina_resource == null or stamina_resource.can_afford(ability.stamina_cost)
		var is_on_cooldown: bool = i < cooldowns.size() and cooldowns[i] > 0
		var is_player_phase: bool = true
		if combat_manager != null:
			is_player_phase = combat_manager.current_phase == CombatManager.Phase.PLAYER_TURN

		button.disabled = !can_pay or is_on_cooldown or !is_player_phase
		button.modulate = Color(1, 1, 1, 0.4 if button.disabled else 1.0)

		var cooldown_label: Label = button.get_meta("cooldown_label")
		if is_on_cooldown:
			cooldown_label.text = str(cooldowns[i])
			cooldown_label.visible = true
		else:
			cooldown_label.visible = false

		if i == selected_ability_index:
			var selected_style: StyleBoxFlat = StyleBoxFlat.new()
			selected_style.bg_color = Color(0.2, 0.2, 0.2, 1.0)
			selected_style.border_width_left = 2
			selected_style.border_width_top = 2
			selected_style.border_width_right = 2
			selected_style.border_width_bottom = 2
			selected_style.border_color = Color(1.0, 0.85, 0.2)
			button.add_theme_stylebox_override("normal", selected_style)
			button.add_theme_stylebox_override("hover", selected_style)
			button.add_theme_stylebox_override("pressed", selected_style)
		else:
			button.remove_theme_stylebox_override("normal")
			button.remove_theme_stylebox_override("hover")
			button.remove_theme_stylebox_override("pressed")
