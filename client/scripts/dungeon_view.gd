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
const SPRITE_SCALE := Vector3(2.0, 2.0, 2.0)
const MOB_SPRITE_SCALE := Vector3(1.6, 1.6, 1.6)

@onready var zone_anchor: Node3D = $ZoneAnchor
@onready var player_anchor: Node3D = $PlayerAnchor
@onready var mob_anchor: Node3D = $MobAnchor

var _current_zone_id: int = -1
var _player_sprite: AnimatedSprite3D = null
var _mob_sprites: Array[AnimatedSprite3D] = []
var _zone_scenes: Dictionary = {}

var _hit_flash_shader: Shader = null

func _ready() -> void:
	for i in range(5):
		var path := "res://scenes/zones/zone_%d.tscn" % i
		if ResourceLoader.exists(path):
			_zone_scenes[i] = load(path)
	if ResourceLoader.exists("res://shaders/hit_flash.gdshader"):
		_hit_flash_shader = load("res://shaders/hit_flash.gdshader")

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
	_player_sprite.position = _get_zone_player_position()
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
		if i < positions.size():
			sprite.position = positions[i]
		else:
			sprite.position = Vector3(randf_range(-2, 2), 0, randf_range(-3, -1))
		mob_anchor.add_child(sprite)
		_mob_sprites.append(sprite)
		_play_sprite_anim(sprite, "idle")

func clear_mobs() -> void:
	for child in mob_anchor.get_children():
		if is_instance_valid(child):
			child.queue_free()
	_mob_sprites.clear()

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
	label.font_size = 48
	label.outline_size = 8
	label.modulate = Color(0.85, 0.27, 0.27) if not is_heal else Color(0.25, 0.7, 0.35)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = world_pos + Vector3(randf_range(-0.3, 0.3), 1.5, 0)
	add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 1.5, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.set_parallel(false)
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
	sprite.pixel_size = 0.003
	sprite.scale = scale
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.transparent = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.position.y = 1.0
	if _hit_flash_shader != null:
		var mat := ShaderMaterial.new()
		mat.shader = _hit_flash_shader
		sprite.material_override = mat
	return sprite

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
	var mat := sprite.material_override
	if mat is ShaderMaterial:
		mat.set_shader_parameter("flash_active", true)
		get_tree().create_timer(duration).timeout.connect(func():
			if is_instance_valid(sprite) and mat is ShaderMaterial:
				mat.set_shader_parameter("flash_active", false)
		)
	else:
		var original_modulate := sprite.modulate
		sprite.modulate = Color.WHITE * 3.0
		get_tree().create_timer(duration).timeout.connect(func():
			if is_instance_valid(sprite):
				sprite.modulate = original_modulate
		)

func _make_placeholder_frames(color: Color) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
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
