extends Node3D

# 3D dungeon world manager — loads zone rooms, manages character/mob models, plays animations.
# Called by arena.gd on state changes. Does NOT contain game logic — only visuals.

const ZONE_COLORS := {
	0: Color(0.831, 0.659, 0.286),  # Amber
	1: Color(0.722, 0.314, 0.188),  # Ember
	2: Color(0.620, 0.353, 0.620),  # Aether
	3: Color(0.165, 0.353, 0.541),  # Sunken
	4: Color(0.165, 0.541, 0.416),  # Crystal
}

const MOB_POSITIONS := {
	1: [Vector3(0, 0, -2)],
	2: [Vector3(-1.5, 0, -2), Vector3(1.5, 0, -2)],
	4: [Vector3(-2, 0, -2), Vector3(2, 0, -2), Vector3(-1, 0, -3.5), Vector3(1, 0, -3.5)],
}

const PLAYER_POSITION := Vector3(0, 0, 2)

@onready var zone_anchor: Node3D = $ZoneAnchor
@onready var player_anchor: Node3D = $PlayerAnchor
@onready var mob_anchor: Node3D = $MobAnchor

var _current_zone_id: int = -1
var _player_model: Node3D = null
var _mob_models: Array[Node3D] = []
var _zone_scenes: Dictionary = {}

func _ready() -> void:
	# Preload zone scenes if they exist
	for i in range(5):
		var path := "res://scenes/zones/zone_%d.tscn" % i
		if ResourceLoader.exists(path):
			_zone_scenes[i] = load(path)

func load_zone(zone_id: int) -> void:
	if zone_id == _current_zone_id:
		return
	_current_zone_id = zone_id

	# Clear current zone
	for child in zone_anchor.get_children():
		child.queue_free()

	# Load zone scene if available
	if _zone_scenes.has(zone_id):
		var instance: Node3D = _zone_scenes[zone_id].instantiate()
		zone_anchor.add_child(instance)
	else:
		# Fallback: colored platform
		_create_fallback_platform(zone_id)

	# Position player
	if _player_model != null:
		_player_model.position = PLAYER_POSITION

func spawn_hero() -> void:
	if _player_model != null:
		return

	# Try to load GLB model
	var hero_path := "res://assets/models/characters/hero.glb"
	if ResourceLoader.exists(hero_path):
		var scene: PackedScene = load(hero_path)
		_player_model = scene.instantiate()
	else:
		# Fallback: capsule mesh
		_player_model = _create_fallback_character(Color(0.831, 0.659, 0.286))

	_player_model.position = PLAYER_POSITION
	player_anchor.add_child(_player_model)

func spawn_mobs(count: int, zone_id: int) -> void:
	clear_mobs()
	var positions: Array = MOB_POSITIONS.get(count, [])
	if positions.is_empty():
		positions = [Vector3(0, 0, -2)]

	var mob_type := _get_mob_type(zone_id)
	var mob_path := "res://assets/models/characters/%s.glb" % mob_type

	for i in range(count):
		var mob: Node3D
		if ResourceLoader.exists(mob_path):
			mob = (load(mob_path) as PackedScene).instantiate()
		else:
			mob = _create_fallback_character(ZONE_COLORS.get(zone_id, Color.RED))

		mob.name = "Mob%d" % i
		if i < positions.size():
			mob.position = positions[i]
		else:
			mob.position = Vector3(randf_range(-2, 2), 0, randf_range(-3, -1))
		mob_anchor.add_child(mob)
		_mob_models.append(mob)

func clear_mobs() -> void:
	for mob in _mob_models:
		if is_instance_valid(mob):
			mob.queue_free()
	_mob_models.clear()

func update_mob_visual(mob_id: int, hp: int, max_hp: int) -> void:
	if mob_id >= _mob_models.size():
		return
	var mob := _mob_models[mob_id]
	if not is_instance_valid(mob):
		return
	if hp <= 0:
		# Death: scale down + fade
		var tween := create_tween()
		tween.tween_property(mob, "scale", Vector3.ZERO, 0.4).set_ease(Tween.EASE_IN)
		tween.tween_callback(mob.queue_free)

