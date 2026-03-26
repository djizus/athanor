class_name AbilityResource
extends Resource

@export var ability_name:String = ""
@export var ability_id:int = 0
@export var stamina_cost:int = 0
@export var cooldown_turns:int = 0
@export var current_cooldown:int = 0
@export var target_mode:int = 0
@export var range_tiles:int = 0
@export var base_damage:float = 0.0
@export_multiline var description:String = ""

func can_use(current_stamina:int) -> bool:
	return current_stamina >= stamina_cost && current_cooldown <= 0

func start_cooldown() -> void:
	current_cooldown = maxi(cooldown_turns, 0)

func tick_cooldown() -> void:
	if current_cooldown > 0:
		current_cooldown -= 1
