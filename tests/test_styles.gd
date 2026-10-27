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
	bad.input_map = {&"light": &"no_such_move", &"heavy": &"jump_kick", &"kick": &"jab"}
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
	_check(boxing.resolve(&"down_light", false) == CombatData.AttackType.BODY_HOOK, "boxing S+J = body hook")
	_check(boxing.resolve(&"technique", false) == CombatData.AttackType.BOB_WEAVE, "boxing L = bob and weave")
	var p := _pair(boxing)
	var a: Fighter = p[0]
	a.push_intent(_attack(CombatData.AttackType.KICK))
	a.tick()
	_check(a.state != Fighter.State.ATTACK and a.rejected_attacks == 1, "an AI/legacy kick intent is refused for a boxer")
	a.push_intent(_slot(&"down_heavy"))
	a.tick()
	_check(a.current_attack != null and a.current_attack.type == CombatData.AttackType.SLIP_COUNTER, "S+K for a boxer is a slip counter, never a low kick")

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
	for case in [[boxing, &"heavy", CombatData.AttackType.JUMP_PUNCH], [tkd, &"heavy", CombatData.AttackType.JUMP_ROUNDHOUSE],
			[tkd, &"technique", CombatData.AttackType.JUMP_SPIN_KICK], [tkd, &"light", CombatData.AttackType.JUMP_PUNCH]]:
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
	for case in [[boxing, CombatData.AttackType.LIGHT, &"down_light", true], [tkd, CombatData.AttackType.KICK, &"up_heavy", true],
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

	print("[style air and wall finishers]")
	# Each style's own contextual finisher, chosen from the ATTACKER's style
	# whatever the rival's; a repeat falls back to that style's own finishers.
	for case in [[&"karate", true, FinisherDirector.Kind.SKYLINE_VERDICT], [&"muay_thai", false, FinisherDirector.Kind.IRON_CORNER]]:
		var st := StyleRegistry.by_id(case[0])
		p = _pair(st, 80.0)
		a = p[0]
		var cv: Fighter = p[1]
		cv.set_style(StyleRegistry.by_id(&"boxing"))
		if case[1]:
			cv.airborne = true
		else:
			cv.position.x = Fighter.ARENA_MAX_X - 60.0
			a.position.x = cv.position.x - 80.0
		var own_n := 0
		var foreign := 0
		var allowed: Array = [case[2]]
		for fid in st.finishers:
			allowed.append(FinisherDirector.kind_for_id(fid))
		var back_to_back := 0
		var prev_k := -1
		for i in 100:
			var k := FinisherDirector.choose(a, cv, null, rng)
			if k == case[2]:
				own_n += 1
			if not k in allowed:
				foreign += 1
			if k == prev_k:
				back_to_back += 1
			prev_k = k
		_check(own_n > 30 and foreign == 0 and back_to_back == 0,
			"%s: its own %s, else its own finishers, never twice running (%d/100, %d foreign)" % [case[0], FinisherDirector.DISPLAY_NAMES[case[2]], own_n, foreign])
		a.queue_free()
		cv.queue_free()
	var bad_ctx := StyleRegistry.by_id(&"karate").duplicate() as MartialArtStyle
	bad_ctx.air_finisher = &"iron_corner"
	bad_ctx.wall_finisher = &"skyline_verdict"
	_check(bad_ctx.validate().size() == 2, "an air or wall finisher of the wrong kind is reported (%s)" % [bad_ctx.validate()])

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
	_check(is_equal_approx(CombatData.focus_for_hurt(12), 12.0 * CombatData.FOCUS_HURT_PER_DAMAGE), "taking a 12-damage hit pays the victim %.1f focus" % CombatData.focus_for_hurt(12))
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

	print("[all six styles]")
	_check(StyleRegistry.count() == 7, "seven styles registered (%d)" % StyleRegistry.count())
	_check(StyleRegistry.default_style().id == &"kickboxing", "kickboxing is the default all-rounder")
	var sig_ids := {}
	var fin_ids := {}
	for st in StyleRegistry.all():
		var fins_ok := st.finishers.size() == 2
		for fid in st.finishers:
			if fin_ids.has(fid):
				fins_ok = false
			fin_ids[fid] = true
		_check(fins_ok, "%s has two finishers of its own (%s)" % [st.id, st.finishers])
		_check(st.signature != &"" and not sig_ids.has(st.signature), "%s has its own signature (%s)" % [st.id, st.signature])
		sig_ids[st.signature] = true
		# The signature starts and spends Focus.
		p = _pair(st, 300.0)
		a = p[0]
		a.focus = CombatData.FOCUS_MAX
		var fi := CombatData.Intent.new()
		fi.signature = true
		a.push_intent(fi)
		a.tick()
		_check(a.state == Fighter.State.ATTACK and a.focus == 0.0 and a.in_signature, "%s: signature starts on F at full focus" % st.id)
	_check(not StyleRegistry.by_id(&"kung_fu").allows(CombatData.AttackType.HIGH_KICK) and not StyleRegistry.by_id(&"karate").allows(CombatData.AttackType.SWEEP)
		and not StyleRegistry.by_id(&"kickboxing").allows(CombatData.AttackType.ELBOW) and StyleRegistry.by_id(&"muay_thai").allows(CombatData.AttackType.ELBOW),
		"movesets stay distinct (no high kick in kung fu, no sweep in karate, elbows only in muay thai)")

	print("[sequences, multi-hit, deflection]")
	# Breaker Combination: four distinct strikes land; mid-sequence hits never knock down.
	p = _pair(StyleRegistry.by_id(&"kickboxing"), 75.0)
	a = p[0]
	var tgt: Fighter = p[1]
	a.focus = CombatData.FOCUS_MAX
	var fsg := CombatData.Intent.new()
	fsg.signature = true
	a.push_intent(fsg)
	var landed: Array = []
	var down_early := false
	for t in 120:
		a.tick()
		tgt.tick()
		if a.is_hitbox_active() and a.get_hitbox_world().intersects(tgt.get_hurtbox_world()):
			var r := tgt.receive_hit(a.current_attack, a, a.combo_step)
			a.confirm_hit(r)
			if r == CombatData.HitResult.HIT:
				landed.append(a.current_attack.display_name)
				if tgt.state == Fighter.State.KNOCKDOWN and landed.size() < 4:
					down_early = true
	_check(landed == ["Jab", "Cross", "Low Kick", "High Kick"], "Breaker Combination: jab, cross, low kick, high kick all land (%s)" % [landed])
	_check(not down_early, "no knockdown before the final strike of the sequence")
	# Interrupted: hit mid-sequence and the rest is dropped.
	p = _pair(StyleRegistry.by_id(&"kickboxing"), 75.0)
	a = p[0]
	a.focus = CombatData.FOCUS_MAX
	a.push_intent(fsg)
	for t in 4:
		a.tick()
	a.receive_hit(CombatData.get_attack(CombatData.AttackType.LIGHT), p[1], 1)
	for t in 40:
		a.tick()
	_check(not a.is_mid_sequence() and not a.in_signature and a.state != Fighter.State.ATTACK, "a signature sequence is interrupted by a hit")
	# Chain palms land several times in one move.
	p = _pair(null, 75.0)
	a = p[0]
	var cp_t: Fighter = p[1]
	a.push_intent(_attack(CombatData.AttackType.CHAIN_PALMS))
	var cp_hits := 0
	for t in 40:
		a.tick()
		cp_t.tick()
		if a.is_hitbox_active() and a.get_hitbox_world().intersects(cp_t.get_hurtbox_world()):
			if cp_t.receive_hit(a.current_attack, a, a.combo_step) == CombatData.HitResult.HIT:
				cp_hits += 1
			a.confirm_hit(CombatData.HitResult.HIT)
	_check(cp_hits == 3, "chain palms hit three times in one move (%d)" % cp_hits)
	# Deflection counter turns aside a body-height strike; a low one still lands.
	p = _pair(null, 80.0)
	a = p[0]
	var att: Fighter = p[1]
	a.push_intent(_attack(CombatData.AttackType.DEFLECT_COUNTER))
	a.tick()
	a.tick()
	_check(a.receive_hit(CombatData.get_attack(CombatData.AttackType.BODY_HOOK), att, 1) == CombatData.HitResult.WHIFF, "deflection counter turns aside a body hook")
	_check(a.receive_hit(CombatData.get_attack(CombatData.AttackType.LOW_SIDE_KICK), att, 1) != CombatData.HitResult.WHIFF, "...but not a low kick")
	# Low kicks must be blocked low.
	p = _pair(null, 80.0)
	a = p[0]
	var lb: Fighter = p[1]
	var hold_hi := CombatData.Intent.new()
	hold_hi.block = true
	for t in 4:
		lb.push_intent(hold_hi)
		lb.tick()
	_check(lb.receive_hit(CombatData.get_attack(CombatData.AttackType.LOW_ROUNDHOUSE), a, 1) == CombatData.HitResult.HIT, "a standing guard does not stop a low kick")

	print("[new moves: one hit, both directions]")
	for t_new in [CombatData.AttackType.ELBOW, CombatData.AttackType.KNEE, CombatData.AttackType.LOW_ROUNDHOUSE,
			CombatData.AttackType.BODY_ROUNDHOUSE, CombatData.AttackType.REVERSE_PUNCH, CombatData.AttackType.KNIFE_HAND,
			CombatData.AttackType.RISING_PUNCH, CombatData.AttackType.SPIN_COUNTER_KICK, CombatData.AttackType.STRAIGHT_PALM,
			CombatData.AttackType.DOUBLE_PALM, CombatData.AttackType.LOW_SIDE_KICK, CombatData.AttackType.RISING_PALM,
			CombatData.AttackType.DEFLECT_COUNTER, CombatData.AttackType.PERFECT_GYAKU, CombatData.AttackType.FLYING_KNEE]:
		var res2: Array = []
		for side in [1, -1]:
			p = _pair(null, 80.0, side)
			a = p[0]
			var b3: Fighter = p[1]
			a.push_intent(_attack(t_new))
			var hits2 := 0
			for t in 60:
				a.tick()
				b3.tick()
				if a.is_hitbox_active() and a.get_hitbox_world().intersects(b3.get_hurtbox_world()):
					if b3.receive_hit(a.current_attack, a, a.combo_step) == CombatData.HitResult.HIT:
						hits2 += 1
					a.confirm_hit(CombatData.HitResult.HIT)
			res2.append([hits2, b3.health])
		_check(res2[0][0] == 1 and res2[0] == res2[1], "%s hits exactly once, same both ways (%s)" % [CombatData.attack_name(t_new), res2])

	print("[finisher poses and wall entries]")
	var fs2: PackedScene = load("res://scenes/fighter.tscn")
	var probe: Fighter = fs2.instantiate()
	root.add_child(probe)
	await process_frame
	var library: Dictionary = (probe.get_node("Visual") as FighterVisual).get("_pose_library")
	var missing: Array = []
	for st in StyleRegistry.all() + [null]:
		for k in FinisherDirector.Kind.values():
			p = _pair(st, 90.0)
			var dir := FinisherDirector.new(k, p[0], p[1])
			for beat in dir.get("_beats"):
				for key in ["atk", "def"]:
					if beat.has(key) and not library.has(beat[key]):
						missing.append("%s/%s:%s" % [st.id if st != null else "none", FinisherDirector.DISPLAY_NAMES[k], beat[key]])
	_check(missing.is_empty(), "every finisher pose (all styles, incl. wall entries) exists in the pose library (%s)" % [missing.slice(0, 5)])
	probe.queue_free()
	# Wall Crush as a boxer: punches only, no knee hop, ends slumped.
	p = _pair(boxing, 90.0)
	a = p[0]
	var wv: Fighter = p[1]
	wv.position.x = Fighter.ARENA_MAX_X - 100.0
	a.position.x = wv.position.x - 90.0
	wv.health = 0
	var wd := FinisherDirector.new(FinisherDirector.Kind.WALL_CRUSH, a, wv)
	var kicked := false
	var hopped := false
	var wt := 0
	while not wd.done and wt < 400:
		wd.tick()
		a.tick()
		wv.tick()
		hopped = hopped or a.airborne
		kicked = kicked or String(a.script_pose).contains("knee") or String(a.script_pose).contains("kick")
		wt += 1
	_check(wd.done and not kicked and not hopped and wv.state == Fighter.State.KO, "Wall Crush as a boxer: hooks and an overhand, no knee or kick, ends in the slump")

	print("[palm barrage and parried signatures]")
	p = _pair(StyleRegistry.by_id(&"kung_fu"), 75.0)
	a = p[0]
	var pb: Fighter = p[1]
	a.focus = CombatData.FOCUS_MAX
	var fpb := CombatData.Intent.new()
	fpb.signature = true
	a.push_intent(fpb)
	var pb_hits: Array = []
	for t in 120:
		a.tick()
		pb.tick()
		if a.is_hitbox_active() and a.get_hitbox_world().intersects(pb.get_hurtbox_world()):
			var r2 := pb.receive_hit(a.current_attack, a, a.combo_step)
			a.confirm_hit(r2)
			if r2 == CombatData.HitResult.HIT:
				pb_hits.append(a.current_attack.display_name)
	_check(pb_hits == ["Straight Palm", "Straight Palm", "Straight Palm", "Double Palm"], "Flowing Palm Barrage: three palms then the double palm (%s)" % [pb_hits])
	for sig_style in [&"taekwondo", &"karate"]:
		p = _pair(StyleRegistry.by_id(sig_style), 90.0)
		a = p[0]
		var par: Fighter = p[1]
		a.focus = CombatData.FOCUS_MAX
		a.push_intent(fpb)
		var sig_a := CombatData.get_attack(CombatData.type_for_id(StyleRegistry.by_id(sig_style).signature))
		var res3 := CombatData.HitResult.WHIFF
		for t in 60:
			var pi := CombatData.Intent.new()
			# Press the guard two ticks before the strike lands (inside the window).
			if a.state == Fighter.State.ATTACK and a.state_frame >= sig_a.startup - 2:
				pi.block = true
				pi.parry = par.state != Fighter.State.BLOCK
			par.push_intent(pi)
			a.tick()
			par.tick()
			if a.is_hitbox_active() and a.get_hitbox_world().intersects(par.get_hurtbox_world()):
				res3 = par.receive_hit(a.current_attack, a, a.combo_step)
				a.confirm_hit(res3)
		_check(res3 in [CombatData.HitResult.PARRIED, CombatData.HitResult.GUARD_BREAK] and par.health == 100,
			"%s signature can be parried (%s)" % [sig_style, CombatData.HitResult.keys()[res3]])

	# AI rivals of each style never start an illegal move.
	print("[AI rivals stay in style]")
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	for rival_id in [&"boxing", &"taekwondo", &"muay_thai", &"karate", &"kung_fu", &"kickboxing", &"bangla_maar"]:
		var pl: Fighter = main.get_node("Player")
		var en: Fighter = main.get_node("Enemy")
		main.call("select_style", &"taekwondo" if rival_id != &"taekwondo" else &"boxing")
		en.set_style(StyleRegistry.by_id(rival_id))
		main.call("start_match", true)
		var seen := {}
		var illegal := 0
		var swings := {}
		var last_swing := -1
		for t in 1500:
			await physics_frame
			pl.health = 100
			en.health = 100
			if en.state == Fighter.State.ATTACK and en.current_attack != null:
				seen[en.current_attack.display_name] = true
				if en.swing_id != last_swing:
					last_swing = en.swing_id
					swings[en.current_attack.id] = swings.get(en.current_attack.id, 0) + 1
				if not en.style.allows(en.current_attack.type):
					illegal += 1
		_check(illegal == 0 and en.rejected_attacks == 0, "%s rival: %d different moves used, none illegal, none refused (%s)" % [rival_id, seen.size(), seen.keys()])
		_check(seen.size() >= 4, "%s rival uses a varied moveset" % rival_id)
		# The idle player never attacks or blocks: all its Focus came from being hit.
		_check(pl.hit_counter > 0 and pl.focus > 0.0, "taking hits fills the Focus bar (%d hits taken, focus %.0f)" % [pl.hit_counter, pl.focus])
		if rival_id == &"bangla_maar":
			var total := 0
			for k in swings:
				total += swings[k]
			var pushes: int = swings.get(&"jor_dhakka", 0)
			_check(total > 10 and pushes * 5 <= total and swings.get(&"belly_bomb", 0) <= 2,
				"bangla_maar rival does not spam Jor Dhakka or the Belly Bomb (%d bashes, %d belly bombs of %d swings)" % [pushes, swings.get(&"belly_bomb", 0), total])
		main.queue_free()
		main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
		root.add_child(main)
		current_scene = main
		await process_frame

	print("[every style selectable]")
	var main2: Node = current_scene
	var sel_ok := true
	for st in StyleRegistry.all():
		main2.call("select_style", st.id)
		var pl2: Fighter = main2.get_node("Player")
		var en2: Fighter = main2.get_node("Enemy")
		if pl2.style != st or pl2.stance != st.stance or en2.style == st or StyleRegistry.player_choice != st.id:
			sel_ok = false
	_check(sel_ok, "each of the %d styles can be selected; it loads into the fighter and the rival differs" % StyleRegistry.count())

	print("RESULT: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)
