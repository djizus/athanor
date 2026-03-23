extends RefCounted

# Per-zone room configuration
const ZONE_CONFIGS := {
	0: {
		"name": "Entrance",
		"player_spawn": Vector3(0, 0, 6),
		"battle_pos": Vector3(0, 0, 2),
		"door_north": Vector3(0, 1, -9), # forward door
		"door_south": Vector3(0, 1, 9), # back door (entry)
		"has_fork": true,
		"door_left": Vector3(-9, 1, 0),
		"door_right": Vector3(9, 1, 0),
	},
	1: {
		"name": "Left Cavern",
		"player_spawn": Vector3(9, 0, 0), # from east door
		"battle_pos": Vector3(0, 0, 0),
		"door_north": Vector3(0, 1, -9),
		"door_east": Vector3(9, 1, 0),
		"has_fork": false,
	},
	2: {
		"name": "Right Passage",
		"player_spawn": Vector3(-9, 0, 0), # from west door
		"battle_pos": Vector3(0, 0, 0),
		"door_north": Vector3(0, 1, -9),
		"door_west": Vector3(-9, 1, 0),
		"has_fork": false,
	},
	3: {
		"name": "Deep Hall",
		"player_spawn": Vector3(0, 0, 9), # from south
		"battle_pos": Vector3(0, 0, -2),
		"door_north": Vector3(0, 1, -9),
		"door_south": Vector3(0, 1, 9),
		"has_fork": false,
	},
	4: {
		"name": "Final Chamber",
		"player_spawn": Vector3(0, 0, 9),
		"battle_pos": Vector3(0, 0, -2),
		"door_south": Vector3(0, 1, 9), # entry only
		"has_fork": false,
	},
}

static func get_zone(zone_id: int) -> Dictionary:
	return ZONE_CONFIGS.get(zone_id, ZONE_CONFIGS[0])
