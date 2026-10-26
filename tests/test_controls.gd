extends SceneTree
## Simplified controls: J light, K heavy, L technique, W / S + J / K variants,
## F signature, Space jump, Shift block / parry, double-tap A / D dash.
## Checks the published mapping for all six styles in both facing directions
## (independently of the style files), every combo branch, the non-striking
## techniques, and through the real scene: dash rules, movement + attack,
## block, low block, parry, jump + air attack, signature and restart.

var _fails: int = 0

## The control scheme as published (slot -> move id), per style.
const SPEC: Dictionary = {
	&"boxing": {&"light": &"jab", &"heavy": &"cross", &"technique": &"bob_weave", &"up_light": &"uppercut",
		&"up_heavy": &"overhand", &"down_light": &"body_hook", &"down_heavy": &"slip_counter", &"F": &"gazelle_hook"},
	&"muay_thai": {&"light": &"jab", &"heavy": &"body_roundhouse", &"technique": &"elbow", &"up_light": &"rising_elbow",
		&"up_heavy": &"high_kick", &"down_light": &"body_straight", &"down_heavy": &"low_roundhouse", &"F": &"flying_knee"},
	&"karate": {&"light": &"jab", &"heavy": &"reverse_punch", &"technique": &"knife_hand", &"up_light": &"rising_punch",
		&"up_heavy": &"high_kick", &"down_light": &"body_punch", &"down_heavy": &"low_side_kick", &"F": &"perfect_gyaku"},
	&"kung_fu": {&"light": &"straight_palm", &"heavy": &"double_palm", &"technique": &"deflect_counter",
		&"up_light": &"rising_palm", &"up_heavy": &"backhand", &"down_light": &"low_palm", &"down_heavy": &"sweep",
		&"F": &"palm_barrage"},
	&"taekwondo": {&"light": &"jab", &"heavy": &"side_kick", &"technique": &"lead_leg_feint", &"up_light": &"rising_punch",
		&"up_heavy": &"high_kick", &"down_light": &"body_punch", &"down_heavy": &"axe_kick", &"F": &"tornado_540"},
	&"kickboxing": {&"light": &"jab", &"heavy": &"cross", &"technique": &"body_roundhouse", &"up_light": &"uppercut",
		&"up_heavy": &"high_kick", &"down_light": &"body_hook", &"down_heavy": &"low_roundhouse", &"F": &"breaker_combo"},
}
## Names the move list must show for each style (its own name for shared moves).
const NAMES: Dictionary = {
	&"karate": {&"jab": "Straight Punch", &"high_kick": "High Roundhouse"},
	&"muay_thai": {&"body_roundhouse": "Body Roundhouse", &"high_kick": "High Roundhouse", &"low_roundhouse": "Low Kick"},
	&"kung_fu": {&"backhand": "High Backfist", &"deflect_counter": "Deflect"},
	&"taekwondo": {&"high_kick": "High Roundhouse"},
}


func _check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func _pair(style: MartialArtStyle, gap: float, side: int) -> Array[Fighter]:
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
	a.set_style(style)
	return [a, b]


func _free(p: Array[Fighter]) -> void:
	for f in p:
		f.queue_free()


func _slot(slot: StringName) -> CombatData.Intent:
	var i := CombatData.Intent.new()
	i.slot = slot
	return i


