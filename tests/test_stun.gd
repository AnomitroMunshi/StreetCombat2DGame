extends SceneTree
## Stun (dizzy): every stun move in both facing directions, the dizzy state
## (cannot act, can be hit, drains per hit, recovers), blocked / non-stun hits,
## immunity, knockdown clearing it, and mashing to recover sooner.

var _fails: int = 0
const STUN_MOVES: Array[StringName] = [&"overhand", &"superman_punch", &"jumping_elbow", &"flying_knee_face",
	&"flying_side_kick", &"jumping_reverse_punch", &"flying_axe_kick", &"leaping_spin_backfist", &"axe_kick",
	&"jumping_spin_hook", &"leaping_roundhouse", &"cap_cartwheel", &"cap_spin_heel", &"cap_crescent", &"jkd_high_hook"]


func _check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func _pair(side: int, seed_value: int = 0) -> Array[Fighter]:
	var a := Fighter.new()
	var b := Fighter.new()
	root.add_child(a)
	root.add_child(b)
	a.position = Vector2(640.0 - side * 40.0, 560.0)
	b.position = Vector2(640.0 + side * 40.0, 560.0)
	a.ground_y = 560.0
	b.ground_y = 560.0
	a.opponent = b
	b.opponent = a
	a.face_opponent()
	b.face_opponent()
	b.set("_rng", RandomNumberGenerator.new())
	(b.get("_rng") as RandomNumberGenerator).seed = seed_value
	return [a, b]


func _free(p: Array[Fighter]) -> void:
	for f in p:
		f.queue_free()


## Hits b with `move` (cleanly, while b is standing) until a seed gives a hit
## that does not knock down (blowback is random). Returns the pair or [].
func _stunned_pair(move: StringName, side: int) -> Array[Fighter]:
	for k in 12:
		var p := _pair(side, 100 + k)
		var r := p[1].receive_hit(CombatData.get_attack(CombatData.type_for_id(move)), p[0], 1)
		if r == CombatData.HitResult.HIT and p[1].state == Fighter.State.HITSTUN:
			return p
		_free(p)
	return []


func _initialize() -> void:
	print("[every stun move, both directions]")
	for move in STUN_MOVES:
		var at := CombatData.get_attack(CombatData.type_for_id(move))
		var results := []
		for side in [1, -1]:
			var p := _stunned_pair(move, side)
			if p.is_empty():
				_check(false, "%s: could not land a clean standing hit" % move)
				continue
			var b := p[1]
			var signals := [0]
			b.dizzied.connect(func(_f: Fighter) -> void: signals[0] += 1)
			var dizzy_ticks := 0
			var acted := false
			var recovered := false
			for t in 260:
				var i := CombatData.Intent.new()
				i.attack = CombatData.AttackType.LIGHT
				if b.state == Fighter.State.DIZZY:
					dizzy_ticks += 1
					b.push_intent(i)  # the AI-style intent: no mashing for a direct attack
				b.tick()
				if b.state == Fighter.State.ATTACK and dizzy_ticks > 0 and not recovered:
					acted = true
				if dizzy_ticks > 0 and b.state == Fighter.State.IDLE and not recovered:
					recovered = true
			results.append(dizzy_ticks)
			var minimum: int = {&"jkd_high_hook": 50, &"cap_spin_heel": 40, &"cap_crescent": 35}.get(move, 60)
			_check(at.stun >= minimum and at.stun <= 120, "%s uses its bounded stun duration (%d ticks)" % [move, at.stun])
			_check(dizzy_ticks > 0 and recovered and not acted,
				"%s facing %d: dizzy after the hit reaction, helpless, then recovers (%d ticks)" % [move, side, dizzy_ticks])
			_free(p)
		_check(results.size() == 2 and results[0] == results[1], "%s: same either way (%s)" % [move, results])

	print("[dizzy rules]")
	var over := CombatData.get_attack(CombatData.AttackType.OVERHAND)
	var jab := CombatData.get_attack(CombatData.AttackType.LIGHT)
	var p := _stunned_pair(&"overhand", 1)
	var a := p[0]
	var b := p[1]
	for t in 40:
		b.tick()
	_check(b.state == Fighter.State.DIZZY, "overhand: dizzy once the reaction ends (%s)" % b.get_state_name())
	var left := b.dizzy_left
	_check(b.receive_hit(jab, a, 1) == CombatData.HitResult.HIT, "a dizzy fighter can be hit (no guard)")
	_check(b.dizzy_left == maxi(left - CombatData.DIZZY_HIT_DRAIN, 0), "each hit drains the stun (%d -> %d)" % [left, b.dizzy_left])
	for t in 30:
		b.tick()
	_check(b.state == Fighter.State.DIZZY, "after that hit's reaction it is dizzy again (%s)" % b.get_state_name())
	_check(b.receive_hit(over, a, 1) == CombatData.HitResult.HIT and b.dizzy_left < left, "a stun move on a dizzy fighter never re-stuns")
	b.call("_enter_state", Fighter.State.KNOCKDOWN)
	_check(b.dizzy_left == 0, "a knockdown clears the stun")
	_free(p)

	p = _stunned_pair(&"overhand", 1)
	b = p[1]
	while b.state != Fighter.State.IDLE:
		b.tick()
	_check(b.dizzy_immunity > 0, "recovering grants stun immunity (%d)" % b.dizzy_immunity)
	b.receive_hit(over, p[0], 1)
	_check(b.dizzy_left == 0, "a stun move during the immunity does not stun")
	_free(p)

	p = _pair(1)
	b = p[1]
	b.block_held = true
	b.call("_enter_state", Fighter.State.BLOCK)
	for t in 4:
		b.state_frame += 1
	_check(b.receive_hit(over, p[0], 1) == CombatData.HitResult.BLOCKED and b.dizzy_left == 0, "a blocked stun move never stuns")
	_free(p)

	p = _pair(1)
	p[1].receive_hit(jab, p[0], 1)
	_check(p[1].dizzy_left == 0, "a move without stun never stuns")
	_free(p)

	print("[mashing]")
	var lasts := []
	for mash in [false, true]:
		p = _stunned_pair(&"axe_kick", 1)
		b = p[1]
		var n := 0
		for t in 300:
			if b.state == Fighter.State.DIZZY:
				n += 1
				if mash:
					var i := CombatData.Intent.new()
					i.slot = &"light"
					b.push_intent(i)
			b.tick()
		lasts.append(n)
		_free(p)
	_check(lasts[1] < lasts[0] and lasts[1] >= CombatData.DIZZY_RECOVER_FRAMES,
		"mashing shortens the stun but keeps the shake-off (%d -> %d ticks)" % lasts)

	print("RESULT: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(_fails)
