extends Node2D

const ZONE_COLORS := {
	0: Color(0.831, 0.659, 0.286),
	1: Color(0.722, 0.314, 0.188),
	2: Color(0.620, 0.353, 0.620),
	3: Color(0.165, 0.353, 0.541),
	4: Color(0.165, 0.541, 0.416),
}

const MOB_POSITIONS := {
	1: [Vector2(0, -120)],
	2: [Vector2(-100, -120), Vector2(100, -120)],
	4: [Vector2(-140, -100), Vector2(140, -100), Vector2(-70, -200), Vector2(70, -200)],
}

const PLAYER_POSITION := Vector2(0, 100)
const SPRITE_SCALE := Vector2(0.25, 0.25)
const MOB_SPRITE_SCALE := Vector2(0.2, 0.2)
const ZONE_MOB_COUNT := {0: 0, 1: 1, 2: 1, 3: 2, 4: 4}

const ZONE_PALETTES := {
	0: {"stone": Color(0.18, 0.15, 0.12), "crack": Color(0.08, 0.06, 0.05), "emission": Color(0.83, 0.66, 0.29), "emission_strength": 0.2},
	1: {"stone": Color(0.20, 0.12, 0.10), "crack": Color(0.10, 0.04, 0.03), "emission": Color(0.90, 0.40, 0.15), "emission_strength": 0.35},
	2: {"stone": Color(0.16, 0.12, 0.18), "crack": Color(0.06, 0.04, 0.08), "emission": Color(0.70, 0.35, 0.70), "emission_strength": 0.3},
	3: {"stone": Color(0.10, 0.12, 0.18), "crack": Color(0.04, 0.05, 0.10), "emission": Color(0.20, 0.45, 0.70), "emission_strength": 0.4},
	4: {"stone": Color(0.10, 0.16, 0.14), "crack": Color(0.03, 0.08, 0.06), "emission": Color(0.20, 0.70, 0.50), "emission_strength": 0.5},
}

const ZONE_ATMOSPHERES := {
	0: {"ambient": Color(0.55, 0.50, 0.45), "player_light": Color(1.0, 0.95, 0.85), "vignette": 0.35},
	1: {"ambient": Color(0.50, 0.40, 0.35), "player_light": Color(1.0, 0.90, 0.80), "vignette": 0.38},
	2: {"ambient": Color(0.42, 0.38, 0.52), "player_light": Color(0.90, 0.85, 1.0), "vignette": 0.38},
	3: {"ambient": Color(0.35, 0.40, 0.55), "player_light": Color(0.85, 0.90, 1.0), "vignette": 0.40},
	4: {"ambient": Color(0.35, 0.48, 0.40), "player_light": Color(0.85, 1.0, 0.90), "vignette": 0.40},
}

@onready var zone_background: ColorRect = $ZoneBackground
@onready var entities: Node2D = $Entities
@onready var player_anchor: Node2D = $Entities/PlayerAnchor

var _current_zone_id: int = -1
var _player_sprite: AnimatedSprite2D = null
var _mob_sprites: Array = []
var _mob_hp_bars: Array = []
var _mob_containers: Array = []
var _hit_flash_shader: Shader = null
var _hp_bar_shader: Shader = null
var _canvas_modulate: CanvasModulate = null
var _vignette_material: ShaderMaterial = null
var _player_light: PointLight2D = null
var _room_bg: Sprite2D = null
var _combat_fx: Node = null

const ANIM_ALIASES := {
	"idle": ["idle", "Idle", "combat_stance", "Combat_Stance", "CombatStance"],
	"attack": ["attack", "Attack", "AttackingwithWeapon"],
	"hit": ["hit", "Hit_Reaction", "hit_reaction", "BeHit_FlyUp"],
	"death": ["death", "Dead", "dead", "Dying"],
	"defend": ["defend", "Defend", "block", "Block", "shield"],
	"skill_cast": ["skill_cast", "SkillCast", "cast", "Cast", "magic"],
}

