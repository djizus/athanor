class_name CombatHUD
extends CanvasLayer

@onready var hp_bar:ProgressBar = %HPBar
@onready var stamina_bar:ProgressBar = %StaminaBar
@onready var ability_bar:HBoxContainer = %AbilityBar
@onready var confirm_button:Button = %ConfirmButton
@onready var reset_button:Button = %ResetButton
@onready var phase_indicator:Label = %PhaseIndicator
@onready var turn_counter:Label = %TurnCounter

var _turn_manager:TurnManager
var _ability_manager:AbilityManager
var _combat_manager:Node
var _stamina:StaminaResource
var _health:HealthResource

var _ability_buttons:Array[Button] = []
var _selected_button:int = -1

var _default_style:StyleBoxFlat
var _selected_style:StyleBoxFlat

func _ready() -> void:
	_build_styles()
	_apply_resource_bar_styles()
	for child in ability_bar.get_children():
		if child is Button:
			var button:Button = child
			_ability_buttons.push_back(button)
			button.pressed.connect(_on_ability_button_pressed.bind(_ability_buttons.size() - 1))
	confirm_button.pressed.connect(_on_confirm_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	visible = false

func _unhandled_input(event:InputEvent) -> void:
	if !visible || _ability_manager == null:
		return
	if !(event is InputEventKey) || !event.pressed || event.echo:
		return
	var key_event:InputEventKey = event
	match key_event.keycode:
		KEY_1:
			_ability_manager.select_ability(0)
			get_viewport().set_input_as_handled()
		KEY_2:
			_ability_manager.select_ability(1)
			get_viewport().set_input_as_handled()
		KEY_3:
			_ability_manager.select_ability(2)
			get_viewport().set_input_as_handled()
		KEY_4:
			_ability_manager.select_ability(3)
			get_viewport().set_input_as_handled()
		KEY_5:
			_ability_manager.select_ability(4)
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			_on_confirm_pressed()
			get_viewport().set_input_as_handled()
		KEY_R:
			_on_reset_pressed()
			get_viewport().set_input_as_handled()

func bind_combat_manager(combat_manager:Node) -> void:
	_disconnect_current()
	if combat_manager == null:
		visible = false
		return

	_combat_manager = combat_manager
	_turn_manager = combat_manager.get("turn_manager")
	_ability_manager = combat_manager.get("ability_manager")
	var player_data:Dictionary = combat_manager.get("player")
	_stamina = player_data.get("stamina", null)
	_health = player_data.get("health", null)

	if _turn_manager != null:
		_turn_manager.phase_changed.connect(_on_phase_changed)
		_turn_manager.player_turn_started.connect(_refresh)
		_turn_manager.enemy_turn_started.connect(_refresh)
		_turn_manager.resolve_started.connect(_refresh)

	if _ability_manager != null:
		_ability_manager.ability_selected.connect(_on_ability_selected)
		_ability_manager.ability_cancelled.connect(_on_ability_cancelled)
		_ability_manager.ability_used.connect(_on_ability_used)

	if _stamina != null:
		_stamina.updated.connect(_refresh_stamina)

	if _health != null:
		_health.updated.connect(_refresh_hp)

	visible = true
	_refresh()

func clear_bindings() -> void:
	_disconnect_current()
	visible = false

func _disconnect_current() -> void:
	if _turn_manager != null:
		if _turn_manager.phase_changed.is_connected(_on_phase_changed):
			_turn_manager.phase_changed.disconnect(_on_phase_changed)
		if _turn_manager.player_turn_started.is_connected(_refresh):
			_turn_manager.player_turn_started.disconnect(_refresh)
		if _turn_manager.enemy_turn_started.is_connected(_refresh):
			_turn_manager.enemy_turn_started.disconnect(_refresh)
		if _turn_manager.resolve_started.is_connected(_refresh):
			_turn_manager.resolve_started.disconnect(_refresh)

	if _ability_manager != null:
		if _ability_manager.ability_selected.is_connected(_on_ability_selected):
			_ability_manager.ability_selected.disconnect(_on_ability_selected)
		if _ability_manager.ability_cancelled.is_connected(_on_ability_cancelled):
			_ability_manager.ability_cancelled.disconnect(_on_ability_cancelled)
		if _ability_manager.ability_used.is_connected(_on_ability_used):
			_ability_manager.ability_used.disconnect(_on_ability_used)

	if _stamina != null && _stamina.updated.is_connected(_refresh_stamina):
		_stamina.updated.disconnect(_refresh_stamina)

	if _health != null && _health.updated.is_connected(_refresh_hp):
		_health.updated.disconnect(_refresh_hp)

	_turn_manager = null
	_ability_manager = null
	_combat_manager = null
	_stamina = null
	_health = null
	_selected_button = -1
	_apply_selection_style()

func _refresh() -> void:
	_refresh_hp()
	_refresh_stamina()
	_refresh_phase()
	_refresh_turn_counter()
	_refresh_abilities()

func _refresh_hp() -> void:
	if _health == null:
		hp_bar.value = 0
		hp_bar.max_value = 100
		return
	hp_bar.max_value = _health.max_hp
	hp_bar.value = _health.hp

func _refresh_stamina() -> void:
	if _stamina == null:
		stamina_bar.value = 0
		stamina_bar.max_value = 100
		return
	stamina_bar.max_value = _stamina.max_value
	stamina_bar.value = _stamina.value

func _refresh_phase() -> void:
	if _turn_manager == null:
		phase_indicator.text = "IDLE"
		return
	_on_phase_changed(_turn_manager.phase)

func _refresh_turn_counter() -> void:
	if _turn_manager == null:
		turn_counter.text = "Turn 0"
		return
	turn_counter.text = "Turn %d" % maxi(1, _turn_manager.turn_count + 1)

func _refresh_abilities() -> void:
	for i in range(_ability_buttons.size()):
		var button:Button = _ability_buttons[i]
		var ability:AbilityResource = _ability_manager.abilities[i] if _ability_manager != null && i < _ability_manager.abilities.size() else null
		var overlay:ColorRect = button.get_node_or_null("CooldownOverlay")
		var overlay_label:Label = button.get_node_or_null("CooldownOverlay/CooldownLabel")
		if ability == null:
			button.text = "--"
			button.disabled = true
			if overlay != null:
				overlay.visible = false
			continue

		button.text = "%d:%s %d" % [i + 1, ability.ability_name, ability.stamina_cost]
		var on_cooldown:bool = ability.current_cooldown > 0
		if overlay != null:
			overlay.visible = on_cooldown
		if overlay_label != null:
			overlay_label.text = "CD%d" % ability.current_cooldown
		button.disabled = false
	_apply_selection_style()

func _on_confirm_pressed() -> void:
	if _combat_manager != null && _combat_manager.has_method("confirm_turn"):
		_combat_manager.confirm_turn()
	elif _turn_manager != null:
		_turn_manager.end_player_turn()

func _on_reset_pressed() -> void:
	if _combat_manager != null && _combat_manager.has_method("reset_turn"):
		_combat_manager.reset_turn()

func _on_ability_button_pressed(index:int) -> void:
	if _ability_manager == null:
		return
	_ability_manager.select_ability(index)

func _on_ability_selected(ability:AbilityResource) -> void:
	if _ability_manager == null:
		return
	_selected_button = _ability_manager.abilities.find(ability)
	_apply_selection_style()

func _on_ability_cancelled() -> void:
	_selected_button = -1
	_apply_selection_style()

func _on_ability_used(_ability:AbilityResource, _target_data:Dictionary) -> void:
	_refresh()

func _apply_selection_style() -> void:
	for i in range(_ability_buttons.size()):
		var button:Button = _ability_buttons[i]
		button.add_theme_stylebox_override("normal", _selected_style if i == _selected_button else _default_style)

func _on_phase_changed(phase:int) -> void:
	var is_player_turn:bool = phase == CombatEnums.Phase.PLAYER_TURN
	confirm_button.visible = is_player_turn
	reset_button.visible = is_player_turn
	for button in _ability_buttons:
		button.disabled = !is_player_turn

	match phase:
		CombatEnums.Phase.PLAYER_TURN:
			phase_indicator.text = "YOUR TURN"
		CombatEnums.Phase.ENEMY_TURN:
			phase_indicator.text = "ENEMY"
		CombatEnums.Phase.RESOLVE:
			phase_indicator.text = "RESOLVE"
		CombatEnums.Phase.COMBAT_OVER:
			phase_indicator.text = "OVER"
		_:
			phase_indicator.text = ""

func _build_styles() -> void:
	_default_style = StyleBoxFlat.new()
	_default_style.bg_color = Color(0.12, 0.12, 0.18, 0.85)
	_default_style.border_color = Color(0.3, 0.3, 0.4)
	_default_style.set_border_width_all(1)
	_default_style.set_corner_radius_all(1)
	_default_style.set_content_margin_all(1)

	_selected_style = _default_style.duplicate()
	_selected_style.border_color = Color(1.0, 0.86, 0.2)
	_selected_style.set_border_width_all(1)

func _apply_resource_bar_styles() -> void:
	var bar_background:StyleBoxFlat = StyleBoxFlat.new()
	bar_background.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	bar_background.border_color = Color(0.25, 0.25, 0.3, 0.9)
	bar_background.set_border_width_all(1)

	var hp_fill:StyleBoxFlat = StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.2, 0.8, 0.2, 0.95)

	var stamina_fill:StyleBoxFlat = StyleBoxFlat.new()
	stamina_fill.bg_color = Color(0.3, 0.5, 0.9, 0.95)

	hp_bar.add_theme_stylebox_override("background", bar_background)
	hp_bar.add_theme_stylebox_override("fill", hp_fill)
	stamina_bar.add_theme_stylebox_override("background", bar_background.duplicate())
	stamina_bar.add_theme_stylebox_override("fill", stamina_fill)
