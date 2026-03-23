extends Node3D

const ZONE_COLORS := {
	0: Color(0.831, 0.659, 0.286),
	1: Color(0.722, 0.314, 0.188),
	2: Color(0.620, 0.353, 0.620),
	3: Color(0.165, 0.353, 0.541),
	4: Color(0.165, 0.541, 0.416),
}

const MOB_POSITIONS := {
	1: [Vector3(0, 0, -2)],
	2: [Vector3(-1.5, 0, -2), Vector3(1.5, 0, -2)],
	4: [Vector3(-2, 0, -2), Vector3(2, 0, -2), Vector3(-1, 0, -3.5), Vector3(1, 0, -3.5)],
}

const PLAYER_POSITION := Vector3(0, 0, 2)
const SPRITE_SCALE := Vector3.ONE
const MOB_SPRITE_SCALE := Vector3(0.8, 0.8, 0.8)

@onready var zone_anchor: Node3D = $ZoneAnchor
@onready var player_anchor: Node3D = $PlayerAnchor
@onready var mob_anchor: Node3D = $MobAnchor

var _current_zone_id: int = -1
var _player_sprite: AnimatedSprite3D = null
var _mob_sprites: Array[AnimatedSprite3D] = []
var _zone_scenes: Dictionary = {}

var _hit_flash_shader: Shader = null
var _hp_bar_shader: Shader = null
var _mob_hp_bars: Array[MeshInstance3D] = []

func _ready() -> void:
	for i in range(5):
		var path := "res://scenes/zones/zone_%d.tscn" % i
		if ResourceLoader.exists(path):
			_zone_scenes[i] = load(path)
	if ResourceLoader.exists("res://shaders/hit_flash.gdshader"):
		_hit_flash_shader = load("res://shaders/hit_flash.gdshader")
	if ResourceLoader.exists("res://shaders/hp_bar_3d.gdshader"):
		_hp_bar_shader = load("res://shaders/hp_bar_3d.gdshader")

func _process(_delta: float) -> void:
	for i in range(mini(_mob_sprites.size(), _mob_hp_bars.size())):
		if is_instance_valid(_mob_sprites[i]) and is_instance_valid(_mob_hp_bars[i]):
			_mob_hp_bars[i].position.x = _mob_sprites[i].position.x
			_mob_hp_bars[i].position.z = _mob_sprites[i].position.z
			_mob_hp_bars[i].position.y = _mob_sprites[i].position.y + 1.5

func load_zone(zone_id: int) -> void:
	if zone_id == _current_zone_id:
		return
	_current_zone_id = zone_id
	for child in zone_anchor.get_children():
		child.queue_free()
	if _zone_scenes.has(zone_id):
		zone_anchor.add_child(_zone_scenes[zone_id].instantiate())
	else:
		_create_fallback_platform(zone_id)
	_decorate_zone(zone_id)
	if _player_sprite != null:
		_player_sprite.position = _get_zone_player_position()

func spawn_hero() -> void:
	if _player_sprite != null:
		return
	var frames := sprite_loader.get_sprite_frames("hero")
	if frames.get_animation_names().size() > 0:
		_player_sprite = _create_animated_sprite(frames, SPRITE_SCALE)
	else:
		var glb_path := "res://assets/models/characters/hero.glb"
		if ResourceLoader.exists(glb_path):
			var model: Node3D = (load(glb_path) as PackedScene).instantiate()
			player_anchor.add_child(model)
			model.position = _get_zone_player_position()
			return
		_player_sprite = _create_animated_sprite(_make_placeholder_frames(Color(0.831, 0.659, 0.286)), SPRITE_SCALE)
	var hero_pos := _get_zone_player_position()
	_player_sprite.position = Vector3(hero_pos.x, 1.0, hero_pos.z)
	player_anchor.add_child(_player_sprite)
	_play_sprite_anim(_player_sprite, "idle")

