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

const PLAYER_POSITION := Vector3(0, 0, 3)
const SPRITE_SCALE := Vector3.ONE
const MOB_SPRITE_SCALE := Vector3(0.8, 0.8, 0.8)
const MODEL_SCALE := Vector3(1.2, 1.2, 1.2)
const MOB_MODEL_SCALE := Vector3(1.0, 1.0, 1.0)

@onready var zone_anchor: Node3D = $ZoneAnchor
@onready var player_anchor: Node3D = $PlayerAnchor
@onready var mob_anchor: Node3D = $MobAnchor

var _current_zone_id: int = -1
var _player_sprite: AnimatedSprite3D = null
var _player_model: Node3D = null
var _mob_sprites: Array[AnimatedSprite3D] = []
var _mob_models: Array[Node3D] = []
var _zone_scenes: Dictionary = {}

const ZONE_PROPS := {
	0: ["res://assets/models/props/zone_0/z0_brazier.glb", "res://assets/models/props/zone_0/z0_pillar.glb"],
	1: ["res://assets/models/props/zone_1/z1_geode.glb", "res://assets/models/props/zone_1/z1_boulder.glb"],
	2: ["res://assets/models/props/zone_2/z2_crystal.glb", "res://assets/models/props/zone_2/z2_runestone.glb"],
	3: ["res://assets/models/props/zone_3/z3_mushroom.glb", "res://assets/models/props/zone_3/z3_column.glb"],
	4: ["res://assets/models/props/zone_4/z4_pylon.glb", "res://assets/models/props/zone_4/z4_throne.glb"],
}

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
	for i in range(_mob_hp_bars.size()):
		if not is_instance_valid(_mob_hp_bars[i]):
			continue
		var mob_node := get_mob_node(i)
		if mob_node != null:
			_mob_hp_bars[i].position.x = mob_node.position.x
			_mob_hp_bars[i].position.z = mob_node.position.z
			_mob_hp_bars[i].position.y = mob_node.position.y + 2.2

func load_zone(zone_id: int) -> void:
	if zone_id == _current_zone_id:
		return
	_current_zone_id = zone_id
	for child in zone_anchor.get_children():
		child.queue_free()
	if _zone_scenes.has(zone_id):
		zone_anchor.add_child(_zone_scenes[zone_id].instantiate())
		_add_extended_ground(zone_id)
	else:
		_create_fallback_platform(zone_id)
	_decorate_zone(zone_id)
	if _player_sprite != null:
		_player_sprite.position = _get_zone_player_position()

func spawn_hero() -> void:
	if _player_model != null or _player_sprite != null:
		return
	var glb_path := "res://assets/models/characters/hero.glb"
	if ResourceLoader.exists(glb_path):
		_player_model = (load(glb_path) as PackedScene).instantiate()
		_player_model.scale = MODEL_SCALE
		_player_model.position = Vector3.ZERO
		player_anchor.position = _get_zone_player_position()
		player_anchor.add_child(_player_model)
		_setup_model_animations(_player_model)
		_face_node_toward(_player_model, Vector3(0, 0, -2) - player_anchor.position)
		var shadow := _create_blob_shadow()
		shadow.position.y = 0.05
		_player_model.add_child(shadow)
		return
	var frames := sprite_loader.get_sprite_frames("hero")
	if frames.get_animation_names().size() > 0:
		_player_sprite = _create_animated_sprite(frames, SPRITE_SCALE)
	else:
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
		var marker_pos := Vector3(randf_range(-2, 2), 0, randf_range(-3, -1))
		if i < positions.size():
			marker_pos = positions[i]

		var glb_path := "res://assets/models/characters/%s.glb" % mob_type
		if ResourceLoader.exists(glb_path):
			var model: Node3D = (load(glb_path) as PackedScene).instantiate()
			model.name = "Mob%d" % i
			model.scale = MOB_MODEL_SCALE
			model.position = marker_pos
			mob_anchor.add_child(model)
			_setup_model_animations(model)
			_face_node_toward(model, player_anchor.position)
			_mob_models.append(model)
			_mob_sprites.append(null)
			var hp_bar := _create_mob_hp_bar()
			hp_bar.position = marker_pos + Vector3(0, 2.2, 0)
			mob_anchor.add_child(hp_bar)
			_mob_hp_bars.append(hp_bar)
			continue

		var sprite: AnimatedSprite3D
		var frames := sprite_loader.get_sprite_frames(mob_type)
		if frames.get_animation_names().size() > 0:
			sprite = _create_animated_sprite(frames, MOB_SPRITE_SCALE)
		else:
			sprite = _create_animated_sprite(_make_placeholder_frames(ZONE_COLORS.get(zone_id, Color.RED)), MOB_SPRITE_SCALE)
		sprite.name = "Mob%d" % i
		sprite.position = Vector3(marker_pos.x, 1.0, marker_pos.z)
		mob_anchor.add_child(sprite)
		_mob_sprites.append(sprite)
		_mob_models.append(null)
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
	_mob_models.clear()
	_mob_hp_bars.clear()

