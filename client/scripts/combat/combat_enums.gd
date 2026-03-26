class_name CombatEnums
extends RefCounted

enum Phase {
	IDLE,
	PLAYER_TURN,
	RESOLVE,
	ENEMY_TURN,
	COMBAT_OVER,
}

enum Faction {
	PLAYER = 0,
	ENEMY = 1,
}

enum Archetype {
	PLAYER = 0,
	BRUTE = 1,
	CASTER = 2,
	FLANKER = 3,
	HEAVY = 4,
	PULLER = 5,
}

enum TargetMode {
	ADJACENT = 0,
	LINE = 1,
	SELF = 2,
}

enum AbilityID {
	STRIKE = 0,
	DASH = 1,
	HEAL = 2,
	SHOVE = 3,
	SLAM = 4,
}

enum TelegraphType {
	DAMAGE = 0,
	PULL = 1,
}