func spawn_mobs(count: int, zone_id: int) -> void:
	clear_mobs()
	var positions: Array = _get_zone_mob_positions(count)
	if positions.is_empty():
		positions = MOB_POSITIONS.get(count, [Vector3(0, 0, -2)])

	var mob_type := _get_mob_type(zone_id)

	for i in range(count):
		var sprite: AnimatedSprite3D
		var frames := sprite_loader.get_sprite_frames(mob_type)
		if frames.get_animation_names().size() > 0:
			sprite = _create_animated_sprite(frames, MOB_SPRITE_SCALE)
		else:
			var glb_path := "res://assets/models/characters/%s.glb" % mob_type
			if ResourceLoader.exists(glb_path):
				var model: Node3D = (load(glb_path) as PackedScene).instantiate()
				model.name = "Mob%d" % i
				if i < positions.size():
					model.position = positions[i]
				mob_anchor.add_child(model)
				continue
			sprite = _create_animated_sprite(_make_placeholder_frames(ZONE_COLORS.get(zone_id, Color.RED)), MOB_SPRITE_SCALE)

		sprite.name = "Mob%d" % i
		var marker_pos := Vector3(randf_range(-2, 2), 0, randf_range(-3, -1))
		if i < positions.size():
			marker_pos = positions[i]
		sprite.position = Vector3(marker_pos.x, 1.0, marker_pos.z)
		mob_anchor.add_child(sprite)
		_mob_sprites.append(sprite)
		_play_sprite_anim(sprite, "idle")
		var hp_bar := _create_mob_hp_bar()
		hp_bar.position = Vector3(marker_pos.x, 2.5, marker_pos.z)
		mob_anchor.add_child(hp_bar)
		_mob_hp_bars.append(hp_bar)

func clear_mobs() -> void:
	for child in mob_anchor.get_children():
		if is_instance_valid(child):
			child.queue_free()
	_mob_sprites.clear()
	_mob_hp_bars.clear()

func update_mob_visual(mob_id: int, hp: int, _max_hp: int) -> void:
	if mob_id >= _mob_sprites.size():
		return
	var sprite := _mob_sprites[mob_id]
	if not is_instance_valid(sprite):
		return
	if hp <= 0:
		_play_sprite_anim(sprite, "death")
		var tween := create_tween()
		tween.tween_interval(0.5)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
		tween.tween_callback(sprite.queue_free)

func play_attack(target_mob_id: int) -> void:
	if _player_sprite != null:
		_play_sprite_anim(_player_sprite, "attack")
		get_tree().create_timer(0.5).timeout.connect(func():
			if is_instance_valid(_player_sprite):
				_play_sprite_anim(_player_sprite, "idle")
		)
	if target_mob_id < _mob_sprites.size():
		var mob := _mob_sprites[target_mob_id]
		if is_instance_valid(mob):
			_play_sprite_anim(mob, "hit")
			_flash_sprite(mob, 0.15)
			get_tree().create_timer(0.4).timeout.connect(func():
				if is_instance_valid(mob):
					_play_sprite_anim(mob, "idle")
			)

func play_mob_turn() -> void:
	for mob in _mob_sprites:
		if is_instance_valid(mob):
			_play_sprite_anim(mob, "attack")
			get_tree().create_timer(0.5).timeout.connect(func():
				if is_instance_valid(mob):
					_play_sprite_anim(mob, "idle")
			)
	if _player_sprite != null:
		_play_sprite_anim(_player_sprite, "hit")
		_flash_sprite(_player_sprite, 0.15)
		get_tree().create_timer(0.4).timeout.connect(func():
			if is_instance_valid(_player_sprite):
				_play_sprite_anim(_player_sprite, "idle")
		)

func play_player_death() -> void:
	if _player_sprite != null:
		_play_sprite_anim(_player_sprite, "death")

func play_victory() -> void:
	if _player_sprite != null:
		_play_sprite_anim(_player_sprite, "idle")

func spawn_damage_number(world_pos: Vector3, amount: int, is_heal: bool = false) -> void:
	var label := Label3D.new()
	label.text = str(amount) if not is_heal else "+%d" % amount
	label.font_size = 42
	label.outline_size = 6
	label.modulate = Color(1.0, 0.9, 0.8) if not is_heal else Color(0.3, 1.0, 0.4)
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.position = world_pos + Vector3(randf_range(-0.3, 0.3), 2.0, 0)
	label.scale = Vector3(0.5, 0.5, 0.5)
	add_child(label)

	var drift := randf_range(-0.4, 0.4)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector3(1.3, 1.3, 1.3), 0.08)
	tween.tween_property(label, "position", label.position + Vector3(drift, 1.5, 0), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.6)
	tween.set_parallel(false)
	tween.tween_property(label, "scale", Vector3.ONE, 0.12)
	tween.tween_callback(label.queue_free)

func get_mob_world_position(mob_id: int) -> Vector3:
	if mob_id < _mob_sprites.size() and is_instance_valid(_mob_sprites[mob_id]):
		return _mob_sprites[mob_id].global_position
	return Vector3.ZERO

