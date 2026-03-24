class_name AbilityGuard
extends Node


func execute(combat_stats:CombatStatsResource) -> bool:
	if combat_stats == null:
		return false
	combat_stats.is_guarding = true
	return true


func clear_guard(combat_stats:CombatStatsResource) -> void:
	if combat_stats == null:
		return
	combat_stats.is_guarding = false
