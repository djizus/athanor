class_name CombatStatsResource
extends SaveableResource

const HERO_OFFENSE:int = 20
const HERO_DEFENSE:int = 5
const HERO_SPEED:int = 10
const HERO_MOVE_COST:int = 10
const HERO_MAX_HP:int = 100
const HERO_MAX_STAMINA:int = 100

const BRUTE_DEFAULT := {"offense": 15, "defense": 8, "speed": 5, "move_cost": 0, "max_hp": 40, "max_stamina": 0}
const CASTER_DEFAULT := {"offense": 20, "defense": 3, "speed": 8, "move_cost": 0, "max_hp": 25, "max_stamina": 0}

@export var offense:int = HERO_OFFENSE
@export var defense:int = HERO_DEFENSE
@export var speed:int = HERO_SPEED
@export var move_cost:int = HERO_MOVE_COST
@export var max_hp:int = HERO_MAX_HP
@export var max_stamina:int = HERO_MAX_STAMINA

@export var reset_offense:int = HERO_OFFENSE
@export var reset_defense:int = HERO_DEFENSE
@export var reset_speed:int = HERO_SPEED
@export var reset_move_cost:int = HERO_MOVE_COST
@export var reset_max_hp:int = HERO_MAX_HP
@export var reset_max_stamina:int = HERO_MAX_STAMINA

func reset_resource()->void:
	offense = reset_offense
	defense = reset_defense
	speed = reset_speed
	move_cost = reset_move_cost
	max_hp = reset_max_hp
	max_stamina = reset_max_stamina

func prepare_save()->Resource:
	return self.duplicate()

func prepare_load(_data:Resource)->void:
	offense = _data.offense
	defense = _data.defense
	speed = _data.speed
	move_cost = _data.move_cost
	max_hp = _data.max_hp
	max_stamina = _data.max_stamina
