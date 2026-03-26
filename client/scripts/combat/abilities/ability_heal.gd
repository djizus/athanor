class_name AbilityHeal
extends Node

const CombatConstants:Script = preload("res://scripts/combat/combat_constants.gd")


func execute(health:HealthResource) -> bool:
	if health == null:
		return false

	health.add_hp(float(CombatConstants.HEAL_AMOUNT))
	return true
