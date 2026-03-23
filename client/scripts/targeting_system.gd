extends Node2D

signal target_selected(mob_id: int)
signal target_cleared

var active := false
var current_target: int = -1
var _mob_nodes: Array = []
var _ring: Sprite2D = null

func _ready() -> void:
	_ring = Sprite2D.new()
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for x in range(64):
		for y in range(64):
			var dx := (float(x) - 32.0) / 32.0
			var dy := (float(y) - 32.0) / 32.0
			var d := sqrt(dx * dx + dy * dy)
			var a := 0.0
			if d > 0.7 and d < 1.0:
				a = smoothstep(1.0, 0.85, d) * smoothstep(0.7, 0.85, d) * 0.7
			img.set_pixel(x, y, Color(1.0, 0.85, 0.3, a))
	_ring.texture = ImageTexture.create_from_image(img)
	_ring.scale = Vector2(2.5, 1.5)
	_ring.visible = false
	_ring.z_index = -1
	add_child(_ring)

func activate(mob_nodes: Array) -> void:
	_mob_nodes.clear()
	for node in mob_nodes:
		if node is Node2D:
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
		var mouse_pos := get_global_mouse_position()
		var closest_id := -1
		var closest_dist := 100.0
		for i in range(_mob_nodes.size()):
			if not is_instance_valid(_mob_nodes[i]):
				continue
			var dist := mouse_pos.distance_to(_mob_nodes[i].global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest_id = i
		if closest_id >= 0:
			_set_target(closest_id)
			get_viewport().set_input_as_handled()

	if event.is_action_pressed("ui_accept") and current_target >= 0:
		target_selected.emit(current_target)
		get_viewport().set_input_as_handled()

	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
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
		_ring.global_position = _mob_nodes[mob_id].global_position
		target_selected.emit(mob_id)
	else:
		_ring.visible = false

func _process(_delta: float) -> void:
	if active and current_target >= 0 and current_target < _mob_nodes.size():
		if is_instance_valid(_mob_nodes[current_target]):
			_ring.global_position = _mob_nodes[current_target].global_position
	if active and _ring.visible:
		var pulse := (sin(Time.get_ticks_msec() * 0.005) + 1.0) * 0.5
		_ring.modulate.a = 0.5 + pulse * 0.5