func _ready() -> void:
	if ResourceLoader.exists("res://shaders/hit_flash.gdshader"):
		_hit_flash_shader = load("res://shaders/hit_flash.gdshader")
	if ResourceLoader.exists("res://shaders/hp_bar.gdshader"):
		_hp_bar_shader = load("res://shaders/hp_bar.gdshader")
	if ResourceLoader.exists("res://scripts/combat_fx.gd"):
		var combat_fx_script := load("res://scripts/combat_fx.gd") as Script
		if combat_fx_script != null:
			_combat_fx = Node.new()
			_combat_fx.name = "CombatFX"
			_combat_fx.set_script(combat_fx_script)
			add_child(_combat_fx)

func load_zone(zone_id: int) -> void:
	if zone_id == _current_zone_id:
		return
	_current_zone_id = zone_id
	var bg_path := "res://assets/backgrounds/zone_%d.png" % zone_id
	var has_room_bg := false
	var bg_tex := _load_texture_safe(bg_path)
	if bg_tex != null:
		if _room_bg == null:
			_room_bg = Sprite2D.new()
			_room_bg.z_index = -11
			_room_bg.centered = true
			add_child(_room_bg)
			move_child(_room_bg, 0)
		_room_bg.texture = bg_tex
		var tex_w := bg_tex.get_width()
		var tex_h := bg_tex.get_height()
		if tex_w > 0 and tex_h > 0:
			_room_bg.scale = Vector2(5000.0 / tex_w, 5000.0 / tex_h)
		_room_bg.visible = true
		has_room_bg = true
	if has_room_bg:
		zone_background.visible = false
	else:
		if _room_bg != null:
			_room_bg.visible = false
		zone_background.visible = true
	var palette: Dictionary = ZONE_PALETTES.get(zone_id, ZONE_PALETTES[0])
	zone_background.color = palette["stone"]
	var mat := zone_background.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("stone_color", palette["stone"])
		mat.set_shader_parameter("crack_color", palette["crack"])
		mat.set_shader_parameter("emission_color", palette["emission"])
		mat.set_shader_parameter("emission_strength", palette["emission_strength"])

	var atmo: Dictionary = ZONE_ATMOSPHERES.get(zone_id, ZONE_ATMOSPHERES[0])

	if _canvas_modulate == null:
		var lighting_layer := get_parent().get_node_or_null("LightingLayer")
		if lighting_layer:
			_canvas_modulate = lighting_layer.get_node_or_null("CanvasModulate") as CanvasModulate

	if _canvas_modulate != null:
		var tween := create_tween()
		tween.tween_property(_canvas_modulate, "color", atmo["ambient"], 0.5)

	if _vignette_material == null:
		var vfx_layer := get_parent().get_node_or_null("VFXLayer")
		if vfx_layer:
			var rect := vfx_layer.get_node_or_null("VignetteRect")
			if rect and rect.material is ShaderMaterial:
				_vignette_material = rect.material as ShaderMaterial

	if _vignette_material != null:
		var raw_vignette: Variant = _vignette_material.get_shader_parameter("vignette_intensity")
		var current_vignette: float = raw_vignette if raw_vignette is float else 0.4
		var target_vignette: float = atmo["vignette"] if atmo["vignette"] is float else 0.4
		var tween2 := create_tween()
		tween2.tween_method(
			func(v: float): _vignette_material.set_shader_parameter("vignette_intensity", v),
			current_vignette,
			target_vignette,
			0.5
		)

	if _player_light != null:
		var tween3 := create_tween()
		tween3.tween_property(_player_light, "color", atmo["player_light"], 0.5)

	# Show zone title card
	var zone_names := {0: "Entrance", 1: "Left Cavern", 2: "Right Passage", 3: "Deep Hall", 4: "Final Chamber"}
	var zone_name := "Zone %d — %s" % [zone_id, zone_names.get(zone_id, "Unknown")]
	if transition_manager.has_method("show_zone_title"):
		transition_manager.show_zone_title(zone_name)

	# Zone ambient music crossfade
	var ambient_track := "ambient_dungeon"
	if zone_id >= 3:
		ambient_track = "ambient_deep"
	if audio_manager.has_method("crossfade_music"):
		audio_manager.crossfade_music(ambient_track, 1.0)

