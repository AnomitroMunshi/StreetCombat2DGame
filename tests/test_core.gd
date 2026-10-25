extends SceneTree
## Headless unit checks for Fighter combat logic (no rendering, no scenes).

var _fails: int = 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		_fails += 1
		printerr("  FAIL ", msg)


func _make_pair() -> Array[Fighter]:
	var a := Fighter.new()
	var b := Fighter.new()
	root.add_child(a)
	root.add_child(b)
	a.position = Vector2(500, 560)
	b.position = Vector2(580, 560)
	a.opponent = b
	b.opponent = a
	a.face_opponent()
	b.face_opponent()
	return [a, b]


func _intent(attack: CombatData.AttackType = CombatData.AttackType.NONE, block: bool = false, move: int = 0) -> CombatData.Intent:
	var i := CombatData.Intent.new()
	i.attack = attack
	i.block = block
	i.move = move
	return i


## Mimics main.gd's per-tick hit resolution for a single attacker.
func _step(a: Fighter, b: Fighter, ia: CombatData.Intent, ib: CombatData.Intent) -> CombatData.HitResult:
	a.push_intent(ia)
	b.push_intent(ib)
	a.tick()
	b.tick()
	if a.is_hitbox_active() and a.get_hitbox_world().intersects(b.get_hurtbox_world()):
		if b.is_evading():
			b.perfect_evade()
			return CombatData.HitResult.WHIFF
		var r := b.receive_hit(a.current_attack, a, a.combo_step)
		a.confirm_hit(r)
		return r
	return CombatData.HitResult.WHIFF


