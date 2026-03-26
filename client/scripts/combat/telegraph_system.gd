class_name TelegraphSystem
extends Node

signal telegraph_added(data:Dictionary)
signal telegraph_resolved(data:Dictionary)
signal telegraphs_cleared

var _telegraphs:Array[Dictionary] = []

func add_telegraph(
		cells:Array[Vector2i],
		damage:float,
		source_id:Variant,
		turn:int,
		telegraph_type:int = CombatEnums.TelegraphType.DAMAGE,
		pull_source:Vector2i = Vector2i.ZERO,
		pull_distance:int = 0
	) -> void:
	var data:Dictionary = {
		"cells": cells.duplicate(),
		"damage": damage,
		"source_id": source_id,
		"turn_created": turn,
		"telegraph_type": telegraph_type,
		"pull_source": pull_source,
		"pull_distance": pull_distance,
	}
	_telegraphs.append(data)
	telegraph_added.emit(data)

func get_active() -> Array:
	return _telegraphs.duplicate(true)

func resolve_telegraphs(current_turn:int) -> Array:
	var pull_resolved:Array[Dictionary] = []
	var damage_resolved:Array[Dictionary] = []
	var remaining:Array[Dictionary] = []

	for data in _telegraphs:
		if int(data.get("turn_created", current_turn)) < current_turn:
			var telegraph_type:int = int(data.get("telegraph_type", CombatEnums.TelegraphType.DAMAGE))
			if telegraph_type == CombatEnums.TelegraphType.PULL:
				pull_resolved.append(data)
			else:
				damage_resolved.append(data)
			telegraph_resolved.emit(data)
		else:
			remaining.append(data)

	_telegraphs = remaining
	var resolved:Array[Dictionary] = []
	resolved.append_array(pull_resolved)
	resolved.append_array(damage_resolved)
	return resolved

func clear_all() -> void:
	_telegraphs.clear()
	telegraphs_cleared.emit()
