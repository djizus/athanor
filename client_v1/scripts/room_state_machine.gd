extends RefCounted

enum RoomState {
	ENTERING, # Fade in, title card (client only)
	EXPLORING, # Player can move freely (client only)
	COMBAT_INTRO, # Battle trigger hit, camera moving to combat position
	COMBAT, # Active fight (contract calls: start/cast/finish)
	CLEARED, # All mobs dead, doors revealing
	EXITING, # Player walking to door (choose() at fork, visual-only elsewhere)
}

signal state_changed(new_state: int, old_state: int)

var current: int = RoomState.ENTERING

func transition_to(new_state: int) -> void:
	if new_state == current:
		return
	var old := current
	current = new_state
	state_changed.emit(new_state, old)

func is_exploring() -> bool:
	return current == RoomState.EXPLORING or current == RoomState.CLEARED

func is_in_combat() -> bool:
	return current == RoomState.COMBAT or current == RoomState.COMBAT_INTRO