func _initialize() -> void:
	print("KEY_F1 = ", KEY_F1)
	print("InputMap actions present: ", InputMap.has_action("attack_light"), " events:", InputMap.action_get_events("attack_light").size())

	print("[jab timing + single hit]")
	var p := _make_pair()
	var a: Fighter = p[0]
	var b: Fighter = p[1]
	var hits: Array[int] = []
	var none := _intent()
	for t in 30:
		var r := _step(a, b, _intent(CombatData.AttackType.LIGHT) if t == 0 else none, none)
		if r != CombatData.HitResult.WHIFF:
			hits.append(t)
	_check(hits.size() == 1, "jab hits exactly once (hits at ticks %s)" % [hits])
	_check(hits.size() == 1 and hits[0] == 5, "jab connects on first active tick (5)")
	_check(b.health == 94, "jab dealt 6 damage (hp %d)" % b.health)
	_check(a.state == Fighter.State.IDLE, "attacker back to IDLE after recovery")

	print("[3-hit combo via buffer]")
	p = _make_pair()
	a = p[0]
	b = p[1]
	var seq := {0: CombatData.AttackType.LIGHT, 3: CombatData.AttackType.LIGHT, 13: CombatData.AttackType.HEAVY, 22: CombatData.AttackType.LIGHT}
	var steps_seen: Array[int] = []
	var hit_count := 0
	for t in 80:
		var r := _step(a, b, _intent(seq.get(t, CombatData.AttackType.NONE)), none)
		if r == CombatData.HitResult.HIT:
			hit_count += 1
		if a.state == Fighter.State.ATTACK and not steps_seen.has(a.combo_step):
			steps_seen.append(a.combo_step)
	_check(steps_seen == [1, 2, 3], "chain progressed through steps 1,2,3 (%s)" % [steps_seen])
	_check(hit_count == 3, "all three combo hits landed (%d)" % hit_count)
	_check(b.received_combo == 3, "defender registered a 3-hit combo (%d)" % b.received_combo)
	_check(b.health == 100 - 6 - 6 - 13, "combo damage correct (hp %d)" % b.health)

	print("[blocking]")
	p = _make_pair()
	a = p[0]
	b = p[1]
	var blocked := false
	for t in 30:
		var r := _step(a, b, _intent(CombatData.AttackType.HEAVY) if t == 0 else none, _intent(CombatData.AttackType.NONE, true))
		if r == CombatData.HitResult.BLOCKED:
			blocked = true
			_check(b.state == Fighter.State.BLOCKSTUN, "defender in BLOCKSTUN")
	_check(blocked, "heavy was blocked")
	_check(b.health == 100, "no damage through block")

	print("[no block / movement mid-attack]")
	p = _make_pair()
	a = p[0]
	b = p[1]
	_step(a, b, _intent(CombatData.AttackType.KICK), none)
	var x0 := a.position.x
	for t in 6:
		_step(a, b, _intent(CombatData.AttackType.NONE, true, -1), none)
	_check(a.state == Fighter.State.ATTACK, "block/move input does not cancel attack startup")
	_check(a.position.x >= x0, "no backwards walking during attack")

	print("[KO]")
	p = _make_pair()
	a = p[0]
	b = p[1]
	b.health = 5
	for t in 20:
		_step(a, b, _intent(CombatData.AttackType.LIGHT) if t == 0 else none, none)
	_check(b.state == Fighter.State.FINISHED and b.health == 0, "lethal hit -> FINISHED (awaiting finisher) at 0 hp")
	var again := b.receive_hit(CombatData.get_attack(CombatData.AttackType.HEAVY), a, 1)
	_check(again == CombatData.HitResult.WHIFF and b.health == 0, "finished fighter ignores further hits")

	print("KEY_SHIFT = ", KEY_SHIFT, "  block bound to shift: ",
		(InputMap.action_get_events("block")[0] as InputEventKey).physical_keycode == KEY_SHIFT)

	print("[front kick]")
	p = _make_pair()
	a = p[0]
	b = p[1]
	hits = []
	for t in 30:
		var r := _step(a, b, _intent(CombatData.AttackType.FRONT_KICK) if t == 0 else none, none)
		if r != CombatData.HitResult.WHIFF:
			hits.append(t)
	_check(hits == [7], "front kick hits once on tick 7 (%s)" % [hits])
	_check(b.health == 92, "front kick dealt 8 (hp %d)" % b.health)
	_check(b.position.x - a.position.x > 120.0, "front kick pushed defender away (gap %.0f)" % (b.position.x - a.position.x))

	print("[jump arc + landing]")
	p = _make_pair()
	a = p[0]
	b = p[1]
	a.position.x = 300
	a.ground_y = 560
	b.ground_y = 560
	var jump := _intent()
	jump.jump = true
	var peak := 0.0
	var air_ticks := 0
	var saw_land := false
	var landed_tick := -1
	for t in 60:
		_step(a, b, jump if t == 0 else none, none)
		if a.airborne:
			air_ticks += 1
			peak = maxf(peak, 560.0 - a.position.y)
		if a.state == Fighter.State.LAND:
			saw_land = true
		if saw_land and landed_tick < 0 and a.state == Fighter.State.IDLE:
			landed_tick = t
	_check(peak > 90.0 and peak < 130.0, "jump peak height ~118 px (%.0f)" % peak)
	_check(air_ticks >= 24 and air_ticks <= 32, "airtime ~29 ticks (%d)" % air_ticks)
	_check(saw_land and landed_tick > 0, "went through LAND recovery back to IDLE")
	_check(is_equal_approx(a.position.y, 560.0), "back on the floor exactly")

	print("[jump kick vs standing opponent]")
	p = _make_pair()
	a = p[0]
	b = p[1]
	a.position.x = 430
	a.ground_y = 560
	b.ground_y = 560
	var jf := _intent(CombatData.AttackType.NONE, false, 1)
	jf.jump = true
	var fwd := _intent(CombatData.AttackType.NONE, false, 1)
	var jk_hits := 0
	var extra_kicks := 0
	for t in 70:
		var ia := fwd
		if t == 0:
			ia = jf
		elif t == 16:
			ia = _intent(CombatData.AttackType.KICK)
		elif t == 22:
			ia = _intent(CombatData.AttackType.FRONT_KICK)  # second air kick must be refused
		var r := _step(a, b, ia, none)
		if r == CombatData.HitResult.HIT:
			jk_hits += 1
		if a.current_attack != null and a.current_attack.type == CombatData.AttackType.JUMP_KICK and a.swing_id > 1:
			extra_kicks += 1
	_check(jk_hits == 1, "jump kick hit standing opponent once (%d)" % jk_hits)
	_check(b.health == 89, "jump kick dealt 11 (hp %d)" % b.health)
	_check(extra_kicks == 0, "only one air attack per jump")
	_check(not a.airborne, "attacker landed")

	print("[jump punch]")
	p = _make_pair()
	a = p[0]
	b = p[1]
	a.position.x = 450
	a.ground_y = 560
	b.ground_y = 560
	var jp_started := false
	var jp_hit := false
	var jfw := _intent(CombatData.AttackType.NONE, false, 1)
	jfw.jump = true
	for t in 60:
		var ia := jfw if t == 0 else (_intent(CombatData.AttackType.LIGHT) if t == 20 else _intent(CombatData.AttackType.NONE, false, 1))
		var r := _step(a, b, ia, none)
		if a.airborne and a.current_attack != null and a.current_attack.type == CombatData.AttackType.JUMP_PUNCH:
			jp_started = true
		if r == CombatData.HitResult.HIT:
			jp_hit = true
	_check(jp_started, "J in the air becomes a jump punch")
	_check(jp_hit and b.health == 92, "jump punch hit late in the jump for 8 (hp %d)" % b.health)

	print("[knockdown + get-up]")
	p = _make_pair()
	a = p[0]
	b = p[1]
	a.ground_y = 560
	b.ground_y = 560
	var kseq := {0: CombatData.AttackType.LIGHT, 3: CombatData.AttackType.LIGHT, 13: CombatData.AttackType.BACKHAND}
	var states_seen: Array[int] = []
	var bounced_seen := false
	var whiff_while_down := false
	for t in 140:
		_step(a, b, _intent(kseq.get(t, CombatData.AttackType.NONE)), none)
		if states_seen.is_empty() or states_seen[-1] != b.state:
			states_seen.append(b.state)
		if b.state == Fighter.State.KNOCKDOWN and b.bounced:
			bounced_seen = true
		if b.state == Fighter.State.KNOCKDOWN and not whiff_while_down:
			var hp := b.health
			var r := b.receive_hit(CombatData.get_attack(CombatData.AttackType.HEAVY), a, 1)
			whiff_while_down = r == CombatData.HitResult.WHIFF and b.health == hp
	var names: Array[String] = []
	for s in states_seen:
		names.append(Fighter.State.keys()[s])
	var seq_ok := names.find("KNOCKDOWN") >= 0 and names.find("GETUP") > names.find("KNOCKDOWN") and names[-1] == "IDLE"
	_check(seq_ok, "3rd hit -> KNOCKDOWN -> GETUP -> IDLE (%s)" % [names])
	_check(bounced_seen, "body bounced on landing")
	_check(whiff_while_down, "cannot be hit while knocked down")
	_check(is_equal_approx(b.position.y, 560.0) and not b.airborne, "back on feet at floor level")

	print("[backhand]")
	p = _make_pair()
	a = p[0]
	b = p[1]
	hits = []
	for t in 30:
		var r := _step(a, b, _intent(CombatData.AttackType.BACKHAND) if t == 0 else none, none)
		if r != CombatData.HitResult.WHIFF:
			hits.append(t)
	_check(hits == [6], "backhand hits once on tick 6 (%s)" % [hits])
	_check(b.health == 93, "backhand dealt 7 (hp %d)" % b.health)

	print("[uppercut launches + juggle]")
	p = _make_pair()
	a = p[0]
	b = p[1]
	a.ground_y = 560
	b.ground_y = 560
	b.position.x = 560
	var launched_h := 0.0
	var juggle := false
	for t in 60:
		var ia := none
		if t == 0:
			ia = _intent(CombatData.AttackType.UPPERCUT)
		elif t == 10:
			ia = _intent(CombatData.AttackType.LIGHT)  # buffered chain into a jab
		var r := _step(a, b, ia, none)
		if b.airborne:
			launched_h = maxf(launched_h, 560.0 - b.position.y)
		if r == CombatData.HitResult.HIT and a.combo_step == 2 and b.airborne:
			juggle = true
	_check(launched_h > 25.0, "uppercut launched defender (peak %.0f px)" % launched_h)
	_check(juggle, "chained jab juggled the airborne defender")
	_check(not b.airborne and b.position.y == 560.0, "defender came back down")

	print("[uppercut as anti-air]")
	p = _make_pair()
	a = p[0]
	b = p[1]
	a.ground_y = 560
	b.ground_y = 560
	b.position.x = 640
	var jl := _intent(CombatData.AttackType.NONE, false, -1)
	jl.jump = true
	var aa_hit := false
	for t in 60:
		var ia := _intent(CombatData.AttackType.UPPERCUT) if t == 14 else none
		var ib := jl if t == 0 else (_intent(CombatData.AttackType.NONE, false, -1) if t < 6 else none)
		var r := _step(a, b, ia, ib)
		if r == CombatData.HitResult.HIT and b.airborne:
			aa_hit = true
	_check(aa_hit, "uppercut hit a jumping opponent")

	print("[blocked uppercut does not launch]")
	p = _make_pair()
	a = p[0]
	b = p[1]
	b.position.x = 560
	var blk := _intent(CombatData.AttackType.NONE, true)
	var was_blocked := false
	for t in 30:
		var r := _step(a, b, _intent(CombatData.AttackType.UPPERCUT) if t == 0 else none, blk)
		if r == CombatData.HitResult.BLOCKED:
			was_blocked = true
	_check(was_blocked and not b.airborne and b.health == 100, "blocked: no launch, no damage")

	print("[finisher selection]")
	FinisherDirector._last_played = -1
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	p = _make_pair()
	a = p[0]
	b = p[1]
	b.airborne = true
	var air_n := 0
	for i in 200:
		FinisherDirector._last_played = -1
		if FinisherDirector.choose(a, b, null, rng) == FinisherDirector.Kind.AIR_SMASH:
			air_n += 1
	_check(air_n > 110 and air_n < 170, "airborne victim -> Air Smash most of the time (%d/200)" % air_n)
	b.airborne = false
	FinisherDirector._last_played = -1
	var up_n := 0
	for i in 200:
		FinisherDirector._last_played = -1
		if FinisherDirector.choose(a, b, CombatData.get_attack(CombatData.AttackType.UPPERCUT), rng) == FinisherDirector.Kind.AIR_SMASH:
			up_n += 1
	_check(up_n > 110, "uppercut kill -> Air Smash most of the time (%d/200)" % up_n)
	b.position.x = Fighter.ARENA_MAX_X - 60.0
	a.position.x = b.position.x - 80.0
	FinisherDirector._last_played = -1
	var wall_n := 0
	for i in 200:
		FinisherDirector._last_played = -1
		if FinisherDirector.choose(a, b, null, rng) == FinisherDirector.Kind.WALL_CRUSH:
			wall_n += 1
	_check(wall_n > 90 and wall_n < 150, "victim near wall -> Wall Crush most of the time (%d/200)" % wall_n)
	b.position.x = 640.0
	a.position.x = 560.0
	FinisherDirector._last_played = -1
	var randoms := {}
	var repeats := 0
	var prev := -1
	for i in 30:
		var k := FinisherDirector.choose(a, b, null, rng)
		randoms[k] = true
		if k == prev:
			repeats += 1
		prev = k
	_check(repeats == 0, "never the same finisher twice in a row (%d repeats)" % repeats)
	b.position.x = Fighter.ARENA_MAX_X - 60.0
	a.position.x = b.position.x - 80.0
	var wall_repeat := 0
	var prev_w := -1
	for i in 60:
		var k := FinisherDirector.choose(a, b, null, rng)
		if k == prev_w:
			wall_repeat += 1
		prev_w = k
	_check(wall_repeat == 0, "near the wall, finishers still never repeat back-to-back")
	b.position.x = 640.0
	a.position.x = 560.0
	_check(randoms.size() == 3 and randoms.has(FinisherDirector.Kind.PALM_FLURRY) and randoms.has(FinisherDirector.Kind.SPINNING_HEEL)
		and randoms.has(FinisherDirector.Kind.TORNADO_KICK), "open floor -> random Palm Flurry / Spinning Heel / Tornado Kick")

	for kind in [FinisherDirector.Kind.PALM_FLURRY, FinisherDirector.Kind.SPINNING_HEEL, FinisherDirector.Kind.AIR_SMASH,
			FinisherDirector.Kind.WALL_CRUSH, FinisherDirector.Kind.TORNADO_KICK]:
		for side in [1, -1]:
			var kname: String = "%s (%s)" % [FinisherDirector.DISPLAY_NAMES[kind], "facing right" if side == 1 else "facing left"]
			print("[finisher %s]" % kname)
			p = _make_pair()
			a = p[0]
			b = p[1]
			a.ground_y = 560
			b.ground_y = 560
			# Mirror the setup around the arena centre for the left-facing run.
			if kind == FinisherDirector.Kind.WALL_CRUSH:
				b.position.x = Fighter.ARENA_MAX_X - 120.0 if side == 1 else Fighter.ARENA_MIN_X + 120.0
			else:
				b.position.x = 640.0 + side * 40.0
			a.position.x = b.position.x - side * 90.0
			a.face_opponent()
			b.face_opponent()
			var start_b := b.position.x
			b.health = 0
			var director := FinisherDirector.new(kind, a, b)
			var hits_n := 0
			var finals := 0
			var crossed := false
			var ticks := 0
			while not director.done and ticks < 400:
				var ev := director.tick()
				a.tick()
				b.tick()
				if not ev.is_empty():
					hits_n += 1
					if ev["final"]:
						finals += 1
				if finals == 0 and (b.position.x - a.position.x) * side < 30.0:
					crossed = true
				ticks += 1
			for t in 200:
				a.tick()
				b.tick()
			_check(director.done and ticks < 400, "%s completes (%d ticks, %d hits)" % [kname, ticks, hits_n])
			_check(finals == 1 and b.state == Fighter.State.KO, "%s ends in exactly one final blow -> KO" % kname)
			_check(not b.airborne and not b.rolling and not b.skidding and is_equal_approx(b.position.y, 560.0) and not a.airborne, "%s: both at rest on the floor" % kname)
			_check(not crossed, "%s: attacker never passes through the victim" % kname)
			_check((b.position.x - start_b) * side >= -1.0, "%s: victim driven away from the attacker" % kname)
			_check(b.position.x <= Fighter.ARENA_MAX_X and a.position.x >= Fighter.ARENA_MIN_X
				and b.position.x >= Fighter.ARENA_MIN_X and a.position.x <= Fighter.ARENA_MAX_X, "%s: both inside the arena" % kname)

	print("[destruction effects]")
	var fxl := FxLayer.new()
	root.add_child(fxl)
	fxl.set_seed(1)
	fxl.crack(Vector2(640, 560), 160.0, false, 9)
	var g0 := fxl.get_newest_decal_growth()
	for t in 5:
		fxl._physics_process(1.0 / 60.0)
	var g1 := fxl.get_newest_decal_growth()
	for t in 40:
		fxl._physics_process(1.0 / 60.0)
	var g2 := fxl.get_newest_decal_growth()
	_check(g0 < g1 and g1 < 1.0 and g2 == 1.0, "cracks grow outward progressively (%.2f -> %.2f -> %.2f)" % [g0, g1, g2])
	fxl.debris(Vector2(640, 500), 300, Color.BROWN, 8.0)
	_check(fxl.get_debris_count() == FxLayer.MAX_DEBRIS, "debris pool capped at %d (%d)" % [FxLayer.MAX_DEBRIS, fxl.get_debris_count()])
	for t in 80:
		fxl._physics_process(1.0 / 60.0)
	var all_landed := true
	for c in fxl.get("_debris"):
		if absf((c["pos"] as Vector2).y - fxl.floor_y) > 0.5:
			all_landed = false
	_check(all_landed, "debris chips come to rest on the floor")
	for t in FxLayer.DEBRIS_LIFE:
		fxl._physics_process(1.0 / 60.0)
	_check(fxl.get_debris_count() == 0, "settled debris fades out")
	for i in 60:
		fxl.crack(Vector2(100 + i * 10, 560), 80.0, false)
	_check(fxl.get_decal_count() == FxLayer.MAX_DECALS, "crack decals capped at %d" % FxLayer.MAX_DECALS)
	fxl.jolt_wall(1, 6.0)
	for t in 60:
		fxl._physics_process(1.0 / 60.0)
	_check(fxl.wall_jolt[1] == 0.0, "pillar jolt settles back to rest")
	fxl.queue_free()

	print("[blowback: tumble -> bounce -> roll -> crouch get-up]")
	p = _make_pair()
	a = p[0]
	b = p[1]
	a.ground_y = 560
	b.ground_y = 560
	b.position.x = 600
	b.state = Fighter.State.KNOCKDOWN
	b.blowback(1, 9.0, -5.5, 1, true)
	var saw_tumble := false
	var saw_bounce := false
	var saw_roll := false
	var max_roll := 0.0
	var start_x := b.position.x
	var from_roll := false
	for t in 200:
		b.tick()
		if b.airborne and b.tumble:
			saw_tumble = true
		if b.bounced:
			saw_bounce = true
		if b.rolling:
			saw_roll = true
			max_roll = maxf(max_roll, b.roll_distance)
		if b.state == Fighter.State.GETUP and b.getup_from_roll:
			from_roll = true
		if b.state == Fighter.State.IDLE:
			break
	_check(saw_tumble and saw_bounce and saw_roll, "tumbled, bounced and rolled")
	_check(max_roll >= CombatData.ROLL_DISTANCE - 1.0, "rolled a full roll (%.0f px)" % max_roll)
	_check(from_roll and b.state == Fighter.State.IDLE, "quick get-up from the roll, back to IDLE")
	_check(b.position.x - start_x > 250.0, "travelled far (%.0f px)" % (b.position.x - start_x))

	print("[wall bounce]")
	p = _make_pair()
	a = p[0]
	b = p[1]
	b.ground_y = 560
	b.position.x = Fighter.ARENA_MAX_X - 80.0
	b.state = Fighter.State.KNOCKDOWN
	var wall_hits := [0]
	b.wall_hit.connect(func(_f: Fighter) -> void: wall_hits[0] += 1)
	b.blowback(1, 12.0, -8.0, 1, true)
	var moved_back := false
	for t in 120:
		b.tick()
		if wall_hits[0] > 0 and b.jump_vx < 0.0:
			moved_back = true
	_check(wall_hits[0] == 1, "bounced off the wall exactly once (%d)" % wall_hits[0])
	_check(moved_back, "rebounded away from the wall")
	_check(b.position.x <= Fighter.ARENA_MAX_X, "stayed inside the arena")

	print("[block startup 2 / release 6]")
	p = _make_pair()
	a = p[0]
	b = p[1]
	# Guard raised only 1 tick before the jab connects (tick 5): too late.
	var late_hit := false
	for t in 12:
		var r := _step(a, b, _intent(CombatData.AttackType.LIGHT) if t == 0 else none, _intent(CombatData.AttackType.NONE, t >= 4))
		if r == CombatData.HitResult.HIT:
			late_hit = true
	_check(late_hit, "guard raised 1 tick before impact does not block (startup 2)")
	p = _make_pair()
	a = p[0]
	b = p[1]
	var attack_tick := -1
	for t in 30:
		var ib := _intent(CombatData.AttackType.NONE, t < 10)
		if t == 10:
			ib = _intent(CombatData.AttackType.LIGHT, false)
		_step(a, b, none, ib)
		if b.state == Fighter.State.ATTACK and attack_tick < 0:
			attack_tick = t
	_check(attack_tick >= 10 + CombatData.BLOCK_RELEASE_FRAMES, "attacking out of block waits for the guard release (attack at %d)" % attack_tick)

	print("[sweep]")
	p = _make_pair()
	a = p[0]
	b = p[1]
	a.ground_y = 560
	b.ground_y = 560
	var swept := false
	for t in 30:
		var r := _step(a, b, _intent(CombatData.AttackType.SWEEP) if t == 0 else none, none)
		if r == CombatData.HitResult.HIT:
			swept = b.state == Fighter.State.KNOCKDOWN and b.last_hit_low
			_check(t == 10, "sweep connects on tick 10 (%d)" % t)
	_check(swept, "sweep always knocks down, hit registered as low")
	_check(b.health == 91, "sweep dealt 9 (hp %d)" % b.health)
	p = _make_pair()
	a = p[0]
	b = p[1]
	var low_block := _intent(CombatData.AttackType.NONE, true)
	low_block.crouch = true
	var sweep_blocked := false
	for t in 30:
		var r := _step(a, b, _intent(CombatData.AttackType.SWEEP) if t == 0 else none, low_block)
		if r == CombatData.HitResult.BLOCKED:
			sweep_blocked = true
	_check(sweep_blocked and b.state != Fighter.State.KNOCKDOWN and b.health == 100, "low block (S+Shift) stops the sweep")
	p = _make_pair()
	a = p[0]
	b = p[1]
	var stand_swept := false
	for t in 30:
		var r := _step(a, b, _intent(CombatData.AttackType.SWEEP) if t == 0 else none, _intent(CombatData.AttackType.NONE, true))
		if r == CombatData.HitResult.HIT:
			stand_swept = true
	_check(stand_swept, "standing block does NOT stop a sweep (low attack)")

	print("[crouch]")
	var crouch_i := _intent()
	crouch_i.crouch = true
	p = _make_pair()
	a = p[0]
	b = p[1]
	var hk_hit := false
	for t in 30:
		if _step(a, b, _intent(CombatData.AttackType.HIGH_KICK) if t == 0 else none, crouch_i) == CombatData.HitResult.HIT:
			hk_hit = true
	_check(b.state == Fighter.State.CROUCH and not hk_hit, "high kick whiffs over a crouching opponent")
	p = _make_pair()
	a = p[0]
	b = p[1]
	var bh_hit := false
	for t in 30:
		if _step(a, b, _intent(CombatData.AttackType.BACKHAND) if t == 0 else none, crouch_i) == CombatData.HitResult.HIT:
			bh_hit = true
	_check(not bh_hit, "backhand whiffs over a crouching opponent")
	p = _make_pair()
	a = p[0]
	b = p[1]
	var jab_hit := false
	for t in 30:
		if _step(a, b, _intent(CombatData.AttackType.LIGHT) if t == 0 else none, crouch_i) == CombatData.HitResult.HIT:
			jab_hit = true
	_check(jab_hit, "jab still hits a crouching opponent")
	p = _make_pair()
	a = p[0]
	b = p[1]
	var moved := false
	var crawl := _intent(CombatData.AttackType.NONE, false, -1)
	crawl.crouch = true
	var crouch_x := b.position.x
	for t in 20:
		_step(a, b, none, crawl)
	_check(is_equal_approx(b.position.x, crouch_x), "no walking while crouched")

	print("[high kick]")
	p = _make_pair()
	a = p[0]
	b = p[1]
	hits = []
	for t in 30:
		var r := _step(a, b, _intent(CombatData.AttackType.HIGH_KICK) if t == 0 else none, none)
		if r != CombatData.HitResult.WHIFF:
			hits.append(t)
	_check(hits == [7], "high kick hits once on tick 7 (%s)" % [hits])
	_check(b.health == 88, "high kick dealt 12 (hp %d)" % b.health)
	_check(b.last_hit_high, "high kick lands at head height")

	print("[dodge / step]")
	p = _make_pair()
	a = p[0]
	b = p[1]
	# b backsteps (world -1 = away from a) right as a's jab comes out.
	var dodge_i := _intent()
	dodge_i.dodge = 1  # b faces left (toward a), so +1 = away from a
	var dodge_start_x := b.position.x
	var evaded := false
	var got_hit := false
	for t in 20:
		var r := _step(a, b, _intent(CombatData.AttackType.LIGHT) if t == 2 else none, dodge_i if t == 0 else none)
		if a.state == Fighter.State.ATTACK and a.get_phase() == Fighter.Phase.ACTIVE and b.is_evading():
			evaded = true
		if r == CombatData.HitResult.HIT:
			got_hit = true
	_check(evaded and not got_hit, "jab during the dodge's invulnerable frames whiffs")
	_check(b.position.x - dodge_start_x > 80.0, "backstep moved away %.0f px" % (b.position.x - dodge_start_x))
	p = _make_pair()
	a = p[0]
	b = p[1]
	var counter_tick := -1
	for t in 30:
		var ib := none
		if t == 0:
			ib = dodge_i
		elif t == 6:
			ib = _intent(CombatData.AttackType.LIGHT)  # buffered during the dodge
		_step(a, b, none, ib)
		if b.state == Fighter.State.ATTACK and counter_tick < 0:
			counter_tick = t
	_check(counter_tick == CombatData.DODGE_FRAMES, "attack buffered during the dodge fires as it ends (tick %d)" % counter_tick)
	p = _make_pair()
	a = p[0]
	b = p[1]
	var early_hit := false
	for t in 12:
		# The jab connects on tick 5; a dodge started on tick 5 is still in startup.
		var r := _step(a, b, _intent(CombatData.AttackType.LIGHT) if t == 0 else none, dodge_i if t == 5 else none)
		if r == CombatData.HitResult.HIT:
			early_hit = true
	_check(early_hit, "a dodge started too late (before its i-frames) still gets hit")

	print("[stances]")
	var srng := RandomNumberGenerator.new()
	srng.seed = 3
	var clash := false
	var seen := {}
	for player_stance in Stances.count():
		for i in 50:
			var ai_stance := Stances.random_except(player_stance, srng)
			seen[ai_stance] = true
			if ai_stance == player_stance:
				clash = true
	_check(not clash, "AI stance is never the player's stance")
	_check(seen.size() == Stances.count(), "all %d stances can be picked" % Stances.count())

	print("[both facing directions]")
	var mirror_ok := true
	for type in [CombatData.AttackType.LIGHT, CombatData.AttackType.HEAVY, CombatData.AttackType.KICK,
			CombatData.AttackType.FRONT_KICK, CombatData.AttackType.BACKHAND, CombatData.AttackType.UPPERCUT,
			CombatData.AttackType.HIGH_KICK, CombatData.AttackType.SWEEP]:
		var results: Array = []
		for side in [1, -1]:
			p = _make_pair()
			a = p[0]
			b = p[1]
			a.position.x = 640.0 - side * 40.0
			b.position.x = 640.0 + side * 40.0
			a.face_opponent()
			b.face_opponent()
			var hit_at := -1
			var box := Rect2()
			for t in 40:
				if _step(a, b, _intent(type) if t == 0 else none, none) != CombatData.HitResult.WHIFF and hit_at < 0:
					hit_at = t
				if a.state == Fighter.State.ATTACK and a.get_phase() == Fighter.Phase.ACTIVE and box.size == Vector2.ZERO:
					# Hitbox relative to the attacker, mirrored back to "facing right".
					var hb := a.get_hitbox_world()
					var rel_x := hb.position.x - a.position.x if side == 1 else a.position.x - hb.end.x
					box = Rect2(rel_x, hb.position.y - a.position.y, hb.size.x, hb.size.y)
			results.append([hit_at, b.health, box])
		var same: bool = results[0][0] == results[1][0] and results[0][1] == results[1][1] \
			and (results[0][2] as Rect2).is_equal_approx(results[1][2]) and results[0][0] >= 0
		if not same:
			mirror_ok = false
			printerr("  %s right %s / left %s" % [CombatData.attack_name(type), results[0], results[1]])
	_check(mirror_ok, "every grounded attack hits on the same tick, for the same damage, with a mirrored hitbox facing left or right")

	print("[directional guard: cross-up]")
	p = _make_pair()
	a = p[0]
	b = p[1]
	var guard := _intent(CombatData.AttackType.NONE, true)
	for t in 4:
		_step(a, b, none, guard)
	_check(b.state == Fighter.State.BLOCK and b.facing == -1, "defender guarding toward the attacker (left)")
	# Attacker crosses to the defender's back (as after a jump over them).
	a.position.x = b.position.x + 70.0
	a.face_opponent()
	var cross_result := CombatData.HitResult.WHIFF
	for t in 20:
		var r := _step(a, b, _intent(CombatData.AttackType.LIGHT) if t == 0 else none, guard)
		if r != CombatData.HitResult.WHIFF:
			cross_result = r
	_check(cross_result == CombatData.HitResult.HIT and b.health == 94, "a held guard does not turn: an attack from behind hits (%s)" % CombatData.HitResult.keys()[cross_result])
	# Re-raising the guard after turning blocks again.
	for t in 30:
		_step(a, b, none, none)
	for t in 4:
		_step(a, b, none, guard)
	var front_result := CombatData.HitResult.WHIFF
	for t in 20:
		var r := _step(a, b, _intent(CombatData.AttackType.LIGHT) if t == 0 else none, guard)
		if r != CombatData.HitResult.WHIFF:
			front_result = r
	_check(front_result == CombatData.HitResult.BLOCKED, "after turning and re-raising the guard, the same attack is blocked")

	print("[perfect parry]")
	var parry_i := _intent(CombatData.AttackType.NONE, true)
	parry_i.parry = true
	var hold := _intent(CombatData.AttackType.NONE, true)
	# Jab connects on tick 5; Shift pressed on tick 3 -> hit on guard frame 2 (window 0..3).
	p = _make_pair()
	a = p[0]
	b = p[1]
	var pr := CombatData.HitResult.WHIFF
	for t in 7:
		var r := _step(a, b, _intent(CombatData.AttackType.LIGHT) if t == 0 else none, parry_i if t == 3 else (hold if t > 3 else none))
		if r != CombatData.HitResult.WHIFF:
			pr = r
	_check(pr == CombatData.HitResult.PARRIED, "Shift pressed 2 ticks before impact parries (%s)" % CombatData.HitResult.keys()[pr])
	_check(b.health == 100, "parry: no damage")
	_check(a.state == Fighter.State.STAGGER and b.state == Fighter.State.PARRY, "attacker staggers, defender deflects")
	# Counter straight out of the deflect.
	var counter_hit := false
	var counter_start := -1
	for t in 30:
		var r := _step(b, a, _intent(CombatData.AttackType.LIGHT) if t == 0 else none, none)
		if b.state == Fighter.State.ATTACK and counter_start < 0:
			counter_start = t
		if r == CombatData.HitResult.HIT:
			counter_hit = true
	_check(counter_start == 0, "counter attack cancels the deflect immediately (tick %d)" % counter_start)
	_check(counter_hit and a.health == 94, "counter jab lands on the staggered attacker (hp %d)" % a.health)

	# Pressed too early: the window is over, it is an ordinary block.
	p = _make_pair()
	a = p[0]
	b = p[1]
	pr = CombatData.HitResult.WHIFF
	for t in 7:
		var r := _step(a, b, _intent(CombatData.AttackType.LIGHT) if t == 0 else none, parry_i if t == 0 else hold)
		if r != CombatData.HitResult.WHIFF:
			pr = r
	_check(pr == CombatData.HitResult.BLOCKED, "Shift pressed 5 ticks early: normal block, not a parry (%s)" % CombatData.HitResult.keys()[pr])

	# Tapping Shift with nothing to parry: slower recovery, then a cooldown.
	p = _make_pair()
	a = p[0]
	b = p[1]
	_step(a, b, none, parry_i)
	_step(a, b, none, hold)
	_step(a, b, none, none)
	_check(b.state == Fighter.State.GUARD_RELEASE and b.parry_whiffed and b.stun_frames == CombatData.PARRY_WHIFF_RECOVERY,
		"releasing an unused parry early: whiff recovery %d ticks" % b.stun_frames)
	for t in 15:
		_step(a, b, none, none)
	# Second press inside the cooldown: no parry window, hit lands on guard frame 2 -> plain block.
	pr = CombatData.HitResult.WHIFF
	for t in 7:
		var r := _step(a, b, _intent(CombatData.AttackType.LIGHT) if t == 0 else none, parry_i if t == 3 else (hold if t > 3 else none))
		if r != CombatData.HitResult.WHIFF:
			pr = r
	_check(pr == CombatData.HitResult.BLOCKED, "parry spam: a press inside the cooldown cannot parry (%s)" % CombatData.HitResult.keys()[pr])

	# Sweeps must be parried low.
	for low in [false, true]:
		p = _make_pair()
		a = p[0]
		b = p[1]
		var lp := _intent(CombatData.AttackType.NONE, true)
		lp.parry = true
		lp.crouch = low
		var lh := _intent(CombatData.AttackType.NONE, true)
		lh.crouch = low
		pr = CombatData.HitResult.WHIFF
		for t in 12:
			# Sweep connects on tick 10.
			var r := _step(a, b, _intent(CombatData.AttackType.SWEEP) if t == 0 else none, lp if t == 8 else (lh if t > 8 else none))
			if r != CombatData.HitResult.WHIFF:
				pr = r
		if low:
			_check(pr == CombatData.HitResult.PARRIED, "S + Shift timed: sweep parried low (%s)" % CombatData.HitResult.keys()[pr])
		else:
			_check(pr == CombatData.HitResult.HIT, "standing parry does not stop a sweep (%s)" % CombatData.HitResult.keys()[pr])

	print("[posture]")
	var cross := CombatData.get_attack(CombatData.AttackType.HEAVY)
	var jab := CombatData.get_attack(CombatData.AttackType.LIGHT)
	_check(jab.posture < cross.posture and cross.posture != float(cross.damage), "posture values are per attack, not copied from damage (jab %d, cross %d)" % [jab.posture, cross.posture])
	p = _make_pair()
	a = p[0]
	b = p[1]
	for t in 4:
		_step(a, b, none, hold)
	var blocks_to_break := 0
	var res := CombatData.HitResult.WHIFF
	for i in 20:
		res = b.receive_hit(cross, a, 1)
		blocks_to_break += 1
		if res != CombatData.HitResult.BLOCKED:
			break
		while b.state == Fighter.State.BLOCKSTUN:
			_step(a, b, none, hold)
	var expected_blocks := ceili(CombatData.POSTURE_MAX / cross.posture)
	_check(res == CombatData.HitResult.GUARD_BREAK and blocks_to_break == expected_blocks,
		"blocking crosses breaks the guard on block %d (expected %d)" % [blocks_to_break, expected_blocks])
	_check(b.state == Fighter.State.BROKEN and b.health == 100, "guard broken: BROKEN state, still no damage")
	_check(b.posture == 0.0 and b.posture_lock > 0, "posture emptied and locked after the break")
	var acted := false
	for t in 20:
		_step(a, b, none, _intent(CombatData.AttackType.LIGHT, true))
		if b.state != Fighter.State.BROKEN:
			acted = true
	_check(not acted, "a broken fighter can neither attack nor block")
	var punish := b.receive_hit(jab, a, 1)
	_check(punish == CombatData.HitResult.HIT and b.state == Fighter.State.HITSTUN, "punish lands; the hit ends the break (no stun loop)")
	_check(not b.add_posture(200.0) and b.posture == 0.0, "no posture gain while locked (breaks cannot chain)")

	# Recovery after a quiet spell.
	p = _make_pair()
	a = p[0]
	b = p[1]
	b.add_posture(50.0)
	for t in CombatData.POSTURE_RECOVER_DELAY:
		_step(a, b, none, none)
	_check(is_equal_approx(b.posture, 50.0), "no recovery during the first %d ticks" % CombatData.POSTURE_RECOVER_DELAY)
	for t in 60:
		_step(a, b, none, none)
	_check(b.posture < 50.0 and b.posture > 0.0, "posture recovers when unpressured (%.1f)" % b.posture)
	for t in 200:
		_step(a, b, none, none)
	_check(b.posture == 0.0, "posture fully recovered")

	# Being parried costs the attacker posture; at high posture it breaks them.
	for pre in [0.0, 90.0]:
		p = _make_pair()
		a = p[0]
		b = p[1]
		a.add_posture(pre)
		pr = CombatData.HitResult.WHIFF
		for t in 7:
			var r := _step(a, b, _intent(CombatData.AttackType.LIGHT) if t == 0 else none, parry_i if t == 3 else (hold if t > 3 else none))
			if r != CombatData.HitResult.WHIFF:
				pr = r
		var gain := jab.posture * CombatData.POSTURE_PARRIED_MULT + CombatData.POSTURE_PARRIED_FLAT
		if pre == 0.0:
			_check(pr == CombatData.HitResult.PARRIED and is_equal_approx(a.posture, gain), "being parried costs the attacker %.0f posture (%.0f)" % [gain, a.posture])
		else:
			_check(pr == CombatData.HitResult.GUARD_BREAK and a.state == Fighter.State.BROKEN, "parried at high posture: attacker's guard breaks (%s)" % CombatData.HitResult.keys()[pr])

	# Counter hits build posture but never break by themselves.
	p = _make_pair()
	a = p[0]
	b = p[1]
	a.stagger(-1)
	a.add_posture(95.0)
	var ch := a.receive_hit(jab, b, 1)
	_check(ch == CombatData.HitResult.HIT and a.last_hit_counter, "hit on a staggered fighter is a counter hit")
	_check(is_equal_approx(a.posture, CombatData.POSTURE_MAX - 1.0) and a.state == Fighter.State.HITSTUN, "a counter hit stops one point short of a break (%.0f)" % a.posture)

	print("[combo branches]")
	# Returns [chain step reached by the follow-up, tick it started].
	var chain_try := func(first: CombatData.AttackType, second: CombatData.AttackType, gap: float, press_at: int) -> Array:
		var pp := _make_pair()
		var x: Fighter = pp[0]
		var y: Fighter = pp[1]
		y.position.x = x.position.x + gap
		var seen_step := 0
		var started := -1
		for t in 60:
			var ia := _intent(first) if t == 0 else (_intent(second) if t == press_at else none)
			_step(x, y, ia, none)
			if t > 0 and x.state == Fighter.State.ATTACK and x.current_attack.type == second and started < 0:
				started = t
				seen_step = x.combo_step
		return [seen_step, started]
	var r1: Array = chain_try.call(CombatData.AttackType.LIGHT, CombatData.AttackType.HIGH_KICK, 80.0, 9)
	_check(r1[0] == 2, "jab (hit) -> W+L high kick chains as step 2 (%s)" % [r1])
	var r2: Array = chain_try.call(CombatData.AttackType.LIGHT, CombatData.AttackType.HEAVY, 80.0, 9)
	_check(r2[0] == 2 and r2[1] <= 12, "jab (hit) -> cross chains in the cancel window (%s)" % [r2])
	var r3: Array = chain_try.call(CombatData.AttackType.LIGHT, CombatData.AttackType.HEAVY, 220.0, 9)
	var jab_total := CombatData.get_attack(CombatData.AttackType.LIGHT).total_frames()
	_check(r3[0] == 0 or (r3[0] == 1 and r3[1] >= jab_total), "whiffed jab cannot cancel: full recovery first (%s)" % [r3])
	var r4: Array = chain_try.call(CombatData.AttackType.HEAVY, CombatData.AttackType.HEAVY, 80.0, 16)
	_check(r4[0] != 2, "cross -> cross is not a branch (%s)" % [r4])
	var r5: Array = chain_try.call(CombatData.AttackType.SWEEP, CombatData.AttackType.LIGHT, 80.0, 15)
	_check(r5[0] != 2, "sweep never chains (%s)" % [r5])
	# Every AI plan only uses listed branches.
	var plans_ok := true
	for plan in EnemyAI.CLOSE_PLANS + EnemyAI.FAR_PLANS:
		for i in range(1, plan.size()):
			if not CombatData.can_chain(plan[i - 1], plan[i]):
				plans_ok = false
				printerr("  AI plan uses an unlisted branch: %s" % [plan])
	_check(plans_ok, "every AI combo plan follows the branch table")

	print("[juggle limits]")
	p = _make_pair()
	a = p[0]
	b = p[1]
	a.ground_y = 560
	b.ground_y = 560
	b.position.x = 560
	var max_juggle := 0
	var knocked := false
	for t in 150:
		# Uppercut, then mash jabs: the juggle must end in a knockdown, never loop.
		var ja := CombatData.AttackType.UPPERCUT if t == 0 else (CombatData.AttackType.LIGHT if t >= 10 and t % 3 == 0 else CombatData.AttackType.NONE)
		_step(a, b, _intent(ja), none)
		max_juggle = maxi(max_juggle, b.received_combo)
		knocked = knocked or b.state == Fighter.State.KNOCKDOWN
	_check(max_juggle == CombatData.KNOCKDOWN_COMBO_HITS and knocked,
		"uppercut + mashed jabs: juggle reaches %d hits, then knockdown (max %d, knocked %s)" % [CombatData.KNOCKDOWN_COMBO_HITS, max_juggle, knocked])

	print("[contact-aware reach (visual)]")
	var fs: PackedScene = load("res://scenes/fighter.tscn")
	var va: Fighter = fs.instantiate()
	var vb: Fighter = fs.instantiate()
	root.add_child(va)
	root.add_child(vb)
	await process_frame
	va.position = Vector2(500, 560)
	vb.position = Vector2(565, 560)
	va.opponent = vb
	vb.opponent = va
	va.face_opponent()
	vb.face_opponent()
	va.ground_y = 560
	vb.ground_y = 560
	var vis: FighterVisual = va.get_node("Visual")
	va.current_attack = CombatData.get_attack(CombatData.AttackType.HEAVY)
	va.state = Fighter.State.ATTACK
	var strike: PackedFloat32Array = vis.get("_heavy_strike")
	var free_x: float = vis._solve_joints(strike)[FighterVisual.J_HAND_B].x
	var held_x: float = vis._solve_joints(vis._limit_reach(strike))[FighterVisual.J_HAND_B].x
	var limit_x := 65.0 - FighterVisual.BODY_HALF + FighterVisual.CONTACT_DEPTH
	_check(free_x > limit_x and held_x <= limit_x + 0.5,
		"point-blank cross stops at the body (free %.0f px -> %.0f px, limit %.0f)" % [free_x, held_x, limit_x])
	vb.position.x = 700.0
	_check(is_equal_approx(vis._solve_joints(vis._limit_reach(strike))[FighterVisual.J_HAND_B].x, free_x),
		"a strike with nothing in reach keeps its full extension")
	vb.position.x = 565.0
	vb.state = Fighter.State.DODGE
	vb.state_frame = CombatData.DODGE_INVULN_START + 1
	_check(is_equal_approx(vis._solve_joints(vis._limit_reach(strike))[FighterVisual.J_HAND_B].x, free_x),
		"a strike through a dodge passes freely")
	va.queue_free()
	vb.queue_free()

	print("[perfect dodge]")
	p = _make_pair()
	a = p[0]
	b = p[1]
	# Slip in toward the jab so it passes through the body during the i-frames.
	var slip_i := _intent()
	slip_i.dodge = -1
	var idle_at := -1
	for t in 20:
		_step(a, b, _intent(CombatData.AttackType.LIGHT) if t == 0 else none, slip_i if t == 1 else none)
		if idle_at < 0 and t > 0 and b.state != Fighter.State.DODGE:
			idle_at = t
	_check(b.dodge_perfect, "a strike passing through the i-frames counts as a perfect dodge")
	_check(idle_at > 0 and idle_at < CombatData.DODGE_FRAMES, "perfect dodge skips the recovery (free at tick %d < %d)" % [idle_at, CombatData.DODGE_FRAMES])

	print("[procedural audio]")
	var audio := GameAudio.new()
	root.add_child(audio)
	await process_frame  # _ready runs once the tree processes
	var all_sfx := true
	for snd in [&"whoosh_light", &"whoosh_heavy", &"jump", &"hit_light", &"hit_heavy", &"block", &"land",
			&"body_fall", &"wall_hit", &"roll", &"ko_boom", &"finisher_sting", &"count_tick", &"fight_call", &"parry", &"guard_break", &"finisher_drums", &"victory"]:
		if not audio.has_sound(snd):
			all_sfx = false
			printerr("missing sound ", snd)
	_check(all_sfx, "all 18 sound effects synthesized")
	var t0 := Time.get_ticks_msec()
	while not audio.is_bgm_playing() and Time.get_ticks_msec() - t0 < 20000:
		await process_frame
	var bgm_ms := Time.get_ticks_msec() - t0
	_check(audio.is_bgm_playing(), "background music rendered and playing (%d ms)" % bgm_ms)
	var expected_len := GameAudio.BGM_BARS * 4.0 * 60.0 / GameAudio.BGM_BPM
	_check(absf(audio.get_bgm_length() - expected_len) < 0.1, "fight music loop: 16 bars at 140 BPM = %.2f s (%.2f s)" % [expected_len, audio.get_bgm_length()])
	audio.queue_free()

	print("RESULT: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)
