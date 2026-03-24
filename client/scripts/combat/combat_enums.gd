class_name CombatEnums
extends RefCounted

enum Phase {
	IDLE,
	PLAYER_TURN,
	ENEMY_TURN,
	RESOLVE,
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
}

enum TargetMode {
	ADJACENT = 0,
	LINE = 1,
	SELF = 2,
}

enum AbilityID {
	STRIKE = 0,
	DASH = 1,
	GUARD = 2,
}