func update_mob_visual(mob_id: int, hp: int, _max_hp: int) -> void:
	if mob_id >= _mob_sprites.size() and mob_id >= _mob_models.size():
		return
	if hp <= 0:
		var node: Node3D = null
		if mob_id < _mob_models.size() and is_instance_valid(_mob_models[mob_id]):
			node = _mob_models[mob_id]
		elif mob_id < _mob_sprites.size() and is_instance_valid(_mob_sprites[mob_id]):
			node = _mob_sprites[mob_id]
			_play_sprite_anim(_mob_sprites[mob_id], "death")
		if node != null:
			var tween := create_tween()
			tween.tween_interval(0.5)
			tween.tween_property(node, "scale", Vector3(0.01, 0.01, 0.01), 0.5).set_ease(Tween.EASE_IN)
			tween.tween_callback(node.queue_free)

func _face_node_toward(node: Node3D, target_pos: Vector3) -> void:
	var dir := target_pos - node.position
	if dir.length_squared() > 0.01:
		node.look_at(node.position + Vector3(dir.x, 0, dir.z).normalized(), Vector3.UP)

func face_hero_toward(target_pos: Vector3) -> void:
	if _player_model != null:
		var dir := target_pos - _player_model.global_position
		if dir.length_squared() > 0.01:
			var target := _player_model.global_position + Vector3(dir.x, 0, dir.z).normalized()
			_player_model.look_at(target, Vector3.UP)
		return
	if _player_sprite == null:
		return
	_player_sprite.flip_h = target_pos.x < _player_sprite.global_position.x

func play_attack(target_mob_id: int) -> void:
	var target_node := get_mob_node(target_mob_id)
	if target_node != null:
		face_hero_toward(target_node.global_position)

	if _player_model != null:
		_play_model_anim(_player_model, "attack")
		_tween_attack_lunge(_player_model, target_node)
	elif _player_sprite != null:
		_play_sprite_anim(_player_sprite, "attack")
		get_tree().create_timer(0.5).timeout.connect(func():
			if is_instance_valid(_player_sprite):
				_play_sprite_anim(_player_sprite, "idle")
		)

	if target_node != null:
		if target_mob_id < _mob_models.size() and is_instance_valid(_mob_models[target_mob_id]):
			_play_model_anim(_mob_models[target_mob_id], "hit")
		elif target_mob_id < _mob_sprites.size() and is_instance_valid(_mob_sprites[target_mob_id]):
			_play_sprite_anim(_mob_sprites[target_mob_id], "hit")
			_flash_sprite(_mob_sprites[target_mob_id], 0.15)
			get_tree().create_timer(0.4).timeout.connect(func():
				if is_instance_valid(_mob_sprites[target_mob_id]):
					_play_sprite_anim(_mob_sprites[target_mob_id], "idle")
			)

