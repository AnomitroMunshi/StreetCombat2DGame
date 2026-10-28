extends SceneTree
## Guard heights: a standing block stops everything but lows; a crouching (low)
## block stops everything but overheads (the overhead moves, and anything
## thrown in the air). A guard beaten on height records why (LOW / OVERHEAD).

var _fails: int = 0


func _check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


## Defender holding a block (crouched for a low block) toward the attacker.
func _guarding_pair(low_block: bool) -> Array[Fighter]:
	var a := Fighter.new()
	var d := Fighter.new()
	root.add_child(a)
	root.add_child(d)
	a.position = Vector2(600.0, 560.0)
	d.position = Vector2(680.0, 560.0)
	a.ground_y = 560.0
	d.ground_y = 560.0
	a.opponent = d
	d.opponent = a
	a.face_opponent()
	d.face_opponent()
	for i in CombatData.BLOCK_STARTUP_FRAMES + 3:
		var it := CombatData.Intent.new()
		it.block = true
		it.crouch = low_block
		d.push_intent(it)
		d.tick()
	return [a, d]


func _result(attack_type: int, low_block: bool, airborne: bool) -> Array:
	var p := _guarding_pair(low_block)
	p[0].airborne = airborne
	var r: int = p[1].receive_hit(CombatData.get_attack(attack_type), p[0], 1)
	var why: StringName = p[1].last_hit_wrong_height
	for f in p:
		f.queue_free()
	return [r, why]


func _initialize() -> void:
	var T := CombatData.AttackType
	var BLOCKED := CombatData.HitResult.BLOCKED
	print("[standing block]")
	_check(_result(T.LIGHT, false, false)[0] == BLOCKED, "stops a mid (jab)")
	_check(_result(T.OVERHAND, false, false)[0] == BLOCKED, "stops an overhead (overhand)")
	_check(_result(T.AXE_KICK, false, false)[0] == BLOCKED, "stops an overhead (axe kick)")
	_check(_result(T.JUMP_KICK, false, true)[0] == BLOCKED, "stops a jump attack")
	var sweep := _result(T.SWEEP, false, false)
	_check(sweep[0] != BLOCKED and sweep[1] == &"low", "loses to a low (sweep), recorded as LOW (%s)" % [sweep])

	print("[low block]")
	_check(_result(T.LIGHT, true, false)[0] == BLOCKED, "stops a mid (jab)")
	_check(_result(T.SWEEP, true, false)[0] == BLOCKED, "stops a low (sweep)")
	var over := _result(T.OVERHAND, true, false)
	_check(over[0] != BLOCKED and over[1] == &"overhead", "loses to an overhead (overhand), recorded as OVERHEAD (%s)" % [over])
	var axe := _result(T.AXE_KICK, true, false)
	_check(axe[0] != BLOCKED and axe[1] == &"overhead", "loses to an overhead (axe kick)")
	var jump := _result(T.JUMP_KICK, true, true)
	_check(jump[0] != BLOCKED and jump[1] == &"overhead", "loses to a jump attack (thrown in the air)")

	print("[data]")
	var overheads := []
	for t in T.values():
		if t != T.NONE and CombatData.get_attack(t).overhead:
			overheads.append(CombatData.get_attack(t).id)
	_check(overheads.size() == 4 and not CombatData.get_attack(T.SWEEP).overhead,
		"overheads: overhand, axe kick, flying axe kick, double-hand hammer (%s)" % [overheads])
	for t in T.values():
		if t != T.NONE and CombatData.get_attack(t).overhead and CombatData.get_attack(t).low:
			_check(false, "%s is both low and overhead" % CombatData.get_attack(t).id)

	print("RESULT: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)