func get_player_world_position() -> Vector3:
	if _player_sprite != null:
		return _player_sprite.global_position
	return player_anchor.global_position

func on_state_changed(state: int, zone_id: int, prev_state: int) -> void:
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
			if _mob_sprites.is_empty():
				var mob_count: int = {0: 0, 1: 1, 2: 1, 3: 2, 4: 4}.get(zone_id, 0)
				spawn_mobs(mob_count, zone_id)
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

func _create_animated_sprite(frames: SpriteFrames, scale: Vector3) -> AnimatedSprite3D:
	var sprite := AnimatedSprite3D.new()
	sprite.sprite_frames = frames
	sprite.pixel_size = 0.004
	sprite.scale = scale
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.shaded = true
	sprite.transparent = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.3
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sprite.position.y = 1.0
	var shadow := _create_blob_shadow()
	sprite.add_child(shadow)
	return sprite

func _create_blob_shadow() -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var disc := QuadMesh.new()
	disc.size = Vector2(1.4, 0.7)
	mesh_inst.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0, 0, 0, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_inst.material_override = mat
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_inst.rotation.x = deg_to_rad(-90)
	mesh_inst.position.y = -1.0
	return mesh_inst

func _play_sprite_anim(sprite: AnimatedSprite3D, anim_name: String) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	if sprite.sprite_frames == null:
		return
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)

func _flash_sprite(sprite: AnimatedSprite3D, duration: float) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	var original_modulate := sprite.modulate
	sprite.modulate = Color(4.0, 4.0, 4.0, 1.0)
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(sprite):
			sprite.modulate = original_modulate
	)

func _make_placeholder_frames(color: Color) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var texture := ImageTexture.create_from_image(img)
	for anim_name in ["idle", "attack", "hit", "death"]:
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, 2.0)
		frames.set_animation_loop(anim_name, anim_name == "idle")
		frames.add_frame(anim_name, texture)
	return frames

func _get_zone_mob_positions(count: int) -> Array:
	var positions: Array = []
	if zone_anchor.get_child_count() == 0:
		return positions
	var zone_scene: Node3D = zone_anchor.get_child(0)
	for i in range(count):
		var marker := zone_scene.get_node_or_null("MobPosition%d" % i) as Marker3D
		if marker != null:
			positions.append(marker.global_position - zone_anchor.global_position)
	return positions

func _get_zone_player_position() -> Vector3:
	if zone_anchor.get_child_count() == 0:
		return PLAYER_POSITION
	var zone_scene: Node3D = zone_anchor.get_child(0)
	var marker := zone_scene.get_node_or_null("PlayerPosition") as Marker3D
	if marker != null:
		return marker.global_position - zone_anchor.global_position
	return PLAYER_POSITION

func _get_mob_type(zone_id: int) -> String:
	match zone_id:
		1: return "mob_ember"
		2: return "mob_aether"
		3: return "mob_sunken"
		4: return "mob_crystal"
		_: return "mob_ember"

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

func _create_mob_hp_bar() -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.2, 0.12)
	mesh_inst.mesh = quad
	if _hp_bar_shader != null:
		var mat := ShaderMaterial.new()
		mat.shader = _hp_bar_shader
		mat.set_shader_parameter("health_ratio", 1.0)
		mat.set_shader_parameter("bar_color", Color(0.75, 0.35, 0.15))
		mesh_inst.material_override = mat
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh_inst

func update_mob_hp(mob_index: int, current_hp: int, max_hp: int) -> void:
	if mob_index < 0 or mob_index >= _mob_hp_bars.size():
		return
	var bar := _mob_hp_bars[mob_index]
	if not is_instance_valid(bar):
		return
	var ratio := float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
	var mat := bar.material_override as ShaderMaterial
	if mat != null:
		var tween := create_tween()
		var current_ratio: float = mat.get_shader_parameter("health_ratio")
		tween.tween_method(func(val: float): mat.set_shader_parameter("health_ratio", val), current_ratio, ratio, 0.3)
	bar.visible = current_hp > 0

func _decorate_zone(zone_id: int) -> void:
	var radius: float = 6.0 + zone_id * 0.5
	_add_edge_props(zone_id, radius)
	_add_atmosphere_particles(zone_id, radius)
	_add_edge_darkness(radius)