func play_mob_turn() -> void:
	for i in range(_mob_models.size()):
		if is_instance_valid(_mob_models[i]):
			_play_model_anim(_mob_models[i], "attack")
	for mob in _mob_sprites:
		if is_instance_valid(mob):
			_play_sprite_anim(mob, "attack")
			get_tree().create_timer(0.5).timeout.connect(func():
				if is_instance_valid(mob):
					_play_sprite_anim(mob, "idle")
			)
	if _player_model != null:
		_play_model_anim(_player_model, "hit")
	elif _player_sprite != null:
		_play_sprite_anim(_player_sprite, "hit")
		_flash_sprite(_player_sprite, 0.15)
		get_tree().create_timer(0.4).timeout.connect(func():
			if is_instance_valid(_player_sprite):
				_play_sprite_anim(_player_sprite, "idle")
		)

func play_player_death() -> void:
	if _player_model != null:
		_play_model_anim(_player_model, "death")
	elif _player_sprite != null:
		_play_sprite_anim(_player_sprite, "death")

func play_victory() -> void:
	if _player_model != null:
		_play_model_anim(_player_model, "idle")
	elif _player_sprite != null:
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
	if mob_id < _mob_models.size() and is_instance_valid(_mob_models[mob_id]):
		return _mob_models[mob_id].global_position
	if mob_id < _mob_sprites.size() and is_instance_valid(_mob_sprites[mob_id]):
		return _mob_sprites[mob_id].global_position
	return Vector3.ZERO

func get_player_world_position() -> Vector3:
	if _player_model != null:
		return _player_model.global_position
	if _player_sprite != null:
		return _player_sprite.global_position
	return player_anchor.global_position

func get_mob_node(mob_id: int) -> Node3D:
	if mob_id < _mob_models.size() and is_instance_valid(_mob_models[mob_id]):
		return _mob_models[mob_id]
	if mob_id < _mob_sprites.size() and is_instance_valid(_mob_sprites[mob_id]):
		return _mob_sprites[mob_id]
	return null

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
			if _mob_sprites.is_empty() and _mob_models.is_empty():
				var mob_count: int = {0: 0, 1: 1, 2: 1, 3: 2, 4: 4}.get(zone_id, 0)
				spawn_mobs(mob_count, zone_id)
			var first_mob := get_mob_node(0)
			if first_mob != null:
				face_hero_toward(first_mob.global_position)
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
	sprite.pixel_size = 0.005
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

func _setup_model_animations(model: Node3D) -> void:
	var anim_player: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player == null:
		return
	var anims := anim_player.get_animation_list()
	if anims.is_empty():
		return
	for anim_name in anims:
		if "idle" in anim_name.to_lower() or "loop" in anim_name.to_lower():
			anim_player.play(anim_name)
			return
	anim_player.play(anims[0])

func _play_model_anim(model: Node3D, anim_name: String) -> void:
	if model == null or not is_instance_valid(model):
		return
	var anim_player: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player != null:
		var anims := anim_player.get_animation_list()
		for a in anims:
			if anim_name.to_lower() in a.to_lower():
				anim_player.play(a)
				if anim_name != "idle":
					anim_player.animation_finished.connect(func(_n: StringName):
						for idle_a in anim_player.get_animation_list():
							if "idle" in idle_a.to_lower():
								anim_player.play(idle_a)
								return
					, CONNECT_ONE_SHOT)
				return
	if anim_name == "attack":
		_tween_attack_lunge(model, null)
	elif anim_name == "hit":
		_tween_hit_recoil(model)

