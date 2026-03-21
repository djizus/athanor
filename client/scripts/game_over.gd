extends Control

signal play_again
signal back_to_lobby

@onready var result_title: Label = %ResultTitle
@onready var stats_label: Label = %StatsLabel
@onready var play_again_button: Button = %PlayAgainButton
@onready var lobby_button: Button = %LobbyButton

func setup(completed: bool, failed: bool) -> void:
	if completed:
		result_title.text = "Dungeon Cleared!"
	elif failed:
		result_title.text = "Dungeon Failed"
	else:
		result_title.text = "Game Over"
	_show_stats()

func _show_stats() -> void:
	var hp := int(game_state.character.get("health", 0))
	var max_hp := int(game_state.character.get("max_health", 100))
	var zones_cleared := int(game_state.dungeon.get("zones_cleared", 0))
	var cleared_count := 0
	for i in range(5):
		if (zones_cleared & (1 << i)) != 0:
			cleared_count += 1
	stats_label.text = "Zones cleared: %d / 5\nHP remaining: %d / %d" % [cleared_count, hp, max_hp]

func _on_play_again_pressed() -> void:
	game_state.reset()
	play_again.emit()

func _on_lobby_pressed() -> void:
	game_state.reset()
	back_to_lobby.emit()