func _initialize() -> void:
	print("[key -> slot]")
	var slot_cases := [
		[[true, false, false, false, false], &"light"], [[false, true, false, false, false], &"heavy"],
		[[false, false, true, false, false], &"technique"], [[true, false, false, true, false], &"up_light"],
		[[false, true, false, true, false], &"up_heavy"], [[true, false, false, false, true], &"down_light"],
		[[false, true, false, false, true], &"down_heavy"], [[true, false, false, true, true], &"up_light"],
		[[false, false, true, true, false], &"technique"], [[false, false, false, true, true], &""],
	]
	var main_script: GDScript = load("res://scripts/main.gd")
	for c in slot_cases:
		var k: Array = c[0]
		var got: StringName = main_script.attack_slot(k[0], k[1], k[2], k[3], k[4])
		_check(got == c[1], "J%s K%s L%s W%s S%s -> %s (%s)" % [int(k[0]), int(k[1]), int(k[2]), int(k[3]), int(k[4]), c[1], got])

	print("[every style, every key, both directions]")
	for sid in SPEC:
		var st := StyleRegistry.by_id(sid)
		_check(st != null and st.validate().is_empty(), "%s is registered and valid" % sid)
		if st == null:
			continue
		_check(st.signature == SPEC[sid][&"F"], "%s: F = %s" % [sid, SPEC[sid][&"F"]])
		_check(st.input_map.size() == MartialArtStyle.SLOTS.size(), "%s: every key has a move" % sid)
		for slot in MartialArtStyle.SLOTS:
			var want: StringName = SPEC[sid][slot]
			var faced := []
			for side in [1, -1]:
				var p := _pair(st, 140.0, side)
				var a := p[0]
				a.push_intent(_slot(slot))
				a.tick()
				var got: StringName = a.current_attack.id if a.state == Fighter.State.ATTACK else &"-"
				faced.append([got, a.facing])
				_free(p)
			_check(faced[0] == [want, 1] and faced[1] == [want, -1],
				"%s %s -> %s, facing right and left (%s)" % [sid, MartialArtStyle.SLOT_KEYS[slot], want, faced])
		for m in NAMES.get(sid, {}):
			_check(st.move_name(m) == NAMES[sid][m], "%s calls %s \"%s\" (%s)" % [sid, m, NAMES[sid][m], st.move_name(m)])
		var keys_ok := true
		for row in st.move_list():
			for bad in ["U", "I", "O", "away", "toward"]:
				if String(row[0]).split("+").has(bad) or String(row[0]).contains(bad + "+"):
					keys_ok = false
		_check(keys_ok, "%s move list shows only the new keys (%s)" % [sid, st.move_list()])

	print("[combo branches]")
	for sid in SPEC:
		var st := StyleRegistry.by_id(sid)
		if st == null:
			continue
		var slot_of := {}
		for slot in st.input_map:
			slot_of[st.input_map[slot]] = slot
		var failed: Array = []
		var total := 0
		for from in st.chains:
			for to in st.chains[from]:
				total += 1
				if not _chains(st, from, slot_of[to], to):
					failed.append("%s>%s" % [from, to])
		_check(failed.is_empty(), "%s: all %d combo branches fire from their keys (%s)" % [sid, total, failed])

	print("[techniques without a strike]")
	var box := StyleRegistry.by_id(&"boxing")
	var p := _pair(box, 90.0, 1)
	var a := p[0]
	var opp := p[1]
	a.push_intent(_slot(&"technique"))
	var whiffs := 0
	var body_lands := false
	var active := false
	for t in 26:
		a.tick()
		active = active or a.is_hitbox_active()
		if t == 4 or t == 12:
			if a.receive_hit(CombatData.get_attack(CombatData.AttackType.LIGHT), opp, 1) == CombatData.HitResult.WHIFF:
				whiffs += 1
	_check(whiffs == 2, "a head-height jab passes over the bob and weave (%d/2)" % whiffs)
	_check(not active, "bob and weave has no hitbox of its own")
	_free(p)
	p = _pair(box, 90.0, -1)
	a = p[0]
	a.push_intent(_slot(&"technique"))
	for t in 6:
		a.tick()
	body_lands = a.receive_hit(CombatData.get_attack(CombatData.AttackType.BODY_HOOK), p[1], 1) == CombatData.HitResult.HIT
	_check(body_lands, "a body hook still lands during the weave (facing left)")
	_free(p)
	var tkd := StyleRegistry.by_id(&"taekwondo")
	for side in [1, -1]:
		p = _pair(tkd, 300.0, side)
		a = p[0]
		a.push_intent(_slot(&"technique"))
		active = false
		var next := &""
		for t in 30:
			a.tick()
			if a.current_attack != null and a.current_attack.id == &"lead_leg_feint":
				active = active or a.is_hitbox_active()
			if t == 12:
				a.push_intent(_slot(&"heavy"))
			if a.combo_step == 2 and next == &"":
				next = a.current_attack.id
		_check(not active and next == &"side_kick",
			"lead-leg feint: no hitbox, flows into a side kick without contact (facing %d, %s)" % [side, next])
		_free(p)

	print("[new strikes: one hit, same either way]")
	for mid in [&"rising_elbow", &"body_straight", &"body_punch", &"low_palm"]:
		var res: Array = []
		for side in [1, -1]:
			p = _pair(null, 80.0, side)
			a = p[0]
			var b := p[1]
			var i := CombatData.Intent.new()
			i.attack = CombatData.type_for_id(mid)
			a.push_intent(i)
			var hits := 0
			for t in 50:
				a.tick()
				b.tick()
				if a.is_hitbox_active() and a.get_hitbox_world().intersects(b.get_hurtbox_world()):
					if b.receive_hit(a.current_attack, a, a.combo_step) == CombatData.HitResult.HIT:
						hits += 1
					a.confirm_hit(CombatData.HitResult.HIT)
			res.append([hits, b.health])
			_free(p)
		_check(res[0][0] == 1 and res[0] == res[1], "%s hits exactly once, same result facing either way (%s)" % [mid, res])

	print("[scene: dash, movement, guard, jump, signature, restart]")
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var d := Driver.new()
	d.tree = self
	d.fails = _fails
	d.process_physics_priority = -100
	root.add_child(d)


