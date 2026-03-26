extends SceneTree

var spent_count:int = 0
var refilled_count:int = 0
var depleted_count:int = 0

func _pass(pass_count:int, message:String) -> int:
	print("  PASS: %s" % message)
	return pass_count + 1

func _fail(fail_count:int, message:String) -> int:
	print("  FAIL: %s" % message)
	return fail_count + 1

func _init() -> void:
	var pass_count:int = 0
	var fail_count:int = 0

	var stamina_script:GDScript = preload("res://scripts/resources/stamina_resource.gd")
	var stamina = stamina_script.new()

	stamina.stamina_spent.connect(_on_stamina_spent)
	stamina.stamina_refilled.connect(_on_stamina_refilled)
	stamina.stamina_depleted.connect(_on_stamina_depleted)

	if stamina.value == 100:
		pass_count = _pass(pass_count, "initial value is 100")
	else:
		fail_count = _fail(fail_count, "initial value expected 100, got %d" % stamina.value)

	var spend_20:bool = stamina.spend(20)
	if spend_20 && stamina.value == 80:
		pass_count = _pass(pass_count, "spend(20) succeeds and value becomes 80")
	else:
		fail_count = _fail(fail_count, "spend(20) expected true and 80, got %s and %d" % [str(spend_20), stamina.value])

	var spend_90:bool = stamina.spend(90)
	if !spend_90 && stamina.value == 80:
		pass_count = _pass(pass_count, "spend(90) fails when stamina is insufficient")
	else:
		fail_count = _fail(fail_count, "spend(90) expected false and value 80, got %s and %d" % [str(spend_90), stamina.value])

	stamina.refill()
	if stamina.value == 100:
		pass_count = _pass(pass_count, "refill resets value to 100")
	else:
		fail_count = _fail(fail_count, "refill expected 100, got %d" % stamina.value)

	stamina.spend(100)
	if spent_count == 2 && refilled_count == 1 && depleted_count == 1:
		pass_count = _pass(pass_count, "signals emitted for spend, refill, and depletion")
	else:
		fail_count = _fail(fail_count, "signals expected spent=2 refilled=1 depleted=1, got spent=%d refilled=%d depleted=%d" % [spent_count, refilled_count, depleted_count])

	print("\n%d passed, %d failed" % [pass_count, fail_count])
	quit(1 if fail_count > 0 else 0)

func _on_stamina_spent(_cost:int) -> void:
	spent_count += 1

func _on_stamina_refilled() -> void:
	refilled_count += 1

func _on_stamina_depleted() -> void:
	depleted_count += 1
