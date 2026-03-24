extends Control

signal auth_url_matched(url: String)
signal auth_closed
signal auth_error(message: String)

const CARTRIDGE_HOST := "x.cartridge.gg"

var browser_container: MarginContainer
var close_button: Button
var loading_label: Label
var error_label: Label

var _cef_texture: Control
var _seen_cartridge_domain := false
var _completion_emitted := false
var _initialized := false

func _ready() -> void:
	visible = false
	_try_init()

func _try_init() -> void:
	if _initialized:
		return
	browser_container = _find("BrowserContainer") as MarginContainer
	close_button = _find("CloseButton") as Button
	loading_label = _find("LoadingLabel") as Label
	error_label = _find("ErrorLabel") as Label
	if browser_container == null or close_button == null or loading_label == null or error_label == null:
		return
	_initialized = true
	error_label.visible = false
	loading_label.visible = false
	close_button.pressed.connect(_on_close_pressed)

func _find(node_name: String) -> Node:
	return find_child(node_name, true, false)

func show_auth(url: String) -> void:
	_try_init()
	_completion_emitted = false
	_seen_cartridge_domain = false
	if error_label != null:
		error_label.visible = false
		error_label.text = ""
	if loading_label != null:
		loading_label.visible = true
		loading_label.text = "Loading authentication..."
	visible = true

	if not _ensure_browser():
		_show_error("Embedded browser unavailable. Install godot-cef or use external browser.")
		auth_error.emit(error_label.text if error_label else "Browser unavailable")
		return

	_cef_texture.set("url", url)

func hide_auth() -> void:
	if _cef_texture != null and _cef_texture.has_method("stop_loading"):
		_cef_texture.call("stop_loading")
	visible = false
	if loading_label != null:
		loading_label.visible = false
	if error_label != null:
		error_label.visible = false

func is_showing() -> bool:
	return visible

func _ensure_browser() -> bool:
	if _cef_texture != null and is_instance_valid(_cef_texture):
		return true
	if not ClassDB.class_exists("CefTexture"):
		return false

	var created: Variant = ClassDB.instantiate("CefTexture")
	if created == null or not (created is Control):
		return false

	_cef_texture = created as Control
	_cef_texture.name = "CefTexture"
	_cef_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	if browser_container != null:
		browser_container.add_child(_cef_texture)

	if _cef_texture.has_signal("url_changed"):
		_cef_texture.connect("url_changed", Callable(self, "_on_url_changed"))
	if _cef_texture.has_signal("load_started"):
		_cef_texture.connect("load_started", Callable(self, "_on_load_started"))
	if _cef_texture.has_signal("load_finished"):
		_cef_texture.connect("load_finished", Callable(self, "_on_load_finished"))
	if _cef_texture.has_signal("load_error"):
		_cef_texture.connect("load_error", Callable(self, "_on_load_error"))

	return true

func _on_url_changed(url: String) -> void:
	var lowered := url.to_lower()
	if lowered.find(CARTRIDGE_HOST) != -1:
		_seen_cartridge_domain = true

	if _completion_emitted:
		return
	if _is_completion_url(lowered):
		_completion_emitted = true
		auth_url_matched.emit(url)

func _is_completion_url(lowered_url: String) -> bool:
	if lowered_url.find("registered=true") != -1:
		return true
	if lowered_url.find("session_id=") != -1:
		return true
	if _seen_cartridge_domain and lowered_url.find(CARTRIDGE_HOST) == -1:
		return true
	return false

func _on_load_started(_url: String) -> void:
	if loading_label != null:
		loading_label.visible = true
	if error_label != null:
		error_label.visible = false

func _on_load_finished(_url: String, _http_status_code: int) -> void:
	if loading_label != null:
		loading_label.visible = false

func _on_load_error(_url: String, _error_code: int, error_text: String) -> void:
	_show_error("Authentication page failed to load: %s" % error_text)
	auth_error.emit(error_label.text if error_label else error_text)

func _on_close_pressed() -> void:
	hide_auth()
	auth_closed.emit()

func _show_error(message: String) -> void:
	if loading_label != null:
		loading_label.visible = false
	if error_label != null:
		error_label.text = message
		error_label.visible = true
