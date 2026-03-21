extends CanvasLayer

const MAX_MOBS := 4
const DEFAULT_MOB_HP := 20

@onready var fight_panel: PanelContainer = %FightPanel
@onready var attack_button: Button = %AttackButton
@onready var end_turn_button: Button = %EndTurnButton
@onready var player_hp_bar: ProgressBar = %PlayerHPBar
@onready var stamina_bar: ProgressBar = %StaminaBar

@onready var mob_row_0: HBoxContainer = %MobRow0
@onready var mob_row_1: HBoxContainer = %MobRow1
@onready var mob_row_2: HBoxContainer = %MobRow2
@onready var mob_row_3: HBoxContainer = %MobRow3

var mob_rows: Array[HBoxContainer]

func _ready() -> void:
	mob_rows = [mob_row_0, mob_row_1, mob_row_2, mob_row_3]
	for row in mob_rows:
		var bar: ProgressBar = row.get_node("Bar")
		bar.max_value = DEFAULT_MOB_HP

	game_state.character_updated.connect(_on_character_updated)
	game_state.fight_updated.connect(_on_fight_updated)
	game_state.dungeon_updated.connect(_on_dungeon_updated)
	_refresh()

func _on_character_updated(_character: Dictionary) -> void:
	_refresh()

func _on_fight_updated(_fight: Dictionary) -> void:
	_refresh()

func _on_dungeon_updated(_dungeon: Dictionary) -> void:
	_refresh()

func _refresh() -> void:
	var max_hp := int(game_state.character.get("max_health", 100))
	var hp := int(game_state.character.get("health", 0))
	var max_stamina := int(game_state.character.get("max_stamina", 100))
	var stamina := int(game_state.character.get("stamina", 0))

	player_hp_bar.max_value = max_hp
	player_hp_bar.value = hp
	player_hp_bar.get_node("Label").text = "HP %d / %d" % [hp, max_hp]

	stamina_bar.max_value = max_stamina
	stamina_bar.value = stamina
	stamina_bar.get_node("Label").text = "Stamina %d / %d" % [stamina, max_stamina]

	var in_fight := bool(game_state.fight.get("active", false))
	var completed := bool(game_state.dungeon.get("completed", false))
	var failed := bool(game_state.dungeon.get("failed", false))
	fight_panel.visible = in_fight and not completed and not failed

	attack_button.disabled = not in_fight or _first_alive_mob() < 0
	end_turn_button.disabled = not in_fight
	_update_mob_rows()

func _update_mob_rows() -> void:
	var mob_count := int(game_state.fight.get("mob_count", 0))
	var packed: int = _parse_int(game_state.fight.get("mob_healths", 0))
	for index in range(MAX_MOBS):
		var row := mob_rows[index]
		row.visible = index < mob_count
		if row.visible:
			var hp := _unpack_mob_hp(packed, index)
			var label: Label = row.get_node("Name")
			var bar: ProgressBar = row.get_node("Bar")
			label.text = "Mob %d" % index
			bar.value = hp
			bar.get_node("Label").text = "%d / %d" % [hp, int(bar.max_value)]

func _on_attack_button_pressed() -> void:
	var target := _first_alive_mob()
	if target < 0:
		return
	dojo_bridge.cast(game_state.get_game_id(), target, 0)

func _on_end_turn_button_pressed() -> void:
	dojo_bridge.finish(game_state.get_game_id())

func _first_alive_mob() -> int:
	var mob_count := int(game_state.fight.get("mob_count", 0))
	var packed: int = _parse_int(game_state.fight.get("mob_healths", 0))
	for index in range(mob_count):
		if _unpack_mob_hp(packed, index) > 0:
			return index
	return -1

func _unpack_mob_hp(packed: int, mob_id: int) -> int:
	return (packed >> (mob_id * 16)) & 0xFFFF

func _parse_int(value: Variant) -> int:
	if value is int:
		return value
	if value is String:
		var text := String(value)
		if text.begins_with("0x"):
			return int("0x" + text.trim_prefix("0x"))
		if text.is_valid_int():
			return int(text)
	return 0
