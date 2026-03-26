class_name DamageCalculator
extends RefCounted


## Matches abilities.cairo compute_damage_with_stats exactly.
## damage = max(base + offense - defense, 1). If result is 0, returns 1.
static func compute_damage_with_stats(base_damage: int, attacker_offense: int, target_defense: int) -> int:
	var combined := base_damage + attacker_offense
	var damage := 1
	if combined > target_defense:
		damage = combined - target_defense
	else:
		damage = 1

	if damage == 0:
		return 1
	return damage


## Matches abilities.cairo compute_telegraph_damage exactly.
## damage = max(base - defense, 1). If result is 0, returns 1.
static func compute_telegraph_damage(base_damage: int, target_defense: int) -> int:
	var damage := 1
	if base_damage > target_defense:
		damage = base_damage - target_defense
	else:
		damage = 1

	if damage == 0:
		return 1
	return damage
