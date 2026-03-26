class_name EnemyGridAI
extends RefCounted

func compute_intent(self_pos:Vector2i, _player_pos:Vector2i, _grid_state:Dictionary) -> Dictionary:
	return {
		"move_to": self_pos,
		"telegraph_cells": Array([], TYPE_VECTOR2I, "", null),
		"telegraph_damage": 0.0,
	}
