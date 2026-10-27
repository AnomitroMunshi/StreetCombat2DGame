extends SceneTree
## Taekwondo L: the Double Kick. One press, two kicks with alternating legs:
## a low roundhouse (5) then a mid roundhouse (9), separate 3-tick active
## windows, the second kick regardless of the first's result, nothing left
## over when the attacker is interrupted; both directions.

var _fails: int = 0


func _check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func _pair(gap: float, side: int) -> Array[Fighter]:
	var a := Fighter.new()
	var b := Fighter.new()
	root.add_child(a)
	root.add_child(b)
	a.position = Vector2(640.0 - side * gap * 0.5, 560.0)
	b.position = Vector2(640.0 + side * gap * 0.5, 560.0)
	a.ground_y = 560.0
	b.ground_y = 560.0
	a.opponent = b
	b.opponent = a
	a.face_opponent()
	b.face_opponent()
	a.set_style(StyleRegistry.by_id(&"taekwondo"))
	b.set_style(StyleRegistry.by_id(&"karate"))
	return [a, b]


func _free(p: Array[Fighter]) -> void:
	for f in p:
		f.queue_free()


func _press_l(a: Fighter) -> void:
	var i := CombatData.Intent.new()
	i.slot = &"technique"
	a.push_intent(i)


## Runs `ticks` ticks of attacker vs target with hit detection. `hold` is a
## per-tick target intent (block / crouch); `each` is called before each tick.
## Returns {"windows": {id: [first, last]}, "results": [[id, result, damage]]}.
func _run(a: Fighter, b: Fighter, ticks: int, block: bool = false, crouch: bool = false, each: Callable = Callable()) -> Dictionary:
	var windows := {}
	var results: Array = []
	for t in ticks:
		if each.is_valid():
			each.call(t)
		var hold := CombatData.Intent.new()
		hold.block = block
		hold.crouch = crouch
		b.push_intent(hold)
		a.tick()
		b.tick()
		if a.state == Fighter.State.ATTACK and a.current_attack != null and a.is_hitbox_active():
			var id := a.current_attack.id
			if not windows.has(id):
				windows[id] = [t, t]
			windows[id][1] = t
			if not a.swing_has_hit and a.get_hitbox_world().intersects(b.get_hurtbox_world()):
				var before := b.health
				var r := b.receive_hit(a.current_attack, a, a.combo_step)
				a.confirm_hit(r)
				results.append([id, r, before - b.health])
	return {"windows": windows, "results": results}


