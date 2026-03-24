class_name TelegraphSystem
extends Node

signal telegraph_added(data:Dictionary)
signal telegraph_resolved(data:Dictionary)
signal telegraphs_cleared

var _telegraphs:Array[Dictionary] = []

func add_telegraph(cells:Array[Vector2i], damage:float, source_id:Variant, turn:int) -> void:
	var data:Dictionary = {
		"cells": cells.duplicate(),
		"damage": damage,
		"source_id": source_id,
		"turn_created": turn,
	}
	_telegraphs.append(data)
	telegraph_added.emit(data)

func get_active() -> Array:
	return _telegraphs.duplicate(true)

func resolve_telegraphs(current_turn:int) -> Array:
	var resolved:Array[Dictionary] = []
	var remaining:Array[Dictionary] = []

	for data in _telegraphs:
		if int(data.get("turn_created", current_turn)) < current_turn:
			resolved.append(data)
			telegraph_resolved.emit(data)
		else:
			remaining.append(data)

	_telegraphs = remaining
	return resolved

func clear_all() -> void:
	_telegraphs.clear()
	telegraphs_cleared.emit()
