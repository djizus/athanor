class_name StaminaResource
extends IntResource

signal depleted

@export var max_stamina:int = 100

func set_value(_value:int)->void:
	var _next_value:int = max(_value, 0)
	super.set_value(_next_value)
	if value == 0:
		depleted.emit()

func spend(amount:int)->bool:
	if !can_afford(amount):
		return false
	set_value(value - amount)
	return true

func refill()->void:
	set_value(max_stamina)

func can_afford(amount:int)->bool:
	return value >= amount

func reset_resource()->void:
	value = max_stamina

func prepare_save()->Resource:
	return self.duplicate()

func prepare_load(_data:Resource)->void:
	value = _data.value
	max_stamina = _data.max_stamina