func _initialize() -> void:
	print("[data]")
	var dk := CombatData.get_attack(CombatData.AttackType.DOUBLE_KICK)
	var lo := CombatData.get_attack(CombatData.AttackType.DOUBLE_KICK_LOW)
	var mid := CombatData.get_attack(CombatData.AttackType.DOUBLE_KICK_MID)
	_check(StyleRegistry.by_id(&"taekwondo").resolve(&"technique", false) == CombatData.AttackType.DOUBLE_KICK, "Taekwondo L is the Double Kick")
	_check(lo.startup == 9 and lo.active == 3 and lo.damage == 5 and lo.low, "first kick: startup 9, active 3, 5 damage, low")
	_check(mid.active == 3 and mid.recovery == 20 and mid.damage == 9 and not mid.low, "second kick: active 3, recovery 20, 9 damage, mid")
	_check(dk.sequence == [&"double_kick_low", &"double_kick_mid"], "one technique, two strikes")
	_check(CombatData.get_attack(CombatData.AttackType.LOW_ROUNDHOUSE).damage == 9
		and CombatData.get_attack(CombatData.AttackType.BODY_ROUNDHOUSE).damage == 12, "shared low / body roundhouse damage unchanged")
	for sid in [&"muay_thai", &"kickboxing", &"karate"]:
		_check(not StyleRegistry.by_id(sid).allows(CombatData.AttackType.DOUBLE_KICK_LOW), "%s cannot use the double kick strikes" % sid)
	_check(StyleRegistry.by_id(&"taekwondo").allows(CombatData.AttackType.DOUBLE_KICK_MID), "its strikes are legal for Taekwondo")

	for side in [1, -1]:
		var dir := "facing right" if side == 1 else "facing left"
		print("[%s]" % dir)
		# Fresh stationary target in range.
		var p := _pair(80.0, side)
		_press_l(p[0])
		var res := _run(p[0], p[1], 60)
		var w: Dictionary = res["windows"]
		var got: Array = res["results"]
		_check(w.has(&"double_kick_low") and w.has(&"double_kick_mid"), "two separate strikes (%s)" % [w])
		_check(got.size() == 2 and got[0][2] == 5 and got[1][2] == 9, "exactly two hits: 5 then 9 (%s)" % [got])
		_check(p[1].health == p[1].max_health - 14, "14 damage in total")
		_check(p[1].state != Fighter.State.KNOCKDOWN, "two kicks alone never knock down")
		_check(p[0].state != Fighter.State.ATTACK, "back to neutral after the recovery")
		_free(p)

		# Pressing L again during the move neither restarts it nor adds hits.
		p = _pair(80.0, side)
		_press_l(p[0])
		var a: Fighter = p[0]
		res = _run(a, p[1], 40, false, false, func(t: int) -> void:
			if t in [5, 15, 25]:
				_press_l(a))
		var lows := 0
		for r in res["results"]:
			if r[0] == &"double_kick_low":
				lows += 1
		_check(lows == 1 and (res["results"] as Array).size() == 2, "repeat presses mid-move: no restart (%s)" % [res["results"]])
		_free(p)

		# First kick whiffs: the second still comes on schedule.
		p = _pair(400.0, side)
		_press_l(p[0])
		res = _run(p[0], p[1], 50)
		w = res["windows"]
		# (A kick that lands switches its hitbox off on contact, so the full
		# windows are measured on the whiff.)
		_check(w.get(&"double_kick_low", []) == [9, 11], "first active window ticks 9-11 (%s)" % [w])
		_check(w.get(&"double_kick_mid", []) == [21, 23], "first whiffs: second kick still comes, active ticks 21-23 after a 9-tick transfer")
		_free(p)

		# Standing guard: the low kick gets through and its hitstun carries
		# into the mid kick (a true two-hit combo under the existing rules).
		p = _pair(80.0, side)
		_press_l(p[0])
		res = _run(p[0], p[1], 60, true, false)
		got = res["results"]
		_check(got.size() == 2 and got[0][1] == CombatData.HitResult.HIT and got[1][1] == CombatData.HitResult.HIT,
			"standing guard: low kick beats it, mid kick follows in its hitstun (%s)" % [got])
		_free(p)
		# Against a fresh standing guard the mid kick on its own is blocked.
		for sub in [[lo, CombatData.HitResult.HIT], [mid, CombatData.HitResult.BLOCKED]]:
			p = _pair(80.0, side)
			for k in 8:
				var g := CombatData.Intent.new()
				g.block = true
				p[1].push_intent(g)
				p[1].tick()
			var r := p[1].receive_hit(sub[0], p[0], 0)
			_check(r == sub[1], "standing guard vs %s: %s" % [sub[0].display_name, CombatData.HitResult.keys()[r]])
			_free(p)

		# Low guard stops the low kick; the second still follows.
		p = _pair(80.0, side)
		_press_l(p[0])
		res = _run(p[0], p[1], 60, true, true)
		got = res["results"]
		_check(got.size() >= 1 and got[0][1] == CombatData.HitResult.BLOCKED and res["windows"].has(&"double_kick_mid"),
			"low guard: low kick blocked, mid kick still thrown (%s)" % [got])
		_free(p)

		# Interrupted at each stage: nothing more lands.
		for at in [4, 10, 15, 19]:
			p = _pair(80.0, side)
			a = p[0]
			var b: Fighter = p[1]
			_press_l(a)
			var jab := CombatData.get_attack(CombatData.AttackType.LIGHT)
			res = _run(a, b, 50, false, false, func(t: int) -> void:
				if t == at:
					a.receive_hit(jab, b, 0))
			var after := 0
			for r in res["results"]:
				after += 1
			var expected := 1 if at > 9 else 0  # the first kick lands at tick 9
			_check(after <= expected and not a.is_mid_sequence(),
				"interrupted at tick %d: no further strike (%d hits)" % [at, after])
			_free(p)

	print("RESULT: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)
