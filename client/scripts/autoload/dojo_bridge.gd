extends Node

signal torii_connected(success: bool)
signal session_ready(address: String)
signal tx_submitted(action: String)
signal tx_failed(action: String, reason: String)
signal auth_url_ready(url: String)

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

# Burner mode: plain Katana dev account, txs via sozo CLI
var _burner_address := ""
var _burner_private_key := ""

# Ephemeral session key — generated internally, NEVER user-provided
var _session_priv_key := ""
const SESSION_CACHE_PATH := "user://controller_session.json"

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

# --- Auth: Burner account for local dev (no browser, no Controller) ---

const KATANA_CHAIN_ID := "0x4b4154414e41"  # felt("KATANA")

func setup_burner(private_key: String, address: String) -> bool:
	_burner_address = address
	_burner_private_key = private_key
	current_player = address.to_lower()
	session_ready.emit(current_player)
	push_warning("[dojo_bridge] Burner mode: %s (txs via sozo CLI)" % address)
	return true

# --- Auth: Controller session flow (no private key input) ---

func connect_torii() -> bool:
	if torii_client == null:
		tx_failed.emit("connect", "ToriiClient node is missing")
		return false
	if not torii_client.has_method("entities") or not torii_client.has_method("subscribe_entity_updates"):
		tx_failed.emit("connect", "ToriiClient SDK node missing (install godot-dojo addon)")
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

	if _can_use_embedded_auth_browser():
		auth_url_ready.emit(session_url)
		return

	# Fallback for mobile/web or when CefTexture is unavailable.
	DisplayServer.enable_for_stealing_focus(OS.get_process_id())
	OS.shell_open(session_url)

func complete_controller_auth() -> bool:
	if session_account == null:
		tx_failed.emit("auth", "DojoSessionAccount node is missing")
		return false
	if _session_priv_key.is_empty():
		tx_failed.emit("auth", "No session key generated — call initiate_controller_auth() first")
		return false

	var session_policies: Dictionary = session_account.call("get_session_policy")
	session_account.call("create_from_subscribe", _session_priv_key, rpc_url, session_policies, relay_url)
	if bool(session_account.call("is_valid")):
		var info: Dictionary = session_account.call("get_info")
		current_player = String(info.get("address", "")).to_lower()
		_save_session_info(_session_priv_key, info)
		session_ready.emit(current_player)
		call_deferred("pull_entities_snapshot")
		return true
	return false

func try_resume_controller_session() -> bool:
	if session_account == null or not session_account.has_method("create"):
		push_warning("[dojo_bridge] resume: no DojoSessionAccount SDK node")
		return false
	var cached := _load_session_info()
	if cached.is_empty():
		push_warning("[dojo_bridge] resume: no cached session at %s" % SESSION_CACHE_PATH)
		return false
	var cached_key := String(cached.get("private_key", ""))
	var cached_address := String(cached.get("address", ""))
	var cached_owner_guid := String(cached.get("owner_guid", ""))
	var cached_chain_id := String(cached.get("chain_id", ""))
	var expires_at := int(cached.get("expires_at", 0))
	if cached_key.is_empty() or cached_address.is_empty() or cached_owner_guid.is_empty() or cached_chain_id.is_empty() or expires_at <= 0:
		push_warning("[dojo_bridge] resume: incomplete cached data")
		return false
	var now := int(Time.get_unix_time_from_system())
	if now >= expires_at:
		push_warning("[dojo_bridge] resume: session expired (now=%d >= expires=%d)" % [now, expires_at])
		_clear_session_cache()
		return false
	push_warning("[dojo_bridge] resume: restoring session for %s (expires in %ds)" % [cached_address, expires_at - now])
	_session_priv_key = cached_key
	session_account.call("create", rpc_url, _session_priv_key, cached_address, cached_owner_guid, cached_chain_id, expires_at)
	var valid := bool(session_account.call("is_valid"))
	var expired := bool(session_account.call("is_expired"))
	var revoked := bool(session_account.call("is_revoked"))
	if valid and not expired and not revoked:
		var info: Dictionary = session_account.call("get_info")
		current_player = String(info.get("address", "")).to_lower()
		push_warning("[dojo_bridge] resume: success — player %s" % current_player)
		session_ready.emit(current_player)
		return true
	push_warning("[dojo_bridge] resume: failed (valid=%s expired=%s revoked=%s)" % [valid, expired, revoked])
	_clear_session_cache()
	return false