func play_attack(target_mob_id: int) -> void:
	# Hero attack animation
	if _player_model != null:
		_play_anim(_player_model, "attack_cast")
	# Mob hit reaction
	if target_mob_id < _mob_models.size():
		var mob := _mob_models[target_mob_id]
		if is_instance_valid(mob):
			_play_anim(mob, "hit_reaction")
			_flash_white(mob, 0.15)

func play_mob_turn() -> void:
	for mob in _mob_models:
		if is_instance_valid(mob):
			_play_anim(mob, "attack")
	if _player_model != null:
		_play_anim(_player_model, "hit_reaction")
		_flash_white(_player_model, 0.15)

func play_player_death() -> void:
	if _player_model != null:
		_play_anim(_player_model, "death")

func play_victory() -> void:
	if _player_model != null:
		_play_anim(_player_model, "victory")

func on_state_changed(state: int, zone_id: int, prev_state: int) -> void:
	# ArenaState enum values: FORK=0, PRE_FIGHT=1, FIGHTING=2, CLEARED=3, COMPLETED=4, FAILED=5
	load_zone(zone_id)
	spawn_hero()

	var camera_rig: Node = get_parent().get_node_or_null("CameraRig")

	match state:
		0:  # FORK
			clear_mobs()
			if camera_rig and camera_rig.has_method("combat_zoom_out"):
				camera_rig.combat_zoom_out()
		1:  # PRE_FIGHT
			var mob_count: int = {0: 0, 1: 1, 2: 1, 3: 2, 4: 4}.get(zone_id, 0)
			spawn_mobs(mob_count, zone_id)
			if camera_rig and camera_rig.has_method("combat_zoom_out"):
				camera_rig.combat_zoom_out()
		2:  # FIGHTING
			if camera_rig and camera_rig.has_method("combat_zoom_in"):
				camera_rig.combat_zoom_in()
		3:  # CLEARED
			clear_mobs()
			if camera_rig and camera_rig.has_method("zone_transition"):
				camera_rig.zone_transition()
		4:  # COMPLETED
			clear_mobs()
			play_victory()
		5:  # FAILED
			play_player_death()

# --- Helpers ---

func _get_mob_type(zone_id: int) -> String:
	match zone_id:
		1: return "mob_ember"
		2: return "mob_aether"
		3: return "mob_sunken"
		4: return "mob_crystal"
		_: return "mob_ember"

func _play_anim(node: Node3D, anim_name: String) -> void:
	var anim_player: AnimationPlayer = node.get_node_or_null("AnimationPlayer")
	if anim_player == null:
		# Search children
		for child in node.get_children():
			if child is AnimationPlayer:
				anim_player = child
				break
	if anim_player != null and anim_player.has_animation(anim_name):
		anim_player.play(anim_name)

func _flash_white(node: Node3D, duration: float) -> void:
	# Find first MeshInstance3D and flash it
	var mesh := _find_mesh(node)
	if mesh == null:
		return
	var original_mat: Material = mesh.get_surface_override_material(0)
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color.WHITE
	flash_mat.emission_enabled = true
	flash_mat.emission = Color.WHITE
	flash_mat.emission_energy_multiplier = 2.0
	mesh.set_surface_override_material(0, flash_mat)
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(mesh):
			mesh.set_surface_override_material(0, original_mat)
	)

func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh(child)
		if found != null:
			return found
	return null

func _create_fallback_platform(zone_id: int) -> void:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(8, 0.3, 8)
	mesh_inst.mesh = box
	var mat := StandardMaterial3D.new()
	var color: Color = ZONE_COLORS.get(zone_id, Color(0.2, 0.2, 0.2))
	mat.albedo_color = color * 0.3
	mat.roughness = 0.8
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.3
	mesh_inst.material_override = mat
	mesh_inst.position = Vector3(0, -0.15, 0)
	zone_anchor.add_child(mesh_inst)

func _create_fallback_character(color: Color) -> Node3D:
	var root := Node3D.new()
	var mesh_inst := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.2
	mesh_inst.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.4
	mat.metallic = 0.3
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.8
	mesh_inst.material_override = mat
	mesh_inst.position = Vector3(0, 0.6, 0)
	root.add_child(mesh_inst)
	return root
