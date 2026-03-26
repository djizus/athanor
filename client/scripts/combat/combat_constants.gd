class_name CombatConstants
extends RefCounted

# contracts/src/constants.cairo
const GRID_WIDTH: int = 8
const GRID_HEIGHT: int = 8

const BASE_STAMINA: int = 80
const MOVE_COST_PER_TILE: int = 10

const STRIKE_COST: int = 20
const STRIKE_COOLDOWN: int = 0
const STRIKE_DAMAGE: int = 15

const DASH_COST: int = 20
const DASH_COOLDOWN: int = 1
const DASH_DAMAGE: int = 10

const HEAL_COST: int = 25
const HEAL_COOLDOWN: int = 3
const HEAL_AMOUNT: int = 20

const SHOVE_COST: int = 20
const SHOVE_COOLDOWN: int = 1
const SHOVE_DAMAGE: int = 5
const SHOVE_PUSH_DISTANCE: int = 2

const SLAM_COST: int = 35
const SLAM_COOLDOWN: int = 2
const SLAM_DAMAGE: int = 10
const SLAM_PUSH_DISTANCE: int = 1

const KILL_STAMINA_BONUS: int = 10
const COLLISION_DAMAGE: int = 5

const HERO_HP: int = 100
const HERO_OFFENSE: int = 20
const HERO_DEFENSE: int = 5
const HERO_SPEED: int = 10

const BRUTE_HP: int = 40
const BRUTE_OFFENSE: int = 15
const BRUTE_DEFENSE: int = 8
const BRUTE_SPEED: int = 5

const CASTER_HP: int = 25
const CASTER_OFFENSE: int = 20
const CASTER_DEFENSE: int = 3
const CASTER_SPEED: int = 8

const FLANKER_HP: int = 40
const FLANKER_OFFENSE: int = 12
const FLANKER_DEFENSE: int = 4
const FLANKER_SPEED: int = 7

const HEAVY_HP: int = 70
const HEAVY_OFFENSE: int = 15
const HEAVY_DEFENSE: int = 10
const HEAVY_SPEED: int = 3

const PULLER_HP: int = 35
const PULLER_OFFENSE: int = 0
const PULLER_DEFENSE: int = 5
const PULLER_SPEED: int = 6

# contracts/src/systems/phase.cairo
const PHASE_EXPLORE: int = 0
const PHASE_PLAYER_TURN: int = 1
const PHASE_ENEMY_TURN: int = 2
const PHASE_COMPLETE: int = 3
const PHASE_FAILED: int = 4

const FACTION_PLAYER: int = 0
const FACTION_ENEMY: int = 1

const ARCHETYPE_HERO: int = 0
const ARCHETYPE_BRUTE: int = 1
const ARCHETYPE_CASTER: int = 2
const ARCHETYPE_FLANKER: int = 3
const ARCHETYPE_HEAVY: int = 4
const ARCHETYPE_PULLER: int = 5

const ABILITY_STRIKE: int = 0
const ABILITY_DASH: int = 1
const ABILITY_HEAL: int = 2
const ABILITY_SHOVE: int = 3
const ABILITY_SLAM: int = 4

const TARGET_SINGLE: int = 0
const TARGET_DIRECTIONAL: int = 1
const TARGET_POSITIONAL: int = 2
const TARGET_SELF: int = 3

const SHAPE_SINGLE_TILE: int = 0
const SHAPE_LINE: int = 1
const SHAPE_CONE: int = 2
const SHAPE_CIRCLE: int = 3
const SHAPE_CROSS: int = 4

const TELEGRAPH_TYPE_DAMAGE: int = 0
const TELEGRAPH_TYPE_PULL: int = 1

static func get_max_hp(archetype: int) -> int:
	match archetype:
		CombatEnums.Archetype.PLAYER:
			return HERO_HP
		CombatEnums.Archetype.BRUTE:
			return BRUTE_HP
		CombatEnums.Archetype.CASTER:
			return CASTER_HP
		CombatEnums.Archetype.FLANKER:
			return FLANKER_HP
		CombatEnums.Archetype.HEAVY:
			return HEAVY_HP
		CombatEnums.Archetype.PULLER:
			return PULLER_HP
		_:
			return 0


static func get_offense(archetype: int) -> int:
	match archetype:
		CombatEnums.Archetype.PLAYER:
			return HERO_OFFENSE
		CombatEnums.Archetype.BRUTE:
			return BRUTE_OFFENSE
		CombatEnums.Archetype.CASTER:
			return CASTER_OFFENSE
		CombatEnums.Archetype.FLANKER:
			return FLANKER_OFFENSE
		CombatEnums.Archetype.HEAVY:
			return HEAVY_OFFENSE
		CombatEnums.Archetype.PULLER:
			return PULLER_OFFENSE
		_:
			return 0


static func get_defense(archetype: int) -> int:
	match archetype:
		CombatEnums.Archetype.PLAYER:
			return HERO_DEFENSE
		CombatEnums.Archetype.BRUTE:
			return BRUTE_DEFENSE
		CombatEnums.Archetype.CASTER:
			return CASTER_DEFENSE
		CombatEnums.Archetype.FLANKER:
			return FLANKER_DEFENSE
		CombatEnums.Archetype.HEAVY:
			return HEAVY_DEFENSE
		CombatEnums.Archetype.PULLER:
			return PULLER_DEFENSE
		_:
			return 0


static func get_speed(archetype: int) -> int:
	match archetype:
		CombatEnums.Archetype.PLAYER:
			return HERO_SPEED
		CombatEnums.Archetype.BRUTE:
			return BRUTE_SPEED
		CombatEnums.Archetype.CASTER:
			return CASTER_SPEED
		CombatEnums.Archetype.FLANKER:
			return FLANKER_SPEED
		CombatEnums.Archetype.HEAVY:
			return HEAVY_SPEED
		CombatEnums.Archetype.PULLER:
			return PULLER_SPEED
		_:
			return 0


static func get_move_cost(archetype: int) -> int:
	match archetype:
		CombatEnums.Archetype.PLAYER:
			return MOVE_COST_PER_TILE
		CombatEnums.Archetype.BRUTE:
			return MOVE_COST_PER_TILE
		CombatEnums.Archetype.CASTER:
			return MOVE_COST_PER_TILE
		CombatEnums.Archetype.FLANKER:
			return MOVE_COST_PER_TILE
		CombatEnums.Archetype.HEAVY:
			return MOVE_COST_PER_TILE
		CombatEnums.Archetype.PULLER:
			return MOVE_COST_PER_TILE
		_:
			return 0


static func ability_cost(ability_id: int) -> int:
	match ability_id:
		CombatEnums.AbilityID.STRIKE:
			return STRIKE_COST
		CombatEnums.AbilityID.DASH:
			return DASH_COST
		CombatEnums.AbilityID.HEAL:
			return HEAL_COST
		CombatEnums.AbilityID.SHOVE:
			return SHOVE_COST
		CombatEnums.AbilityID.SLAM:
			return SLAM_COST
		_:
			return 0


static func ability_cooldown(ability_id: int) -> int:
	match ability_id:
		CombatEnums.AbilityID.STRIKE:
			return STRIKE_COOLDOWN
		CombatEnums.AbilityID.DASH:
			return DASH_COOLDOWN
		CombatEnums.AbilityID.HEAL:
			return HEAL_COOLDOWN
		CombatEnums.AbilityID.SHOVE:
			return SHOVE_COOLDOWN
		CombatEnums.AbilityID.SLAM:
			return SLAM_COOLDOWN
		_:
			return 0
