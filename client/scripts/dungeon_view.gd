extends Node3D

const COLOR_LOCKED := Color(0.12, 0.11, 0.16, 1.0)
const COLOR_AVAILABLE := Color(0.831, 0.659, 0.286, 1.0)
const COLOR_CURRENT := Color(0.267, 0.722, 0.851, 1.0)
const COLOR_CLEARED := Color(0.25, 0.5, 0.3, 1.0)
const COLOR_PLAYER := Color(0.831, 0.659, 0.286, 1.0)
const COLOR_PATH := Color(0.18, 0.16, 0.13, 1.0)

const EMISSION_AVAILABLE := Color(0.6, 0.45, 0.1)
const EMISSION_CURRENT := Color(0.15, 0.5, 0.6)
const EMISSION_CLEARED := Color(0.1, 0.25, 0.1)
const EMISSION_PLAYER := Color(0.6, 0.45, 0.1)

@onready var start_button: Button = %StartButton
@onready var status_label: Label = %DungeonStatus
@onready var player_marker: MeshInstance3D = %PlayerMarker

@onready var zone_0_mesh: MeshInstance3D = %Zone0Mesh
@onready var zone_1_mesh: MeshInstance3D = %Zone1Mesh
@onready var zone_2_mesh: MeshInstance3D = %Zone2Mesh
@onready var zone_3_mesh: MeshInstance3D = %Zone3Mesh
@onready var zone_4_mesh: MeshInstance3D = %Zone4Mesh

var zone_meshes: Dictionary
var zone_positions: Dictionary

func _ready() -> void:
	_build_meshes()

	zone_meshes = {
		0: zone_0_mesh,
		1: zone_1_mesh,
		2: zone_2_mesh,
		3: zone_3_mesh,
		4: zone_4_mesh,
	}
	zone_positions = {
		0: Vector3(0, 0.9, -4),
		1: Vector3(-4, 0.9, 0),
		2: Vector3(4, 0.9, 0),
		3: Vector3(0, 0.9, 4),
		4: Vector3(0, 0.9, 8),
	}

	game_state.character_updated.connect(_on_character_updated)
	game_state.dungeon_updated.connect(_on_dungeon_updated)
	game_state.fight_updated.connect(_on_fight_updated)

	status_label.text = "Navigate the dungeon"
	_refresh_scene()

func _build_meshes() -> void:
	if DisplayServer.get_name() == "headless":
		return

	var zone_box := BoxMesh.new()
	zone_box.size = Vector3(2.8, 0.5, 2.8)
	zone_0_mesh.mesh = zone_box
	zone_1_mesh.mesh = zone_box
	zone_2_mesh.mesh = zone_box
	zone_3_mesh.mesh = zone_box
	zone_4_mesh.mesh = zone_box

	var capsule := CapsuleMesh.new()
	capsule.radius = 0.42
	capsule.height = 1.4
	player_marker.mesh = capsule
	var player_mat := StandardMaterial3D.new()
	player_mat.albedo_color = COLOR_PLAYER
	player_mat.roughness = 0.3
	player_mat.metallic = 0.4
	player_mat.emission_enabled = true
	player_mat.emission = EMISSION_PLAYER
	player_mat.emission_energy_multiplier = 1.5
	player_marker.material_override = player_mat

	var path_line := CylinderMesh.new()
	path_line.top_radius = 0.1
	path_line.bottom_radius = 0.1
	path_line.height = 4.0
	var path_mat := StandardMaterial3D.new()
	path_mat.albedo_color = COLOR_PATH
	path_mat.roughness = 0.85
	path_mat.metallic = 0.05
	path_mat.emission_enabled = true
	path_mat.emission = Color(0.08, 0.06, 0.04)
	path_mat.emission_energy_multiplier = 0.3
	var path_lines: Node3D = get_node("PathLines")
	for child in path_lines.get_children():
		if child is MeshInstance3D:
			child.mesh = path_line
			child.material_override = path_mat

func _on_character_updated(_character: Dictionary) -> void:
	_refresh_scene()

