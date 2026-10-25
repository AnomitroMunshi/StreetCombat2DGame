extends SceneTree
## Martial-art styles: registry and validation, the legality gate (player
## slots, AI intents, combos, air attacks), Boxing vs Taekwondo differences,
## every new move in both facing directions, and AI rivals of each style never
## starting a move outside their style.

var _fails: int = 0
const KICKS: Array = [CombatData.AttackType.KICK, CombatData.AttackType.FRONT_KICK, CombatData.AttackType.HIGH_KICK,
	CombatData.AttackType.SWEEP, CombatData.AttackType.BACK_KICK, CombatData.AttackType.JUMP_KICK,
	CombatData.AttackType.AXE_KICK, CombatData.AttackType.SPIN_HOOK_KICK, CombatData.AttackType.JUMP_ROUNDHOUSE,
	CombatData.AttackType.JUMP_SPIN_KICK]
const BOXING_ONLY: Array = [&"lead_hook", &"rear_hook", &"body_hook", &"overhand", &"slip_counter", &"uppercut"]


func _check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func _pair(style_a: MartialArtStyle, gap: float = 80.0, side: int = 1) -> Array[Fighter]:
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
	a.set_style(style_a)
	return [a, b]


func _slot(slot: StringName) -> CombatData.Intent:
	var i := CombatData.Intent.new()
	i.slot = slot
	return i


func _attack(t: CombatData.AttackType) -> CombatData.Intent:
	var i := CombatData.Intent.new()
	i.attack = t
	return i