func spawn_hero() -> void:
	if _player_sprite != null and is_instance_valid(_player_sprite):
		return
	player_anchor.position = PLAYER_POSITION
	var frames := sprite_loader.get_sprite_frames("hero")
	if frames == null or frames.get_animation_names().is_empty():
		frames = _make_placeholder_frames(ZONE_COLORS.get(_current_zone_id, Color(0.831, 0.659, 0.286)))
	_player_sprite = AnimatedSprite2D.new()
	_player_sprite.sprite_frames = frames
	_player_sprite.scale = SPRITE_SCALE
	_player_sprite.offset.y = -128
	_player_sprite.z_index = 10
	_player_sprite.material = _make_hit_flash_material()
	_player_sprite.add_child(_create_blob_shadow(Vector2(1.2, 0.7)))
	player_anchor.add_child(_player_sprite)
	var player_light := PointLight2D.new()
	var light_tex := _load_texture_safe("res://assets/vfx/light_gradient.png")
	if light_tex != null:
		player_light.texture = light_tex
	player_light.texture_scale = 5.0
	player_light.energy = 1.8
	player_light.color = Color(1.0, 0.95, 0.85)
	player_light.blend_mode = Light2D.BLEND_MODE_ADD
	_player_sprite.add_child(player_light)
	_player_light = player_light
	_play_sprite_anim(_player_sprite, "idle")