func get_player_info() -> Dictionary:
	if session_account == null or not bool(session_account.call("is_valid")):
		return {}
	return session_account.call("get_info")

func is_session_valid() -> bool:
	if session_account == null or not session_account.has_method("is_valid"):
		return false
	return bool(session_account.call("is_valid"))

func disconnect_session() -> void:
	current_player = ""
	_session_priv_key = ""
	_burner_address = ""
	_burner_private_key = ""
	_clear_session_cache()
	push_warning("[dojo_bridge] Session disconnected")

func _build_session_url() -> String:
	if not ClassDB.class_exists("ControllerHelper"):
		return ""
	var helper: Variant = ClassDB.instantiate("ControllerHelper")

	# Build policies in ControllerHelper format: {policies: [{target, method}]}
	var policy_list: Array = []
	for contract_address in full_policies.keys():
		var contract: Dictionary = full_policies[contract_address]
		var methods: Array = contract.get("methods", [])
		for method in methods:
			policy_list.append({
				"target": contract_address,
				"method": method.get("entrypoint", "")
			})
	var policies := {"policies": policy_list}
	var session_policies: Dictionary = session_account.call("get_session_policy")
	if session_policies.is_empty():
		session_policies = policies

	# Use the preferred API (ControllerHelper) instead of deprecated DojoSessionAccount method.
	# NOTE: rpc_url MUST be publicly reachable (Slot deployment, not localhost).
	# The Controller keychain page resolves chain_id by calling starknet_chainId on rpc_url.
	# localhost:5050 is unreachable from x.cartridge.gg → "No chainId" error.
	return String(helper.call("create_session_registration_url", _session_priv_key, session_policies, rpc_url, ""))

# --- Entity sync ---

func pull_entities_snapshot() -> void:
	if torii_client == null:
		return
	var query: Variant = _instantiate_dojo_class("DojoQuery")
	if query == null:
		return
	var response: Dictionary = torii_client.call("entities", query)
	var items: Array = response.get("items", [])
	push_warning("[dojo_bridge] Snapshot: %d entities returned" % items.size())
	for entity in items:
		if entity is Dictionary:
			push_warning("[dojo_bridge] Entity: %s" % str(entity).left(300))
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
	if callback == null:
		return
	callback.set("on_update", Callable(self, "_on_entities"))

	# Use KeysClause with our model names so Torii streams matching entity updates
	var clause: Variant = null
	if ClassDB.class_exists("KeysClause"):
		clause = ClassDB.instantiate("KeysClause")
		clause.call("add_model", CHARACTER_MODEL)
		clause.call("add_model", DUNGEON_MODEL)
		clause.call("add_model", FIGHT_MODEL)
		clause.call("pattern", 2)  # VariableLen
		push_warning("[dojo_bridge] Subscribing with KeysClause: %s, %s, %s" % [CHARACTER_MODEL, DUNGEON_MODEL, FIGHT_MODEL])
	else:
		clause = _instantiate_dojo_class("DojoClause")
		if clause == null:
			return

	entity_subscription_id = int(torii_client.call("subscribe_entity_updates", clause, [world_address], callback))
	push_warning("[dojo_bridge] Entity subscription ID: %d" % entity_subscription_id)

func _on_entities(args: Dictionary) -> void:
	push_warning("[dojo_bridge] SUBSCRIPTION entity update: %s" % str(args).left(500))
	_handle_entity_payload(args)

func _handle_entity_payload(payload: Dictionary) -> void:
	var models: Dictionary = payload.get("models", {})
	if models.is_empty():
		# Try flat payload — some SDK versions don't wrap in "models"
		if payload.has("player") or payload.has("health") or payload.has("game_id"):
			push_warning("[dojo_bridge] Flat entity payload, checking model type...")
			# Can't determine model type from flat dict, skip
			return
		return
	push_warning("[dojo_bridge] Entity models keys: %s" % str(models.keys()))
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
			# Only accept the fight for the current zone — old zone fights must not overwrite
			var current_zone := int(game_state.character.get("current_zone", -1))
			var fight_zone := int(fight_model.get("zone_id", -2))
			if current_zone < 0 or fight_zone == current_zone:
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
	var model_player := _normalize_hex(String(model.get("player", "")))
	var local_player := _normalize_hex(current_player)
	return model_player == local_player