func _on_dungeon_updated(_dungeon: Dictionary) -> void:
	_refresh_scene()

func _on_fight_updated(_fight: Dictionary) -> void:
	_refresh_scene()

func _refresh_scene() -> void:
	var has_character := not game_state.character.is_empty()
	start_button.disabled = not _can_start_fight()

	if has_character:
		var current_zone := int(game_state.character.get("current_zone", 0))
		player_marker.visible = true
		player_marker.position = zone_positions.get(current_zone, Vector3.ZERO)
		status_label.text = "Current zone: %d" % current_zone
	else:
		player_marker.visible = false

	for zone_id in zone_meshes.keys():
		_apply_zone_color(zone_id)

func _apply_zone_color(zone_id: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mesh_inst: MeshInstance3D = zone_meshes[zone_id]
	var material := StandardMaterial3D.new()
	material.roughness = 0.7
	material.metallic = 0.15
	if _is_zone_cleared(zone_id):
		material.albedo_color = COLOR_CLEARED
		material.emission_enabled = true
		material.emission = EMISSION_CLEARED
		material.emission_energy_multiplier = 0.5
	elif _is_zone_current(zone_id):
		material.albedo_color = COLOR_CURRENT
		material.emission_enabled = true
		material.emission = EMISSION_CURRENT
		material.emission_energy_multiplier = 1.2
	elif _is_zone_available(zone_id):
		material.albedo_color = COLOR_AVAILABLE
		material.emission_enabled = true
		material.emission = EMISSION_AVAILABLE
		material.emission_energy_multiplier = 0.8
	else:
		material.albedo_color = COLOR_LOCKED
	mesh_inst.material_override = material

func _is_zone_current(zone_id: int) -> bool:
	if game_state.character.is_empty():
		return zone_id == 0
	return int(game_state.character.get("current_zone", 0)) == zone_id

func _is_zone_available(zone_id: int) -> bool:
	if game_state.character.is_empty():
		return zone_id == 0
	var current_zone := int(game_state.character.get("current_zone", 0))
	if current_zone == 0:
		return zone_id == 1 or zone_id == 2
	if current_zone == 1 or current_zone == 2:
		return zone_id == 3
	if current_zone == 3:
		return zone_id == 4
	return false

func _is_zone_cleared(zone_id: int) -> bool:
	var bitmap := int(game_state.dungeon.get("zones_cleared", 0))
	return (bitmap & (1 << zone_id)) != 0

func _can_start_fight() -> bool:
	if game_state.character.is_empty():
		return false
	if bool(game_state.dungeon.get("completed", false)) or bool(game_state.dungeon.get("failed", false)):
		return false
	if bool(game_state.fight.get("active", false)):
		return false
	var current_zone := int(game_state.character.get("current_zone", 0))
	return current_zone != 0 and not _is_zone_cleared(current_zone)

func _try_choose(zone_id: int) -> void:
	if game_state.character.is_empty():
		status_label.text = "Not in dungeon yet"
		return
	var current_zone := int(game_state.character.get("current_zone", 0))
	var game_id := game_state.get_game_id()
	if current_zone != 0:
		status_label.text = "Only fork zone requires choose()"
		return
	if zone_id == 1:
		dojo_bridge.choose(game_id, dojo_bridge.DIRECTION_LEFT)
		status_label.text = "choose(Left) submitted"
	elif zone_id == 2:
		dojo_bridge.choose(game_id, dojo_bridge.DIRECTION_RIGHT)
		status_label.text = "choose(Right) submitted"

func _on_start_button_pressed() -> void:
	dojo_bridge.start(game_state.get_game_id())
	status_label.text = "start() submitted"

func _on_zone_0_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		status_label.text = "Spawn zone — you start here"

func _on_zone_1_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_choose(1)

func _on_zone_2_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_choose(2)

func _on_zone_3_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		status_label.text = "Zone auto-advances after cleared fights"

func _on_zone_4_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		status_label.text = "Final zone reached via auto-advance"
