class_name AbilityResource
extends Resource

const STRIKE:int = 0
const DASH:int = 1
const CLEAVE:int = 2
const FIREBALL:int = 3
const GUARD:int = 4

enum TargetMode {
	SINGLE_TARGET = 0,
	DIRECTIONAL = 1,
	POSITIONAL = 2,
	SELF = 3,
}

@export var id:int = STRIKE
@export var name:String = ""
@export var stamina_cost:int = 0
@export var cooldown_turns:int = 0
@export var target_mode:int = TargetMode.SINGLE_TARGET
@export var aoe_shape:int = 0
@export var base_damage:int = 0
@export var icon:Texture2D

static func _new_ability()->AbilityResource:
	return load("res://scripts/resources/ability_resource.gd").new()

static func create_strike()->AbilityResource:
	var ability:AbilityResource = _new_ability()
	ability.id = STRIKE
	ability.name = "Strike"
	ability.stamina_cost = 15
	ability.cooldown_turns = 0
	ability.target_mode = TargetMode.SINGLE_TARGET
	ability.aoe_shape = 0
	ability.base_damage = 20
	return ability

static func create_dash()->AbilityResource:
	var ability:AbilityResource = _new_ability()
	ability.id = DASH
	ability.name = "Dash"
	ability.stamina_cost = 20
	ability.cooldown_turns = 2
	ability.target_mode = TargetMode.DIRECTIONAL
	ability.aoe_shape = 1
	ability.base_damage = 10
	return ability

static func create_cleave()->AbilityResource:
	var ability:AbilityResource = _new_ability()
	ability.id = CLEAVE
	ability.name = "Cleave"
	ability.stamina_cost = 25
	ability.cooldown_turns = 1
	ability.target_mode = TargetMode.DIRECTIONAL
	ability.aoe_shape = 2
	ability.base_damage = 15
	return ability

static func create_fireball()->AbilityResource:
	var ability:AbilityResource = _new_ability()
	ability.id = FIREBALL
	ability.name = "Fireball"
	ability.stamina_cost = 30
	ability.cooldown_turns = 2
	ability.target_mode = TargetMode.POSITIONAL
	ability.aoe_shape = 3
	ability.base_damage = 25
	return ability

static func create_guard()->AbilityResource:
	var ability:AbilityResource = _new_ability()
	ability.id = GUARD
	ability.name = "Guard"
	ability.stamina_cost = 10
	ability.cooldown_turns = 3
	ability.target_mode = TargetMode.SELF
	ability.aoe_shape = 4
	ability.base_damage = 0
	return ability