## Starts `from` against a close dummy, presses the key for `to` during the
## strike and reports whether the chain fired.
func _chains(st: MartialArtStyle, from: StringName, to_slot: StringName, to: StringName) -> bool:
	var p := _pair(st, 70.0, 1)
	var a := p[0]
	var b := p[1]
	var i := CombatData.Intent.new()
	i.attack = CombatData.type_for_id(from)
	a.push_intent(i)
	var at := CombatData.get_attack(i.attack)
	var ok := false
	for t in 70:
		a.tick()
		b.tick()
		if a.is_hitbox_active() and a.get_hitbox_world().intersects(b.get_hurtbox_world()):
			a.confirm_hit(b.receive_hit(a.current_attack, a, a.combo_step))
		if t == at.startup + at.active - 2:
			a.push_intent(_slot(to_slot))
		if a.state == Fighter.State.ATTACK and a.combo_step == 2 and a.current_attack.id == to:
			ok = true
			break
	_free(p)
	return ok


class Driver extends Node:
	var tree: SceneTree
	var frame: int = 0
	var fails: int = 0
	var min_gap: float = INF
	## frame -> actions pressed that frame (released on the next frame unless held).
	var taps: Dictionary = {}
	var held: Dictionary = {}

	func check(cond: bool, msg: String) -> void:
		print(("  ok   " if cond else "  FAIL ") + msg)
		if not cond:
			fails += 1

	func tap(f: int, actions: Array) -> void:
		taps[f] = actions

	func hold(from: int, to: int, action: String) -> void:
		for f in range(from, to):
			held[f] = held.get(f, []) + [action]

	func _ready() -> void:
		tap(10, ["move_right"])
		tap(14, ["move_right"])
		tap(40, ["move_left"])
		tap(44, ["move_left"])
		tap(70, ["move_right"])
		tap(83, ["move_right"])  # 13 ticks apart: too slow
		tap(100, ["move_right"])
		tap(112, ["move_right"])  # exactly the 12-tick window
		hold(140, 160, "move_right")
		tap(172, ["move_right"])
		tap(176, ["move_right"])
		tap(212, ["move_right"])
		tap(216, ["move_right"])
		tap(262, ["move_right"])
		tap(265, ["move_right"])
		hold(300, 309, "move_right")
		tap(305, ["attack_light"])
		hold(340, 344, "mod_up")
		tap(340, ["attack_light"])
		hold(380, 396, "block")
		hold(410, 422, "mod_down")  # S held, then Shift
		hold(414, 422, "block")
		tap(440, ["jump"])
		tap(447, ["attack_light"])
		tap(500, ["signature"])
		tap(560, ["restart"])

	func _physics_process(_d: float) -> void:
		frame += 1
		var main := tree.current_scene
		for a in ["move_left", "move_right", "attack_light", "attack_heavy", "attack_technique", "mod_up",
				"mod_down", "jump", "block", "signature", "restart"]:
			if not a in held.get(frame, []) and not a in taps.get(frame, []):
				Input.action_release(a)
		for a in taps.get(frame, []) + held.get(frame, []):
			Input.action_press(a)
		var p: Fighter = main.get_node("Player")
		var e: Fighter = main.get_node("Enemy")
		if frame == 1:
			main.call("select_style", &"boxing")
			main.call("start_match", true)
		if frame == 3:
			(main.get_node("EnemyAI") as EnemyAI).setup(null, null)
		if frame in [3, 168, 208, 258, 298, 336, 376, 436, 496]:
			# Reset the scene for the next check: player idle at a known spot,
			# the quiet rival out of the way.
			var px := 500.0
			var ex := 900.0
			if frame == 168:
				px = Fighter.ARENA_MAX_X - 20.0
				ex = px - 500.0
			elif frame == 208:
				ex = px + 100.0
			p.position = Vector2(px, p.ground_y)
			e.position = Vector2(ex, e.ground_y)
			p.airborne = false
			e.airborne = false
			p.call("_enter_state", Fighter.State.IDLE)
			e.call("_enter_state", Fighter.State.IDLE)
			p.face_opponent()
			e.face_opponent()
			p.health = p.max_health
			e.health = e.max_health
		if frame > 212 and frame < 245:
			min_gap = minf(min_gap, absf(e.position.x - p.position.x))
		match frame:
			17:
				check(p.state == Fighter.State.DODGE and p.dodge_world_dir == 1, "D D -> dash right (%s, dir %d)" % [p.get_state_name(), p.dodge_world_dir])
			47:
				check(p.state == Fighter.State.DODGE and p.dodge_world_dir == -1, "A A -> dash left, the tapped screen direction (%s, dir %d)" % [p.get_state_name(), p.dodge_world_dir])
			86:
				check(p.state != Fighter.State.DODGE, "taps 13 ticks apart -> no dash (%s)" % p.get_state_name())
			115:
				check(p.state == Fighter.State.DODGE, "taps 12 ticks apart -> dash (%s)" % p.get_state_name())
			160:
				check(p.state != Fighter.State.DODGE, "holding D never dashes (%s)" % p.get_state_name())
			179:
				check(p.state == Fighter.State.DODGE and p.dodge_world_dir == 1 and p.facing == -1,
					"D D facing left -> backstep to the right (%s, dir %d, facing %d)" % [p.get_state_name(), p.dodge_world_dir, p.facing])
			200:
				check(p.position.x <= Fighter.ARENA_MAX_X, "a dash stops at the stage edge (x %.0f)" % p.position.x)
			250:
				check(min_gap >= Fighter.PUSH_HALF_WIDTH * 2.0 - 0.5, "a dash into a standing rival stops at its pushbox (closest %.1f px)" % min_gap)
			260:
				p.call("_enter_state", Fighter.State.HITSTUN)
				p.stun_frames = 20
			268:
				check(p.state == Fighter.State.HITSTUN, "no dash out of hitstun (%s)" % p.get_state_name())
			285:
				check(p.state != Fighter.State.DODGE, "a dash tapped during hitstun does not fire later (%s)" % p.get_state_name())
			307:
				check(p.state == Fighter.State.ATTACK and p.current_attack.id == &"jab", "walking forward + J -> jab, at once (%s)" % p.get_debug_label())
			342:
				check(p.state == Fighter.State.ATTACK and p.current_attack.id == &"uppercut", "W + J -> uppercut (%s)" % p.get_debug_label())
			382:
				check(p.state == Fighter.State.BLOCK and p.is_parry_active(), "fresh Shift -> guard with a parry window (%s)" % p.get_debug_label())
			392:
				check(p.state == Fighter.State.BLOCK and not p.is_parry_active(), "holding Shift -> plain block (%s)" % p.get_debug_label())
			420:
				check(p.state == Fighter.State.BLOCK and p.is_crouched(), "S + Shift -> low block (%s)" % p.get_debug_label())
			444:
				check(p.state == Fighter.State.JUMP and p.airborne, "Space -> jump (%s)" % p.get_debug_label())
			450:
				check(p.state == Fighter.State.ATTACK and p.current_attack.id == &"jump_punch", "J in the air -> jump punch (%s)" % p.get_debug_label())
			497:
				p.focus = CombatData.FOCUS_MAX
			503:
				check(p.state == Fighter.State.ATTACK and p.current_attack.id == &"gazelle_hook" and p.focus == 0.0,
					"F at full Focus -> Gazelle Hook (%s)" % p.get_debug_label())
			570:
				check(main.call("get_round_state_name") != "FIGHTING" and p.health == p.max_health,
					"R restarts the match (%s)" % main.call("get_round_state_name"))
				print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
				tree.quit(fails)
