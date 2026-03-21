extends Node

signal torii_connected(success: bool)
signal session_ready(address: String)
signal tx_submitted(action: String)
signal tx_failed(action: String, reason: String)

const CHARACTER_MODEL := "athanor-Character"
const DUNGEON_MODEL := "athanor-Dungeon"
const FIGHT_MODEL := "athanor-Fight"
const DIRECTION_LEFT := 0
const DIRECTION_RIGHT := 1

@export var torii_url := "http://localhost:8080"
@export var rpc_url := "http://localhost:5050"
@export var relay_url := "https://api.cartridge.gg"
@export var session_base_url := "https://x.cartridge.gg/session"
@export var world_address := "0x0"
@export var actions_address := "0x0"

var torii_client: Node
var session_account: Node
var http_tools: Node
var current_player := ""
var entity_subscription_id := -1

# Ephemeral session key — generated internally, NEVER user-provided
var _session_priv_key := ""

var full_policies: Dictionary:
	get:
		if actions_address == "0x0":
			return {}
		return {
			actions_address: {
				"methods": [
					{"entrypoint": "spawn"},
					{"entrypoint": "choose"},
					{"entrypoint": "start"},
					{"entrypoint": "cast"},
					{"entrypoint": "finish"}
				]
			}
		}

func configure_nodes(next_torii_client: Node, next_session_account: Node, next_http_tools: Node = null) -> void:
	torii_client = next_torii_client
	session_account = next_session_account
	http_tools = next_http_tools
	session_account.set("max_fee", "0x100000")
	session_account.set("full_policies", full_policies)

func configure_network(next_torii_url: String, next_rpc_url: String, next_world_address: String, next_actions_address: String) -> void:
	torii_url = next_torii_url
	rpc_url = next_rpc_url
	world_address = next_world_address
	actions_address = next_actions_address
	if session_account != null:
		session_account.set("full_policies", full_policies)

# --- Auth: Controller session flow (no private key input) ---

func connect_torii() -> bool:
	if torii_client == null:
		tx_failed.emit("connect", "ToriiClient node is missing")
		return false
	var ok: bool = bool(torii_client.call("connect", torii_url))
	torii_connected.emit(ok)
	if ok:
		_create_entity_subscription()
		pull_entities_snapshot()
	return ok

func initiate_controller_auth() -> void:
	if session_account == null:
		tx_failed.emit("auth", "DojoSessionAccount node is missing")
		return

	# Generate ephemeral keypair if not already generated
	if _session_priv_key.is_empty():
		if ClassDB.class_exists("ControllerHelper"):
			_session_priv_key = String(ClassDB.instantiate("ControllerHelper").call("generate_private_key"))
		else:
			tx_failed.emit("auth", "ControllerHelper not available (install godot-dojo SDK)")
			return

	var session_url := _build_session_url()
	if session_url.is_empty():
		tx_failed.emit("auth", "Could not generate session URL")
		return

	# Allow window to steal focus back after browser auth
	DisplayServer.enable_for_stealing_focus(OS.get_process_id())
	OS.shell_open(session_url)

func complete_controller_auth() -> bool:
	if session_account == null:
		tx_failed.emit("auth", "DojoSessionAccount node is missing")
		return false
	if _session_priv_key.is_empty():
		tx_failed.emit("auth", "No session key generated — call initiate_controller_auth() first")
		return false

	session_account.call("create_from_subscribe", _session_priv_key, rpc_url, relay_url)
	if bool(session_account.call("is_valid")):
		var info: Dictionary = session_account.call("get_info")
		current_player = String(info.get("address", "")).to_lower()
		session_ready.emit(current_player)
		pull_entities_snapshot()
		return true
	return false

func get_player_info() -> Dictionary:
	if session_account == null or not bool(session_account.call("is_valid")):
		return {}
	return session_account.call("get_info")

func is_session_valid() -> bool:
	if session_account == null:
		return false
	return bool(session_account.call("is_valid"))

