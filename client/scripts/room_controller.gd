extends Node2D

signal door_interacted(target_zone: int)
signal battle_triggered()
signal room_ready()

var config: Dictionary = {}
var _doors: Array[Area2D] = []
var _player_ref: Node2D = null
var _player_inside_door: Area2D = null
var state_machine: Node = null

func _ready() -> void:
    state_machine = preload("res://scripts/room_state_machine.gd").new()
    state_machine.name = "StateMachine"
    add_child(state_machine)

func configure(room_config: Dictionary) -> void:
    config = room_config

func place_player(player: Node2D) -> void:
    _player_ref = player
    var spawn_pos: Vector2 = config.get("player_spawn", Vector2(800, 900))
    player.position = spawn_pos

func create_door(door_data: Dictionary) -> Area2D:
    var door := Area2D.new()
    door.name = "Door_%d" % door_data.get("target_zone", 0)
    door.collision_layer = CollisionLayers.DOORS
    door.collision_mask = CollisionLayers.PLAYER
    door.set_meta("target_zone", door_data.get("target_zone", 0))
    door.set_meta("label", door_data.get("label", "Continue"))
    var shape := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = 60.0
    shape.shape = circle
    door.add_child(shape)
    door.position = door_data.get("position", Vector2.ZERO)
    var portal := _create_portal_visual()
    door.add_child(portal)
    door.body_entered.connect(_on_door_body_entered.bind(door))
    door.body_exited.connect(_on_door_body_exited.bind(door))
    return door

func spawn_doors() -> void:
    for existing in _doors:
        existing.queue_free()
    _doors.clear()
    for door_data in config.get("door_configs", []):
        var door := create_door(door_data)
        door.visible = config.get("is_fork", false)
        add_child(door)
        _doors.append(door)

func show_exit_doors() -> void:
    for door in _doors:
        if not is_instance_valid(door):
            continue
        door.visible = true
        door.monitoring = true

func hide_all_doors() -> void:
    for door in _doors:
        if is_instance_valid(door):
            door.visible = false

func create_battle_trigger() -> Area2D:
    var trigger_rect: Rect2 = config.get("trigger_rect", Rect2())
    if trigger_rect == Rect2():
        return null
    var trigger := Area2D.new()
    trigger.name = "BattleTrigger"
    trigger.collision_layer = CollisionLayers.TRIGGERS
    trigger.collision_mask = CollisionLayers.PLAYER
    trigger.monitoring = false
    var shape := CollisionShape2D.new()
    var rect_shape := RectangleShape2D.new()
    rect_shape.size = trigger_rect.size
    shape.shape = rect_shape
    trigger.add_child(shape)
    trigger.position = trigger_rect.position + trigger_rect.size / 2.0
    trigger.body_entered.connect(_on_trigger_body_entered)
    add_child(trigger)
    return trigger

func enable_battle_trigger() -> void:
    var trigger := get_node_or_null("BattleTrigger") as Area2D
    if trigger != null:
        trigger.monitoring = true

func _on_door_body_entered(body: Node2D, door: Area2D) -> void:
    if body == _player_ref:
        _player_inside_door = door

func _on_door_body_exited(body: Node2D, door: Area2D) -> void:
    if body == _player_ref and _player_inside_door == door:
        _player_inside_door = null

func _on_trigger_body_entered(body: Node2D) -> void:
    if body == _player_ref and state_machine != null and state_machine.is_state(state_machine.State.EXPLORING):
        var trigger := get_node_or_null("BattleTrigger") as Area2D
        if trigger != null:
            trigger.monitoring = false
        battle_triggered.emit()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("interact") and _player_inside_door != null:
        var target_zone: int = _player_inside_door.get_meta("target_zone")
        door_interacted.emit(target_zone)
        get_viewport().set_input_as_handled()

func get_player_inside_door() -> Area2D:
    return _player_inside_door

func _create_portal_visual() -> Sprite2D:
    var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
    for x in range(64):
        for y in range(64):
            var dx := (float(x) - 32.0) / 32.0
            var dy := (float(y) - 32.0) / 32.0
            var d := sqrt(dx * dx + dy * dy)
            var a := clampf(1.0 - d, 0.0, 1.0) * 0.8
            img.set_pixel(x, y, Color(0.3, 0.7, 1.0, a))
    var sprite := Sprite2D.new()
    sprite.texture = ImageTexture.create_from_image(img)
    sprite.scale = Vector2(2.0, 2.0)
    return sprite