func _initialize() -> void:
	var boxing := StyleRegistry.by_id(&"boxing")
	var tkd := StyleRegistry.by_id(&"taekwondo")

	print("[registry]")
	_check(boxing != null and tkd != null, "boxing and taekwondo are registered")
	_check(StyleRegistry.rejected().is_empty(), "no style file rejected (%s)" % [StyleRegistry.rejected()])
	var ids := {}
	for s in StyleRegistry.all():
		ids[s.id] = true
		_check(s.validate().is_empty(), "%s validates" % s.id)
	_check(ids.size() == StyleRegistry.count(), "style ids are unique")
	var bad := MartialArtStyle.new()
	bad.id = &"broken"
	bad.display_name = "Broken"
	bad.input_map = {&"light": &"no_such_move", &"kick": &"jump_kick"}
	bad.chains = {&"jab": [&"cross"]}
	var errs := bad.validate()
	_check(errs.size() >= 3, "malformed style data is reported (%d problems: %s)" % [errs.size(), ", ".join(errs)])

	print("[boxing cannot kick]")
	var any_kick := false
	for m in boxing.moves():
		if CombatData.type_for_id(m) in KICKS:
			any_kick = true
	_check(not any_kick, "no kick or sweep anywhere in the boxing moveset (%s)" % [boxing.moves()])
	var slots_ok := true
	for slot in MartialArtStyle.SLOTS:
		for air in [false, true]:
			if boxing.resolve(slot, air) in KICKS:
				slots_ok = false
	_check(slots_ok, "every button, on the ground and in the air, gives a boxer a punch (or nothing)")
	_check(boxing.resolve(&"kick", false) == CombatData.AttackType.BODY_HOOK, "boxing L = body hook")
	var p := _pair(boxing)
	var a: Fighter = p[0]
	a.push_intent(_attack(CombatData.AttackType.KICK))
	a.tick()
	_check(a.state != Fighter.State.ATTACK and a.rejected_attacks == 1, "an AI/legacy kick intent is refused for a boxer")
	a.push_intent(_slot(&"down_kick"))
	a.tick()
	_check(a.current_attack != null and a.current_attack.type == CombatData.AttackType.BODY_HOOK, "S+L for a boxer is a body hook, never a sweep")

	print("[taekwondo has no boxing combos]")
	var shared := 0
	for m in BOXING_ONLY:
		if m in tkd.moves():
			shared += 1
	_check(shared == 0, "no hooks, overhand, slip counter or uppercut in taekwondo")
	_check(not tkd.can_chain(CombatData.AttackType.LIGHT, CombatData.AttackType.LIGHT) and boxing.can_chain(CombatData.AttackType.LIGHT, CombatData.AttackType.LIGHT),
		"jab-jab is a boxing chain, not a taekwondo one")
	var only_box := boxing.moves().filter(func(m: StringName) -> bool: return not m in tkd.moves())
	var only_tkd := tkd.moves().filter(func(m: StringName) -> bool: return not m in boxing.moves())
	_check(only_box.size() >= 6 and only_tkd.size() >= 7, "movesets genuinely differ (boxing-only %d, taekwondo-only %d)" % [only_box.size(), only_tkd.size()])

	print("[air attacks follow the style]")
	for case in [[boxing, &"kick", CombatData.AttackType.JUMP_PUNCH], [tkd, &"kick", CombatData.AttackType.JUMP_ROUNDHOUSE],
			[tkd, &"lead", CombatData.AttackType.JUMP_SPIN_KICK], [tkd, &"light", CombatData.AttackType.JUMP_PUNCH]]:
		p = _pair(case[0], 300.0)
		a = p[0]
		a.push_intent(_slot(&"none"))
		var j := CombatData.Intent.new()
		j.jump = true
		a.push_intent(j)
		var started := CombatData.AttackType.NONE
		for t in 40:
			if t == 8:
				a.push_intent(_slot(case[1]))
			a.tick()
			if a.state == Fighter.State.ATTACK and started == CombatData.AttackType.NONE:
				started = a.current_attack.type
		_check(started == case[2], "%s in the air, %s -> %s (%s)" % [case[0].id, case[1], CombatData.attack_name(case[2]), CombatData.attack_name(started)])

	print("[combos follow the style graph]")
	for case in [[boxing, CombatData.AttackType.LIGHT, &"kick", true], [tkd, CombatData.AttackType.KICK, &"up_kick", true],
			[tkd, CombatData.AttackType.LIGHT, &"light", false]]:
		p = _pair(case[0], 80.0)
		a = p[0]
		var b: Fighter = p[1]
		a.push_intent(_attack(case[1]))
		var chained := false
		for t in 40:
			a.tick()
			b.tick()
			if a.is_hitbox_active() and a.get_hitbox_world().intersects(b.get_hurtbox_world()):
				a.confirm_hit(b.receive_hit(a.current_attack, a, a.combo_step))
			if t == 8:
				a.push_intent(_slot(case[2]))
			if a.state == Fighter.State.ATTACK and a.combo_step == 2:
				chained = true
		_check(chained == case[3], "%s: %s then %s %s" % [case[0].id, CombatData.attack_name(case[1]), case[2], "chains" if case[3] else "does not chain"])

	print("[new moves: one hit, both directions]")
	for t_new in [CombatData.AttackType.LEAD_HOOK, CombatData.AttackType.REAR_HOOK, CombatData.AttackType.BODY_HOOK,
			CombatData.AttackType.OVERHAND, CombatData.AttackType.SLIP_COUNTER, CombatData.AttackType.AXE_KICK,
			CombatData.AttackType.SPIN_HOOK_KICK]:
		var res: Array = []
		for side in [1, -1]:
			p = _pair(null, 80.0, side)
			a = p[0]
			var b: Fighter = p[1]
			a.push_intent(_attack(t_new))
			var hits := 0
			for t in 50:
				a.tick()
				b.tick()
				if a.is_hitbox_active() and a.get_hitbox_world().intersects(b.get_hurtbox_world()):
					if b.receive_hit(a.current_attack, a, a.combo_step) == CombatData.HitResult.HIT:
						hits += 1
					a.confirm_hit(CombatData.HitResult.HIT)
			res.append([hits, b.health])
		_check(res[0][0] == 1 and res[0] == res[1], "%s hits exactly once, same result facing either way (%s)" % [CombatData.attack_name(t_new), res])

	print("[slip counter]")
	p = _pair(null, 80.0)
	a = p[0]
	var opp: Fighter = p[1]
	a.push_intent(_attack(CombatData.AttackType.SLIP_COUNTER))
	a.tick()
	a.tick()
	var high_jab := CombatData.get_attack(CombatData.AttackType.LIGHT)
	_check(a.receive_hit(high_jab, opp, 1) == CombatData.HitResult.WHIFF and a.health == 100, "a head-height jab whiffs during the slip")
	var low := CombatData.get_attack(CombatData.AttackType.SWEEP)
	_check(a.receive_hit(low, opp, 1) != CombatData.HitResult.WHIFF, "a low attack still lands during the slip")

	print("[style finishers]")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for st in [boxing, tkd]:
		p = _pair(st, 80.0)
		a = p[0]
		var v: Fighter = p[1]
		var own := {}
		for fid in st.finishers:
			own[FinisherDirector.kind_for_id(fid)] = true
		var picked := {}
		var foreign := 0
		var repeats := 0
		var last := -1
		for i in 200:
			var k := FinisherDirector.choose(a, v, CombatData.get_attack(CombatData.AttackType.LIGHT), rng)
			picked[k] = true
			if not own.has(k):
				foreign += 1
			if k == last:
				repeats += 1
			last = k
		_check(foreign == 0 and picked.size() == 2 and repeats == 0,
			"%s on open floor: only its own two finishers, alternating (%s)" % [st.id, picked.keys().map(func(k: int) -> String: return FinisherDirector.DISPLAY_NAMES[k])])
	p = _pair(boxing, 80.0)
	a = p[0]
	var vic: Fighter = p[1]
	vic.airborne = true
	var air_n := 0
	for i in 100:
		if FinisherDirector.choose(a, vic, null, rng) == FinisherDirector.Kind.AIR_SMASH:
			air_n += 1
	_check(air_n > 40, "airborne kill: Air Smash still has priority for a styled attacker (%d/100)" % air_n)
	vic.airborne = false
	vic.position.x = Fighter.ARENA_MAX_X - 60.0
	a.position.x = vic.position.x - 80.0
	var wall_n := 0
	for i in 100:
		if FinisherDirector.choose(a, vic, null, rng) == FinisherDirector.Kind.WALL_CRUSH:
			wall_n += 1
	_check(wall_n > 30, "near the wall: Wall Crush still has priority (%d/100)" % wall_n)

	print("[boxing power]")
	for case in [[CombatData.AttackType.REAR_HOOK, 40.0], [CombatData.AttackType.OVERHAND, 50.0], [CombatData.AttackType.BODY_HOOK, 30.0]]:
		p = _pair(null, 80.0)
		a = p[0]
		var d: Fighter = p[1]
		var x0 := d.position.x
		d.receive_hit(CombatData.get_attack(case[0]), a, 1)
		for t in 40:
			d.tick()
		_check(d.position.x - x0 >= case[1], "%s drives the opponent back %.0f px (>= %.0f)" % [CombatData.attack_name(case[0]), d.position.x - x0, case[1]])

	print("[focus]")
	var jab_at := CombatData.get_attack(CombatData.AttackType.LIGHT)
	var cross_at := CombatData.get_attack(CombatData.AttackType.HEAVY)
	var kick_at := CombatData.get_attack(CombatData.AttackType.KICK)
	_check(CombatData.focus_for_hit(jab_at, false) == 5.0 and CombatData.focus_for_hit(cross_at, false) == 10.0
		and CombatData.focus_for_hit(kick_at, false) == 8.0 and CombatData.focus_for_hit(jab_at, true) == 15.0,
		"focus per hit: light 5, heavy 10, kick 8, counter 15")
	_check(CombatData.focus_for_hit(CombatData.get_attack(CombatData.AttackType.GAZELLE_HOOK), false) == 0.0, "signature hits earn no focus")
	p = _pair(boxing, 80.0)
	a = p[0]
	_check(a.focus == 0.0, "focus starts at 0")
	for i in 40:
		a.add_focus(10.0)
	_check(a.focus == CombatData.FOCUS_MAX, "focus never exceeds 100 (%.0f)" % a.focus)
	a.focus = 0.0
	a.add_block_focus()
	a.add_block_focus()
	_check(a.focus == CombatData.FOCUS_BLOCK, "two blocks in quick succession pay once (no block farming)")
	for t in CombatData.FOCUS_BLOCK_COOLDOWN + 1:
		a.tick()
	a.add_block_focus()
	_check(a.focus == CombatData.FOCUS_BLOCK * 2.0, "blocks pay again after the cooldown")

	print("[signatures]")
	for case in [[boxing, CombatData.AttackType.GAZELLE_HOOK], [tkd, CombatData.AttackType.TORNADO_540]]:
		p = _pair(case[0], 300.0)
		a = p[0]
		a.focus = 60.0
		var sig_i := CombatData.Intent.new()
		sig_i.signature = true
		a.push_intent(sig_i)
		a.tick()
		_check(a.state != Fighter.State.ATTACK and a.focus == 60.0, "%s: F without full focus does nothing and costs nothing" % case[0].id)
		a.focus = CombatData.FOCUS_MAX
		a.push_intent(sig_i)
		a.tick()
		_check(a.current_attack != null and a.current_attack.type == case[1] and a.focus == 0.0,
			"%s: F at full focus starts %s and spends 100" % [case[0].id, CombatData.attack_name(case[1])])
		var left_ground := false
		for t in 80:
			a.tick()
			left_ground = left_ground or a.airborne
		_check(a.focus == 0.0 and a.state == Fighter.State.IDLE, "%s: a whiffed signature is not refunded" % case[0].id)
		if case[1] == CombatData.AttackType.TORNADO_540:
			_check(left_ground, "540 tornado kick leaves the ground and lands")
	p = _pair(boxing, 80.0)
	a = p[0]
	a.push_intent(_attack(CombatData.AttackType.TORNADO_540))
	a.tick()
	_check(a.state != Fighter.State.ATTACK and a.rejected_attacks == 1, "a boxer cannot do another style's signature")
	for sig_t in [CombatData.AttackType.GAZELLE_HOOK, CombatData.AttackType.TORNADO_540]:
		var res: Array = []
		for side in [1, -1]:
			p = _pair(null, 90.0, side)
			a = p[0]
			var b2: Fighter = p[1]
			a.push_intent(_attack(sig_t))
			var hits := 0
			var blocked := false
			for t in 60:
				a.tick()
				b2.tick()
				if a.is_hitbox_active() and a.get_hitbox_world().intersects(b2.get_hurtbox_world()):
					if b2.receive_hit(a.current_attack, a, a.combo_step) == CombatData.HitResult.HIT:
						hits += 1
					a.confirm_hit(CombatData.HitResult.HIT)
			res.append([hits, b2.health, b2.state == Fighter.State.KNOCKDOWN])
		_check(res[0][0] == 1 and res[0] == res[1] and res[0][2], "%s lands once, knocks down, same both ways (%s)" % [CombatData.attack_name(sig_t), res])
	p = _pair(boxing, 90.0)
	a = p[0]
	var guard_b: Fighter = p[1]
	var hold_i := CombatData.Intent.new()
	hold_i.block = true
	for t in 4:
		guard_b.push_intent(hold_i)
		guard_b.tick()
	a.focus = CombatData.FOCUS_MAX
	var fsig := CombatData.Intent.new()
	fsig.signature = true
	a.push_intent(fsig)
	var sig_res := CombatData.HitResult.WHIFF
	for t in 40:
		guard_b.push_intent(hold_i)
		a.tick()
		guard_b.tick()
		if a.is_hitbox_active() and a.get_hitbox_world().intersects(guard_b.get_hurtbox_world()):
			sig_res = guard_b.receive_hit(a.current_attack, a, a.combo_step)
			a.confirm_hit(sig_res)
	_check(sig_res in [CombatData.HitResult.BLOCKED, CombatData.HitResult.GUARD_BREAK] and guard_b.health == 100,
		"a signature can be blocked (%s, no damage)" % CombatData.HitResult.keys()[sig_res])

	# AI rivals of each style never start an illegal move.
	print("[AI rivals stay in style]")
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	for rival_id in [&"boxing", &"taekwondo"]:
		var pl: Fighter = main.get_node("Player")
		var en: Fighter = main.get_node("Enemy")
		main.call("select_style", &"taekwondo" if rival_id == &"boxing" else &"boxing")
		en.set_style(StyleRegistry.by_id(rival_id))
		main.call("start_match", true)
		var seen := {}
		var illegal := 0
		for t in 1500:
			await physics_frame
			pl.health = 100
			en.health = 100
			if en.state == Fighter.State.ATTACK and en.current_attack != null:
				seen[en.current_attack.display_name] = true
				if not en.style.allows(en.current_attack.type):
					illegal += 1
		_check(illegal == 0 and en.rejected_attacks == 0, "%s rival: %d different moves used, none illegal, none refused (%s)" % [rival_id, seen.size(), seen.keys()])
		_check(seen.size() >= 4, "%s rival uses a varied moveset" % rival_id)
		main.queue_free()
		main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
		root.add_child(main)
		current_scene = main
		await process_frame

	print("RESULT: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)