func _tween_attack_lunge(model: Node3D, target: Node3D) -> void:
	if model == null or not is_instance_valid(model):
		return
	var original_pos := model.position
	var lunge_dir := Vector3(0, 0, -0.5)
	if target != null and is_instance_valid(target):
		lunge_dir = (target.global_position - model.global_position).normalized() * 0.8
		lunge_dir.y = 0
	var tween := create_tween()
	tween.tween_property(model, "position", original_pos + lunge_dir, 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_property(model, "position", original_pos, 0.25).set_ease(Tween.EASE_IN)

func _tween_hit_recoil(model: Node3D) -> void:
	if model == null or not is_instance_valid(model):
		return
	var original_pos := model.position
	var recoil := -model.basis.z * 0.3
	recoil.y = 0
	var tween := create_tween()
	tween.tween_property(model, "position", original_pos + recoil, 0.1)
	tween.tween_property(model, "position", original_pos, 0.2).set_ease(Tween.EASE_OUT)

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
	box.size = Vector3(14, 0.3, 14)
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
	_add_extended_ground(zone_id)

func _add_extended_ground(zone_id: int) -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	var color: Color = ZONE_COLORS.get(zone_id, Color(0.1, 0.1, 0.1))
	mat.albedo_color = color * 0.12
	mat.roughness = 1.0
	ground.material_override = mat
	ground.position = Vector3(0, -0.3, 0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone_anchor.add_child(ground)

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
	var radius: float = 10.0 + zone_id * 0.5
	_add_arena_boundary(zone_id, radius)
	_add_edge_props(zone_id, radius + 2.0)
	_add_atmosphere_particles(zone_id, radius)
	_add_player_fill_light()

func _add_arena_boundary(zone_id: int, radius: float) -> void:
	var color: Color = ZONE_COLORS.get(zone_id, Color.GRAY)
	for i in range(28):
		var angle := (TAU / 28.0) * float(i) + randf_range(-0.08, 0.08)
		var dist := radius + randf_range(-0.3, 0.3)
		var pos := Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		var rock := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		var s := randf_range(0.3, 0.8)
		mesh.radius = s
		mesh.height = s * randf_range(0.6, 1.2)
		mesh.radial_segments = 6
		mesh.rings = 3
		rock.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color.darkened(randf_range(0.5, 0.7))
		mat.roughness = 0.95
		rock.material_override = mat
		rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		rock.position = pos
		rock.position.y = mesh.height * 0.2
		rock.rotation = Vector3(randf_range(-0.2, 0.2), randf() * TAU, randf_range(-0.2, 0.2))
		zone_anchor.add_child(rock)

func _add_player_fill_light() -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.95, 0.85)
	light.light_energy = 1.5
	light.omni_range = 5.0
	light.shadow_enabled = false
	light.position = Vector3(0, 3.0, 0)
	player_anchor.add_child(light)

func _add_edge_props(zone_id: int, radius: float) -> void:
	var zone_emission: Color = ZONE_COLORS.get(zone_id, Color.GRAY)
	var prop_paths: Array = ZONE_PROPS.get(zone_id, [])
	var loaded_props: Array[PackedScene] = []
	for path in prop_paths:
		if ResourceLoader.exists(path):
			loaded_props.append(load(path) as PackedScene)

	for i in range(8):
		var angle := (TAU / 8.0) * float(i) + randf_range(-0.2, 0.2)
		var dist := radius + randf_range(-0.5, 0.8)
		var pos := Vector3(cos(angle) * dist, 0, sin(angle) * dist)

		if not loaded_props.is_empty():
			var scene: PackedScene = loaded_props[i % loaded_props.size()]
			var instance: Node3D = scene.instantiate()
			instance.position = pos
			var s := randf_range(0.4, 0.7)
			instance.scale = Vector3(s, s, s)
			instance.rotation.y = randf() * TAU
			zone_anchor.add_child(instance)
		else:
			var pillar := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = randf_range(0.05, 0.15)
			cyl.bottom_radius = randf_range(0.25, 0.4)
			cyl.height = randf_range(1.5, 3.0)
			pillar.mesh = cyl
			var mat := StandardMaterial3D.new()
			mat.albedo_color = _zone_prop_color(zone_id).darkened(randf_range(0.1, 0.3))
			mat.roughness = 0.85
			pillar.material_override = mat
			pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			pillar.position = pos
			pillar.position.y = cyl.height * 0.5
			pillar.rotation.y = randf() * TAU
			zone_anchor.add_child(pillar)

		if i % 2 == 0:
			var glow := OmniLight3D.new()
			glow.light_color = zone_emission
			glow.light_energy = 0.6
			glow.omni_range = 3.0
			glow.position = pos + Vector3(0, 1.5, 0)
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
