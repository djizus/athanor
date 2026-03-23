extends Node

## Combat effects utility — hit freeze and particles

var _particle_texture: Texture2D = null

func _ready() -> void:
	_particle_texture = _load_tex("res://assets/vfx/slash.png")

func hit_freeze(duration: float = 0.04) -> void:
	get_tree().paused = true
	await get_tree().create_timer(duration, true, false, true).timeout
	get_tree().paused = false

func spawn_hit_particles(pos: Vector2, color: Color = Color.WHITE) -> void:
	var particles := GPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 8
	particles.lifetime = 0.3
	particles.explosiveness = 0.9
	particles.z_index = 50
	particles.position = pos
	if _particle_texture != null:
		particles.texture = _particle_texture
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 50.0
	mat.initial_velocity_max = 120.0
	mat.gravity = Vector3(0, 0, 0)
	mat.scale_min = 0.3
	mat.scale_max = 0.8
	mat.color = color
	particles.process_material = mat
	get_tree().current_scene.add_child(particles)
	particles.emitting = true
	# Auto-cleanup after particles finish
	get_tree().create_timer(particles.lifetime + 0.1).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)

func spawn_skill_particles(pos: Vector2, skill_type: String) -> void:
	var color := Color.WHITE
	var tex_path := "res://assets/vfx/slash.png"
	match skill_type:
		"heavy":
			color = Color(1.0, 0.5, 0.2)  # orange fire
			tex_path = "res://assets/vfx/fire_burst.png"
		"defend":
			color = Color(0.3, 0.7, 1.0)  # blue shield
			tex_path = "res://assets/vfx/shield_glow.png"
		"attack":
			color = Color.WHITE
			tex_path = "res://assets/vfx/slash.png"
	var tex: Texture2D = _load_tex(tex_path)

	var particles := GPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 10
	particles.lifetime = 0.4
	particles.explosiveness = 0.9
	particles.z_index = 50
	particles.position = pos
	if tex != null:
		particles.texture = tex
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 100.0
	mat.gravity = Vector3(0, 0, 0)
	mat.scale_min = 0.4
	mat.scale_max = 1.0
	mat.color = color
	particles.process_material = mat
	get_tree().current_scene.add_child(particles)
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.2).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)

func screen_flash(color: Color = Color(1, 1, 1, 0.08), duration: float = 0.08) -> void:
	var flash_rect := ColorRect.new()
	flash_rect.color = color
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.z_index = 100
	var vfx_layer: Node = null
	var scene := get_tree().current_scene
	if scene:
		vfx_layer = scene.get_node_or_null("VFXLayer")
	if vfx_layer:
		vfx_layer.add_child(flash_rect)
	else:
		get_tree().current_scene.add_child(flash_rect)
	var tween := create_tween()
	tween.tween_property(flash_rect, "color:a", 0.0, duration)
	tween.tween_callback(flash_rect.queue_free)

func _load_tex(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		return load(res_path) as Texture2D
	var abs_path := ProjectSettings.globalize_path(res_path)
	var img := Image.new()
	if img.load(abs_path) == OK:
		return ImageTexture.create_from_image(img)
	return null
