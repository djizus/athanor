class_name AbilityHeal
extends Node


func execute(health:HealthResource) -> bool:
	if health == null:
		return false

	health.add_hp(20.0)
	return true
