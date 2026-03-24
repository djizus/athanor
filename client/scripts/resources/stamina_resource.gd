class_name StaminaResource
extends ValueResource

signal stamina_spent(cost:int)
signal stamina_refilled
signal stamina_depleted

@export var max_value:int = 100 : set = set_max_value
@export var value:int = 100 : set = set_value

func set_max_value(_max_value:int) -> void:
	max_value = maxi(_max_value, 0)
	set_value(value)

func set_value(_value:int) -> void:
	value = clampi(_value, 0, max_value)
	updated.emit()

func can_spend(cost:int) -> bool:
	if cost < 0:
		return false
	return value >= cost

func spend(cost:int) -> bool:
	if !can_spend(cost):
		return false

	value = value - cost
	stamina_spent.emit(cost)
	if value == 0:
		stamina_depleted.emit()
	return true

func refill() -> void:
	value = max_value
	stamina_refilled.emit()

func reset_resource() -> void:
	refill()

func prepare_save() -> Resource:
	return self.duplicate()

func prepare_load(_data:Resource) -> void:
	if _data == null:
		return
	max_value = _data.max_value
	value = _data.value
