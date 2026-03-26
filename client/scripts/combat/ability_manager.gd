class_name AbilityManager
extends Node

signal ability_selected(ability:AbilityResource)
signal ability_used(ability:AbilityResource, target_data:Dictionary)
signal ability_cancelled

@export var abilities:Array[AbilityResource] = []
@export var stamina_resource:StaminaResource

var _selected_index:int = -1


func select_ability(index:int) -> void:
	if index < 0 || index >= abilities.size():
		cancel_selection()
		return

	_selected_index = index
	ability_selected.emit(abilities[_selected_index])


func cancel_selection() -> void:
	_selected_index = -1
	ability_cancelled.emit()


func get_selected() -> AbilityResource:
	if _selected_index < 0 || _selected_index >= abilities.size():
		return null
	return abilities[_selected_index]


func use_ability(target_data:Dictionary) -> bool:
	var ability:AbilityResource = get_selected()
	if ability == null:
		return false
	if stamina_resource == null:
		return false
	if ability.current_cooldown > 0:
		return false
	if !stamina_resource.spend(ability.stamina_cost):
		return false

	ability.start_cooldown()
	ability_used.emit(ability, target_data)
	return true


func tick_cooldowns() -> void:
	for ability in abilities:
		if ability != null:
			ability.tick_cooldown()