func _add_edge_props(zone_id: int, radius: float) -> void:
	var prop_color := _zone_prop_color(zone_id)
	var zone_emission: Color = ZONE_COLORS.get(zone_id, Color.GRAY)
	for i in range(12):
		var angle := (TAU / 12.0) * float(i) + randf_range(-0.15, 0.15)
		var dist := radius + randf_range(-0.5, 0.5)
		var pos := Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		var pillar := MeshInstance3D.new()
		var mesh: Mesh
		var h: float
		match i % 4:
			0:
				var cyl := CylinderMesh.new()
				cyl.top_radius = randf_range(0.05, 0.12)
				cyl.bottom_radius = randf_range(0.3, 0.5)
				cyl.height = randf_range(2.0, 3.5)
				h = cyl.height
				mesh = cyl
			1:
				var prism := PrismMesh.new()
				prism.size = Vector3(randf_range(0.4, 0.8), randf_range(1.5, 2.5), randf_range(0.4, 0.8))
				h = prism.size.y
				mesh = prism
			2:
				var box := BoxMesh.new()
				box.size = Vector3(randf_range(0.3, 0.6), randf_range(0.8, 1.5), randf_range(0.3, 0.6))
				h = box.size.y
				mesh = box
			_:
				var cyl2 := CylinderMesh.new()
				cyl2.top_radius = randf_range(0.15, 0.25)
				cyl2.bottom_radius = randf_range(0.15, 0.25)
				cyl2.height = randf_range(1.0, 2.0)
				h = cyl2.height
				mesh = cyl2
		pillar.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = prop_color.darkened(randf_range(0.1, 0.3))
		mat.roughness = 0.85
		mat.emission_enabled = true
		mat.emission = zone_emission
		mat.emission_energy_multiplier = randf_range(0.05, 0.2)
		pillar.material_override = mat
		pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		pillar.position = pos
		pillar.position.y = h * 0.5
		pillar.rotation.y = randf() * TAU
		pillar.rotation.x = randf_range(-0.05, 0.05)
		pillar.rotation.z = randf_range(-0.05, 0.05)
		zone_anchor.add_child(pillar)

		if i % 3 == 0:
			var glow := OmniLight3D.new()
			glow.light_color = zone_emission
			glow.light_energy = 0.4
			glow.omni_range = 2.0
			glow.position = pos + Vector3(0, h + 0.3, 0)
			zone_anchor.add_child(glow)

func _add_atmosphere_particles(zone_id: int, radius: float) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 60
	particles.lifetime = 5.0
	particles.emitting = true
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(radius, 0.5, radius)
	mat.gravity = Vector3.ZERO
	match zone_id:
		1:
			mat.direction = Vector3(0, 1, 0)
			mat.initial_velocity_min = 0.1
			mat.initial_velocity_max = 0.3
			mat.spread = 20.0
		2:
			mat.direction = Vector3(1, 0.3, 0)
			mat.initial_velocity_min = 0.05
			mat.initial_velocity_max = 0.15
			mat.spread = 60.0
		3:
			mat.direction = Vector3(0, -1, 0)
			mat.initial_velocity_min = 0.1
			mat.initial_velocity_max = 0.2
			mat.spread = 15.0
			mat.emission_box_extents.y = 3.0
			particles.position.y = 4.0
		_:
			mat.direction = Vector3(0, 1, 0)
			mat.initial_velocity_min = 0.02
			mat.initial_velocity_max = 0.1
			mat.spread = 45.0
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 0.3
	mat.turbulence_noise_scale = 2.0
	mat.scale_min = 0.02
	mat.scale_max = 0.06
	var color: Color = ZONE_COLORS.get(zone_id, Color.WHITE)
	mat.color = Color(color.r, color.g, color.b, 0.4)
	particles.process_material = mat
	var draw_mesh := QuadMesh.new()
	draw_mesh.size = Vector2(0.05, 0.05)
	particles.draw_pass_1 = draw_mesh
	particles.position.y += 1.0
	zone_anchor.add_child(particles)

func _add_edge_darkness(radius: float) -> void:
	var wall := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius + 3.0
	mesh.bottom_radius = radius + 3.0
	mesh.height = 6.0
	mesh.rings = 1
	mesh.radial_segments = 32
	wall.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.02, 0.04, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wall.material_override = mat
	wall.position.y = 2.0
	zone_anchor.add_child(wall)

func _zone_prop_color(zone_id: int) -> Color:
	match zone_id:
		0: return Color(0.35, 0.30, 0.25)
		1: return Color(0.30, 0.15, 0.10)
		2: return Color(0.25, 0.18, 0.30)
		3: return Color(0.15, 0.20, 0.28)
		4: return Color(0.15, 0.28, 0.22)
		_: return Color(0.25, 0.25, 0.25)