func _normalize_hex(hex: String) -> String:
	var h := hex.to_lower().strip_edges()
	if h.begins_with("0x"):
		h = h.substr(2)
	h = h.lstrip("0")
	if h.is_empty():
		h = "0"
	return "0x" + h

func _execute_action(entrypoint: String, calldata: Array) -> void:
	if actions_address == "0x0":
		push_error("[dojo_bridge] actions_address is 0x0 — set it in project.godot or Main scene inspector")
		tx_failed.emit(entrypoint, "actions_address not configured")
		return

	var call := {
		"contract_address": actions_address,
		"entrypoint": entrypoint,
		"calldata": calldata,
	}

	if not _burner_private_key.is_empty():
		_sozo_execute(entrypoint, calldata)
		return

	# Controller mode: use DojoSessionAccount
	if session_account == null or not bool(session_account.call("is_valid")):
		push_error("[dojo_bridge] No active session for %s" % entrypoint)
		tx_failed.emit(entrypoint, "No active session")
		return
	var result: String = String(session_account.call("execute", [call]))
	if result.begins_with("0x"):
		push_warning("[dojo_bridge] tx %s submitted: %s" % [entrypoint, result])
		tx_submitted.emit(entrypoint)
		_schedule_entity_poll()
	else:
		push_error("[dojo_bridge] tx %s failed: %s" % [entrypoint, result])
		tx_failed.emit(entrypoint, result)

func _resolve_game_id(game_id: int) -> int:
	if game_id >= 0:
		return game_id
	return game_state.get_game_id()

var _poll_timer: Timer = null

func _schedule_entity_poll() -> void:
	if _poll_timer != null and _poll_timer.time_left > 0:
		return
	if _poll_timer == null:
		_poll_timer = Timer.new()
		_poll_timer.one_shot = true
		_poll_timer.timeout.connect(_on_poll_timer)
		add_child(_poll_timer)
	_poll_timer.start(2.0)

func _on_poll_timer() -> void:
	pull_entities_snapshot()

func _instantiate_dojo_class(type_name: String) -> Variant:
	if not ClassDB.class_exists(type_name):
		return null
	return ClassDB.instantiate(type_name)

func _sozo_execute(entrypoint: String, calldata: Array) -> void:
	var args: PackedStringArray = PackedStringArray([
		"execute", actions_address, entrypoint,
		"--rpc-url", rpc_url,
		"--account-address", _burner_address,
		"--private-key", _burner_private_key,
		"--world", world_address,
	])
	if not calldata.is_empty():
		args.append("--calldata")
		var parts: PackedStringArray = PackedStringArray()
		for arg in calldata:
			parts.append(str(arg))
		args.append(",".join(parts))

	var output: Array = []
	push_warning("[dojo_bridge] sozo %s" % " ".join(args))
	var exit_code := OS.execute("sozo", args, output, true)
	var stdout: String = "\n".join(output)

	if exit_code == 0:
		push_warning("[dojo_bridge] tx %s ok: %s" % [entrypoint, stdout.strip_edges()])
		tx_submitted.emit(entrypoint)
	else:
		push_error("[dojo_bridge] tx %s failed (exit %d): %s" % [entrypoint, exit_code, stdout.strip_edges()])
		tx_failed.emit(entrypoint, stdout.strip_edges())

func _save_session_info(key: String, info: Dictionary) -> void:
	if key.is_empty() or info.is_empty():
		return
	var file := FileAccess.open(SESSION_CACHE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"private_key": key,
		"address": String(info.get("address", "")),
		"owner_guid": String(info.get("owner_guid", "")),
		"chain_id": String(info.get("chain_id", "")),
		"expires_at": int(info.get("expires_at", 0))
	}))

func _load_session_info() -> Dictionary:
	if not FileAccess.file_exists(SESSION_CACHE_PATH):
		return {}
	var file := FileAccess.open(SESSION_CACHE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}

func _clear_session_cache() -> void:
	if FileAccess.file_exists(SESSION_CACHE_PATH):
		DirAccess.remove_absolute(SESSION_CACHE_PATH)

func _is_desktop_platform() -> bool:
	var os_name := OS.get_name()
	return os_name in ["Linux", "Windows", "macOS"]

func _can_use_embedded_auth_browser() -> bool:
	return _is_desktop_platform() and ClassDB.class_exists("CefTexture")