func spawn_mobs(count: int, zone_id: int) -> void:
	clear_mobs()
	var positions: Array = MOB_POSITIONS.get(count, MOB_POSITIONS.get(1, [Vector2(0, -120)]))
	var mob_type := _get_mob_type(zone_id)
	for i in range(count):
		var container := Node2D.new()
		container.name = "Mob%d" % i
		container.position = positions[i] if i < positions.size() else Vector2(0, -120)
		var sprite := AnimatedSprite2D.new()
		var frames := sprite_loader.get_sprite_frames(mob_type)
		if frames == null or frames.get_animation_names().is_empty():
			frames = _make_placeholder_frames(ZONE_COLORS.get(zone_id, Color.RED))
		sprite.name = "Sprite"
		sprite.sprite_frames = frames
		sprite.scale = MOB_SPRITE_SCALE
		sprite.offset.y = -128
		sprite.material = _make_hit_flash_material()
		sprite.add_child(_create_blob_shadow(Vector2(1.0, 0.6)))
		container.add_child(sprite)
		_play_sprite_anim(sprite, "idle")

		var hp := ColorRect.new()
		hp.name = "HPBar"
		hp.size = Vector2(60, 8)
		hp.position = Vector2(-30, -150)
		hp.color = Color.WHITE
		if _hp_bar_shader != null:
			var hp_mat := ShaderMaterial.new()
			hp_mat.shader = _hp_bar_shader
			hp_mat.set_shader_parameter("health_ratio", 1.0)
			hp.material = hp_mat
		container.add_child(hp)
		var mob_light := PointLight2D.new()
		var light_tex_mob := _load_texture_safe("res://assets/vfx/light_gradient.png")
		if light_tex_mob != null:
			mob_light.texture = light_tex_mob
		mob_light.texture_scale = 2.0
		mob_light.energy = 0.6
		mob_light.blend_mode = Light2D.BLEND_MODE_ADD
		mob_light.color = _get_mob_light_color(zone_id)
		container.add_child(mob_light)

		entities.add_child(container)

		# Stagger spawn animation
		container.scale = Vector2.ZERO
		container.modulate.a = 0.0
		var spawn_delay := i * 0.1
		var spawn_tween := create_tween()
		spawn_tween.tween_interval(spawn_delay)
		spawn_tween.set_parallel(true)
		spawn_tween.tween_property(container, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		spawn_tween.tween_property(container, "modulate:a", 1.0, 0.3)

		_mob_containers.append(container)
		_mob_sprites.append(sprite)
		_mob_hp_bars.append(hp)

func clear_mobs() -> void:
	for child in entities.get_children():
		if child.name == "PlayerAnchor":
			continue
		child.queue_free()
	_mob_sprites.clear()
	_mob_hp_bars.clear()
	_mob_containers.clear()

func update_mob_visual(mob_id: int, hp: int, _max_hp: int) -> void:
	if mob_id < 0 or mob_id >= _mob_containers.size():
		return
	if not is_instance_valid(_mob_containers[mob_id]):
		return
	var container: Node2D = _mob_containers[mob_id]
	if hp <= 0:
		if mob_id < _mob_sprites.size() and is_instance_valid(_mob_sprites[mob_id]):
			_play_sprite_anim(_mob_sprites[mob_id], "death")
		# Death smoke particles
		var smoke := CPUParticles2D.new()
		smoke.emitting = false
		smoke.one_shot = true
		smoke.amount = 12
		smoke.lifetime = 0.5
		smoke.explosiveness = 0.8
		smoke.direction = Vector2(0, -1)
		smoke.spread = 180.0
		smoke.initial_velocity_min = 20.0
		smoke.initial_velocity_max = 50.0
		smoke.gravity = Vector2(0, -20)
		smoke.scale_amount_min = 2.0
		smoke.scale_amount_max = 5.0
		smoke.color = Color(0.3, 0.1, 0.4, 0.7)  # dark purple
		smoke.position = container.position
		add_child(smoke)
		smoke.emitting = true
		get_tree().create_timer(0.7).timeout.connect(func():
			if is_instance_valid(smoke):
				smoke.queue_free()
		)
		var tween := create_tween()
		tween.tween_interval(0.45)
		tween.tween_property(container, "scale", Vector2.ZERO, 0.35).set_ease(Tween.EASE_IN)
		tween.tween_callback(container.queue_free)

func play_skill_vfx(skill_type: String, world_pos: Vector2) -> void:
	if _combat_fx != null and is_instance_valid(_combat_fx) and _combat_fx.has_method("spawn_skill_particles"):
		_combat_fx.spawn_skill_particles(world_pos, skill_type)
	if skill_type == "heavy" and _combat_fx != null and is_instance_valid(_combat_fx) and _combat_fx.has_method("screen_flash"):
		_combat_fx.screen_flash(Color(1, 0.92, 0.72, 0.12), 0.12)

func face_hero_toward(target_pos: Vector2) -> void:
	if _player_sprite == null or not is_instance_valid(_player_sprite):
		return
	_player_sprite.flip_h = target_pos.x < _player_sprite.global_position.x

func face_mobs_toward_player() -> void:
	for mob in _mob_sprites:
		if is_instance_valid(mob):
			mob.flip_h = player_anchor.global_position.x < mob.global_position.x

func play_attack(target_mob_id: int) -> void:
	var target_node := get_mob_node(target_mob_id)
	if target_node != null:
		face_hero_toward(target_node.global_position)
	_play_sprite_anim(_player_sprite, "attack")
	var base_pos := player_anchor.position
	var lunge := Vector2(0, -20)
	if target_node != null:
		var dir := (target_node.global_position - player_anchor.global_position).normalized()
		lunge = dir * 40.0
	var tween := create_tween()
	tween.tween_property(player_anchor, "position", base_pos + lunge, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(player_anchor, "position", base_pos, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if target_mob_id >= 0 and target_mob_id < _mob_sprites.size() and is_instance_valid(_mob_sprites[target_mob_id]):
		_play_sprite_anim(_mob_sprites[target_mob_id], "hit")
		_flash_sprite(_mob_sprites[target_mob_id], 0.15)
		get_tree().create_timer(0.35).timeout.connect(func():
			if target_mob_id < _mob_sprites.size() and is_instance_valid(_mob_sprites[target_mob_id]):
				_play_sprite_anim(_mob_sprites[target_mob_id], "idle")
		)
	get_tree().create_timer(0.45).timeout.connect(func():
		if is_instance_valid(_player_sprite):
			_play_sprite_anim(_player_sprite, "idle")
	)

func play_mob_turn() -> void:
	for mob in _mob_sprites:
		if is_instance_valid(mob):
			_play_sprite_anim(mob, "attack")
			get_tree().create_timer(0.4).timeout.connect(func():
				if is_instance_valid(mob):
					_play_sprite_anim(mob, "idle")
			)
	if is_instance_valid(_player_sprite):
		_play_sprite_anim(_player_sprite, "hit")
		_flash_sprite(_player_sprite, 0.15)
		get_tree().create_timer(0.35).timeout.connect(func():
			if is_instance_valid(_player_sprite):
				_play_sprite_anim(_player_sprite, "idle")
		)

func play_player_death() -> void:
	_play_sprite_anim(_player_sprite, "death")

func play_victory() -> void:
	_play_sprite_anim(_player_sprite, "idle")

func spawn_damage_number(world_pos: Vector2, amount: int, is_heal: bool = false, is_heavy: bool = false, is_player_damage: bool = false) -> void:
	var label := Label.new()
	label.text = str(amount) if not is_heal else "+%d" % amount
	label.position = world_pos + Vector2(randf_range(-20, 20), -130)
	var font_size := 24
	if is_heal:
		label.modulate = Color(0.3, 1.0, 0.4)
	elif is_player_damage:
		label.modulate = Color(1.0, 0.3, 0.3)
		font_size = 28
	elif is_heavy:
		label.modulate = Color(1.0, 0.95, 0.3)
		font_size = 32
	else:
		label.modulate = Color(1.0, 0.9, 0.8)
	label.add_theme_font_size_override("font_size", font_size)
	label.rotation_degrees = randf_range(-5.0, 5.0)
	label.z_index = 100
	add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(randf_range(-12, 12), -60), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.45)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

func get_mob_world_position(mob_id: int) -> Vector2:
	if mob_id >= 0 and mob_id < _mob_containers.size() and is_instance_valid(_mob_containers[mob_id]):
		return _mob_containers[mob_id].global_position
	return Vector2.ZERO

func get_player_world_position() -> Vector2:
	return player_anchor.global_position

func get_mob_node(mob_id: int) -> Node2D:
	if mob_id >= 0 and mob_id < _mob_containers.size() and is_instance_valid(_mob_containers[mob_id]):
		return _mob_containers[mob_id]
	return null

func update_mob_hp(mob_index: int, current_hp: int, max_hp: int) -> void:
	if mob_index < 0 or mob_index >= _mob_hp_bars.size():
		return
	if not is_instance_valid(_mob_hp_bars[mob_index]):
		return
	var bar: ColorRect = _mob_hp_bars[mob_index]
	var ratio := float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
	var mat := bar.material as ShaderMaterial
	if mat != null:
		var current_ratio: float = mat.get_shader_parameter("health_ratio")
		var tween := create_tween()
		tween.tween_method(func(v: float): mat.set_shader_parameter("health_ratio", v), current_ratio, ratio, 0.25)
	bar.visible = current_hp > 0

func on_state_changed(state: int, zone_id: int, prev_state: int) -> void:
	load_zone(zone_id)
	spawn_hero()
	var game_camera: Node = get_parent().get_node_or_null("GameCamera")
	match state:
		0:
			clear_mobs()
			if game_camera and game_camera.has_method("combat_zoom_out"):
				game_camera.combat_zoom_out()
		1:
			spawn_mobs(ZONE_MOB_COUNT.get(zone_id, 0), zone_id)
			if game_camera and game_camera.has_method("combat_zoom_out"):
				game_camera.combat_zoom_out()
		2:
			if _mob_containers.is_empty():
				spawn_mobs(ZONE_MOB_COUNT.get(zone_id, 0), zone_id)
			var first_mob := get_mob_node(0)
			if first_mob != null:
				face_hero_toward(first_mob.global_position)
			face_mobs_toward_player()
			if game_camera and game_camera.has_method("combat_zoom_in"):
				game_camera.combat_zoom_in()
		3:
			clear_mobs()
			if game_camera and game_camera.has_method("zone_transition"):
				game_camera.zone_transition()
		4:
			clear_mobs()
			play_victory()
		5:
			play_player_death()
	if prev_state != state and state in [3, 4, 5]:
		if game_camera and game_camera.has_method("shake"):
			game_camera.shake(4.0, 0.15)

func _make_hit_flash_material() -> Material:
	if _hit_flash_shader == null:
		return null
	var mat := ShaderMaterial.new()
	mat.shader = _hit_flash_shader
	mat.set_shader_parameter("flash_amount", 0.0)
	return mat

func _flash_sprite(sprite: AnimatedSprite2D, duration: float) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	var mat := sprite.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("flash_amount", 0.8)
		var tween := create_tween()
		tween.tween_method(
			func(v: float):
				if is_instance_valid(sprite) and sprite.material is ShaderMaterial:
					(sprite.material as ShaderMaterial).set_shader_parameter("flash_amount", v),
			0.8,
			0.0,
			duration
		)
	else:
		var old := sprite.modulate
		sprite.modulate = Color(4.0, 4.0, 4.0, 1.0)
		get_tree().create_timer(duration).timeout.connect(func():
			if is_instance_valid(sprite):
				sprite.modulate = old
		)

func _play_sprite_anim(sprite: AnimatedSprite2D, anim_name: String) -> void:
	if sprite == null or not is_instance_valid(sprite) or sprite.sprite_frames == null:
		return
	var chosen := anim_name
	if not sprite.sprite_frames.has_animation(chosen):
		for alias in ANIM_ALIASES.get(anim_name, []):
			if sprite.sprite_frames.has_animation(alias):
				chosen = alias
				break
	if sprite.sprite_frames.has_animation(chosen):
		sprite.play(chosen)

func _get_mob_type(zone_id: int) -> String:
	match zone_id:
		1:
			return "mob_ember"
		2:
			return "mob_aether"
		3:
			return "mob_sunken"
		4:
			return "mob_crystal"
		_:
			return "mob_ember"

func _get_mob_light_color(zone_id: int) -> Color:
	match zone_id:
		1:
			return Color(1.0, 0.5, 0.2)
		2:
			return Color(0.6, 0.4, 0.7)
		3:
			return Color(0.3, 0.9, 0.8)
		4:
			return Color(0.2, 0.7, 0.5)
		_:
			return Color(1.0, 0.5, 0.2)

func _make_placeholder_frames(color: Color) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var texture := ImageTexture.create_from_image(img)
	for anim_name in ["idle", "attack", "hit", "death"]:
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, 2.0)
		frames.set_animation_loop(anim_name, anim_name == "idle")
		frames.add_frame(anim_name, texture)
	return frames

func _create_blob_shadow(shadow_scale: Vector2 = Vector2(1.0, 0.6)) -> Sprite2D:
	var shadow := Sprite2D.new()
	var img := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	for x in range(64):
		for y in range(32):
			var dx := (float(x) - 32.0) / 32.0
			var dy := (float(y) - 16.0) / 16.0
			var d := dx * dx + dy * dy
			var a := clampf(1.0 - d, 0.0, 1.0) * 0.35
			img.set_pixel(x, y, Color(0, 0, 0, a))
	shadow.texture = ImageTexture.create_from_image(img)
	shadow.scale = shadow_scale
	shadow.z_index = -1
	shadow.position = Vector2(0, 0)
	return shadow

func _load_texture_safe(res_path: String) -> Texture2D:
	# Try Godot resource loader first (needs .import files)
	if ResourceLoader.exists(res_path):
		return load(res_path) as Texture2D
	# Fallback: load raw image from filesystem
	var abs_path := ProjectSettings.globalize_path(res_path)
	var img := Image.new()
	if img.load(abs_path) == OK:
		return ImageTexture.create_from_image(img)
	return null