func _build_session_url() -> String:
	if not ClassDB.class_exists("ControllerHelper"):
		return ""
	var helper: Variant = ClassDB.instantiate("ControllerHelper")
	var public_key := String(helper.call("get_public_key", _session_priv_key))
	if public_key.is_empty():
		return ""

	# Start local redirect server if HttpTools is available
	var redirect_uri := ""
	var redirect_query_name := ""
	if http_tools != null and http_tools.has_method("start_server"):
		if bool(http_tools.call("start_server")):
			var port: int = int(http_tools.get("port"))
			redirect_uri = "http://localhost:%d" % port
			redirect_query_name = "startapp"

	return String(session_account.call("generate_session_request_url",
		session_base_url,
		public_key,
		rpc_url,
		session_account.call("get_register_session_policy"),
		redirect_uri,
		redirect_query_name
	))

# --- Entity sync ---

func pull_entities_snapshot() -> void:
	if torii_client == null:
		return
	var query: Variant = _instantiate_dojo_class("DojoQuery")
	if query == null:
		return
	var response: Dictionary = torii_client.call("entities", query)
	var items: Array = response.get("items", [])
	for entity in items:
		if entity is Dictionary:
			_handle_entity_payload(entity)

# --- Game actions ---

func spawn(class_id: int = 0) -> void:
	_execute_action("spawn", [class_id])

func choose(game_id: int, direction: int) -> void:
	_execute_action("choose", [_resolve_game_id(game_id), direction])

func start(game_id: int) -> void:
	_execute_action("start", [_resolve_game_id(game_id)])

func cast(game_id: int, mob_id: int, skill_id: int) -> void:
	_execute_action("cast", [_resolve_game_id(game_id), mob_id, skill_id])

func finish(game_id: int) -> void:
	_execute_action("finish", [_resolve_game_id(game_id)])

# --- Internals ---

func _create_entity_subscription() -> void:
	if world_address == "0x0":
		return
	var callback: Variant = _instantiate_dojo_class("DojoCallback")
	var clause: Variant = _instantiate_dojo_class("DojoClause")
	if callback == null or clause == null:
		return
	callback.set("on_update", Callable(self, "_on_entities"))
	entity_subscription_id = int(torii_client.call("subscribe_entity_updates", clause, [world_address], callback))

func _on_entities(args: Dictionary) -> void:
	_handle_entity_payload(args)

func _handle_entity_payload(payload: Dictionary) -> void:
	var models: Dictionary = payload.get("models", {})
	if models.has(CHARACTER_MODEL):
		var character_model := _normalize_model(models[CHARACTER_MODEL])
		if _matches_current_player(character_model):
			game_state.update_character(character_model)
	if models.has(DUNGEON_MODEL):
		var dungeon_model := _normalize_model(models[DUNGEON_MODEL])
		if _matches_current_player(dungeon_model):
			game_state.update_dungeon(dungeon_model)
	if models.has(FIGHT_MODEL):
		var fight_model := _normalize_model(models[FIGHT_MODEL])
		if _matches_current_player(fight_model):
			game_state.update_fight(fight_model)

func _normalize_model(model: Dictionary) -> Dictionary:
	var normalized := model.duplicate(true)
	if normalized.has("player"):
		normalized["player"] = String(normalized["player"]).to_lower()
	for key in normalized.keys():
		var value: Variant = normalized[key]
		if value is String and String(value).begins_with("0x"):
			normalized[key] = String(value).to_lower()
	return normalized

func _matches_current_player(model: Dictionary) -> bool:
	if current_player.is_empty():
		return true
	return String(model.get("player", "")).to_lower() == current_player

func _execute_action(entrypoint: String, calldata: Array) -> void:
	if session_account == null or not bool(session_account.call("is_valid")):
		tx_failed.emit(entrypoint, "No active session")
		return
	if actions_address == "0x0":
		tx_failed.emit(entrypoint, "Set actions_address in Main scene inspector")
		return
	var call := {
		"contract_address": actions_address,
		"entrypoint": entrypoint,
		"calldata": calldata,
	}
	session_account.call("execute", [call])
	tx_submitted.emit(entrypoint)

func _resolve_game_id(game_id: int) -> int:
	if game_id >= 0:
		return game_id
	return game_state.get_game_id()

func _instantiate_dojo_class(type_name: String) -> Variant:
	if not ClassDB.class_exists(type_name):
		return null
	return ClassDB.instantiate(type_name)
