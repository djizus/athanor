class_name HealthResource
extends Resource

signal updated
signal dead

@export var max_hp:float = 100.0
@export var hp:float = 100.0 : set = set_hp


func set_hp(new_hp:float) -> void:
	hp = clampf(new_hp, 0.0, max_hp)
	updated.emit()
	if hp <= 0.0:
		dead.emit()


func add_hp(amount:float) -> void:
	self.hp = hp + amount


func is_dead() -> bool:
	return hp <= 0.0
