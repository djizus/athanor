extends SceneTree


func _pass(pass_count:int, message:String) -> int:
	print("  PASS: %s" % message)
	return pass_count + 1


func _fail(fail_count:int, message:String) -> int:
	print("  FAIL: %s" % message)
	return fail_count + 1


func _make_ability(ability_script:GDScript, id:int, name:String, stamina_cost:int, cooldown_turns:int) -> AbilityResource:
	var ability:AbilityResource = ability_script.new()
	ability.ability_id = id
	ability.ability_name = name
	ability.stamina_cost = stamina_cost
	ability.cooldown_turns = cooldown_turns
	ability.current_cooldown = 0
	return ability


func _init() -> void:
	var pass_count:int = 0
	var fail_count:int = 0
	var enums_script:GDScript = preload("res://scripts/combat/combat_enums.gd")
	var stamina_script:GDScript = preload("res://scripts/resources/stamina_resource.gd")
	var ability_script:GDScript = preload("res://scripts/resources/ability_resource.gd")
	var manager_script:GDScript = preload("res://scripts/combat/ability_manager.gd")

	var stamina:StaminaResource = stamina_script.new()
	stamina.max_value = 100
	stamina.value = 100

	var strike:AbilityResource = _make_ability(ability_script, enums_script.AbilityID.STRIKE, "Strike", 15, 1)
	var dash:AbilityResource = _make_ability(ability_script, enums_script.AbilityID.DASH, "Dash", 30, 2)
	var guard:AbilityResource = _make_ability(ability_script, enums_script.AbilityID.GUARD, "Guard", 20, 1)

	var manager = manager_script.new()
	var abilities:Array[AbilityResource] = [strike, dash, guard]
	manager.abilities = abilities
	manager.stamina_resource = stamina

	manager.select_ability(0)
	if manager.get_selected() == strike:
		pass_count = _pass(pass_count, "select_ability(0) sets selected ability")
	else:
		fail_count = _fail(fail_count, "selected ability should be Strike")

	var first_use_ok:bool = manager.use_ability({"cell": Vector2i(4, 4)})
	if first_use_ok && stamina.value == 85:
		pass_count = _pass(pass_count, "use_ability deducts stamina")
	else:
		fail_count = _fail(fail_count, "first use expected success with stamina=85, got success=%s stamina=%d" % [str(first_use_ok), stamina.value])

	var blocked_by_cooldown:bool = !manager.use_ability({"cell": Vector2i(4, 4)})
	if blocked_by_cooldown && strike.current_cooldown == 1:
		pass_count = _pass(pass_count, "cooldown blocks reuse before ticking")
	else:
		fail_count = _fail(fail_count, "cooldown should block immediate second use (cd=%d)" % strike.current_cooldown)

	manager.tick_cooldowns()
	if strike.current_cooldown == 0:
		pass_count = _pass(pass_count, "tick_cooldowns reduces cooldown by one")
	else:
		fail_count = _fail(fail_count, "strike cooldown expected 0 after tick, got %d" % strike.current_cooldown)

	var use_after_tick:bool = manager.use_ability({"cell": Vector2i(5, 4)})
	if use_after_tick && stamina.value == 70:
		pass_count = _pass(pass_count, "ability can be used again after cooldown expires")
	else:
		fail_count = _fail(fail_count, "expected second valid use with stamina=70, got success=%s stamina=%d" % [str(use_after_tick), stamina.value])

	stamina.value = 10
	manager.select_ability(1)
	var insufficient_stamina_block:bool = !manager.use_ability({"direction": Vector2i(1, 0)})
	if insufficient_stamina_block && stamina.value == 10:
		pass_count = _pass(pass_count, "use_ability fails when stamina is insufficient")
	else:
		fail_count = _fail(fail_count, "insufficient stamina should fail and keep stamina=10")

	stamina.value = 100
	manager.select_ability(1)
	var dash_first_ok:bool = manager.use_ability({"direction": Vector2i(0, -1)})
	var dash_second_blocked:bool = !manager.use_ability({"direction": Vector2i(0, -1)})
	manager.tick_cooldowns()
	var dash_still_blocked:bool = !manager.use_ability({"direction": Vector2i(0, -1)})
	manager.tick_cooldowns()
	var dash_ready_again:bool = manager.use_ability({"direction": Vector2i(0, -1)})
	if dash_first_ok && dash_second_blocked && dash_still_blocked && dash_ready_again:
		pass_count = _pass(pass_count, "cooldown_turns=2 blocks for two turns and then allows use")
	else:
		fail_count = _fail(fail_count, "dash cooldown lifecycle failed (first=%s blocked_now=%s blocked_after_1=%s ready_after_2=%s)" % [str(dash_first_ok), str(dash_second_blocked), str(dash_still_blocked), str(dash_ready_again)])

	if strike.stamina_cost == 15 && dash.stamina_cost == 30 && guard.stamina_cost == 20:
		pass_count = _pass(pass_count, "all three abilities have expected stamina costs")
	else:
		fail_count = _fail(fail_count, "ability costs mismatch: strike=%d dash=%d guard=%d" % [strike.stamina_cost, dash.stamina_cost, guard.stamina_cost])

	print("\n%d passed, %d failed" % [pass_count, fail_count])
	quit(1 if fail_count > 0 else 0)
