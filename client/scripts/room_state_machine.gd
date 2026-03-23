extends Node

enum State {
    ENTERING,
    EXPLORING,
    COMBAT_INTRO,
    COMBAT,
    CLEARED,
    EXITING,
    COMPLETED,
    FAILED,
}

signal state_changed(new_state: int, old_state: int)

var current: int = State.ENTERING
var _locked := false

func transition_to(new_state: int) -> void:
    if _locked:
        push_warning("[RoomSM] Transition blocked (locked): %s -> %s" % [
            State.keys()[current], State.keys()[new_state]])
        return
    var old := current
    current = new_state
    state_changed.emit(new_state, old)

func lock() -> void:
    _locked = true

func unlock() -> void:
    _locked = false

func is_state(s: int) -> bool:
    return current == s
