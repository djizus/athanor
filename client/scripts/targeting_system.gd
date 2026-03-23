extends Node3D

signal target_selected(mob_id: int)
signal target_cleared

var active := false
var current_target: int = -1
var _mob_nodes: Array[Node3D] = []
var _ring: MeshInstance3D = null

func _ready() -> void:
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 0.7
	torus.rings = 16
	torus.ring_segments = 24
	_ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.3, 0.2, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring.material_override = mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	_ring.rotation.x = deg_to_rad(90)
	add_child(_ring)

func activate(mob_nodes: Array) -> void:
	_mob_nodes.clear()
	for node in mob_nodes:
		if node is Node3D:
			_mob_nodes.append(node)
	active = true
	if current_target < 0 and not _mob_nodes.is_empty():
		_set_target(0)

func deactivate() -> void:
	active = false
	current_target = -1
	_ring.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var camera := get_viewport().get_camera_3d()
		if camera == null:
			return
		var mouse_pos := get_viewport().get_mouse_position()
		var from := camera.project_ray_origin(mouse_pos)
		var dir := camera.project_ray_normal(mouse_pos)
		var closest_id := -1
		var closest_dist := 3.5
		for i in range(_mob_nodes.size()):
			if not is_instance_valid(_mob_nodes[i]):
				continue
			var mob_pos := _mob_nodes[i].global_position + Vector3(0, 1.0, 0)
			var to_mob := mob_pos - from
			var proj := to_mob.dot(dir)
			if proj < 0:
				continue
			var closest_point := from + dir * proj
			var dist := closest_point.distance_to(mob_pos)
			if dist < closest_dist:
				closest_dist = dist
				closest_id = i
		if closest_id >= 0:
			_set_target(closest_id)
			target_selected.emit(closest_id)
			get_viewport().set_input_as_handled()

	if event.is_action_pressed("ui_accept") and current_target >= 0:
		target_selected.emit(current_target)
		get_viewport().set_input_as_handled()

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_TAB:
			_cycle_target(1)
			get_viewport().set_input_as_handled()

func _cycle_target(direction: int) -> void:
	if _mob_nodes.is_empty():
		return
	var next := current_target + direction
	for _attempt in range(_mob_nodes.size()):
		next = wrapi(next, 0, _mob_nodes.size())
		if is_instance_valid(_mob_nodes[next]):
			_set_target(next)
			return
		next += direction

func _set_target(mob_id: int) -> void:
	current_target = mob_id
	if mob_id >= 0 and mob_id < _mob_nodes.size() and is_instance_valid(_mob_nodes[mob_id]):
		_ring.visible = true
		_ring.global_position = _mob_nodes[mob_id].global_position + Vector3(0, 0.05, 0)
		target_selected.emit(mob_id)
	else:
		_ring.visible = false

func _process(_delta: float) -> void:
	if active and current_target >= 0 and current_target < _mob_nodes.size():
		if is_instance_valid(_mob_nodes[current_target]):
			_ring.global_position = _mob_nodes[current_target].global_position + Vector3(0, 0.05, 0)
