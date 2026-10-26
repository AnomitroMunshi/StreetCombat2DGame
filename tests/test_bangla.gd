extends SceneTree
## Bangla Maar: the relaxed stance, the shove's 20% knockdown (seeded, never on
## block or through invulnerability, one roll per hit), the Belly Bomb (run-up,
## leap, bounce, short landing on contact, long on a miss), every move in both
## facing directions, its own finishers, and the speech bubble rules through
## the real scene (lines, priority, cooldown, once per event, Bengali font).

var _fails: int = 0


func _check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func _pair(gap: float, side: int, seed_value: int = 1) -> Array[Fighter]:
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
	a.set_style(StyleRegistry.by_id(&"bangla_maar"))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	b.set("_rng", rng)
	return [a, b]


func _free(p: Array[Fighter]) -> void:
	for f in p:
		f.queue_free()


func _attack(t: CombatData.AttackType) -> CombatData.Intent:
	var i := CombatData.Intent.new()
	i.attack = t
	return i


func _initialize() -> void:
	var st := StyleRegistry.by_id(&"bangla_maar")
	print("[style]")
	_check(st != null and st.validate().is_empty(), "Bangla Maar is registered and valid")
	_check(StyleRegistry.count() == 7, "seven styles (%d)" % StyleRegistry.count())
	var guard := Stances.pose(st.stance)
	_check(guard[2] < 0.9 and guard[4] < 0.9, "relaxed stance: neither hand raised into a guard (ua %.2f / %.2f)" % [guard[2], guard[4]])

	print("[every move, both directions]")
	for mid in [&"light_slap", &"thrust_kick", &"double_push", &"head_elbow", &"hammer_fist", &"stomach_shot", &"leg_kick",
			&"flying_slap", &"flying_chest_kick", &"belly_bomb"]:
		var res := []
		for side in [1, -1]:
			var gap := 150.0 if mid == &"belly_bomb" else (130.0 if mid.begins_with("flying") else 85.0)
			var p := _pair(gap, side)
			var a := p[0]
			var b := p[1]
			a.push_intent(_attack(CombatData.type_for_id(mid)))
			var hits := 0
			for t in 80:
				a.tick()
				b.tick()
				if a.is_hitbox_active() and a.get_hitbox_world().intersects(b.get_hurtbox_world()):
					var r := b.receive_hit(a.current_attack, a, a.combo_step)
					if r == CombatData.HitResult.HIT:
						hits += 1
					a.confirm_hit(r)
			res.append([hits, b.health])
			_free(p)
		_check(res[0][0] == 1 and res[0] == res[1], "%s hits once, same either way (%s)" % [mid, res])

	print("[double-hand push]")
	var push := CombatData.get_attack(CombatData.AttackType.DOUBLE_PUSH)
	var downs := 0
	var trials := 400
	for k in trials:
		var p := _pair(80.0, 1, 1000 + k)
		var r := p[1].receive_hit(push, p[0], 1)
		if r == CombatData.HitResult.HIT and p[1].state == Fighter.State.KNOCKDOWN:
			downs += 1
		_free(p)
	_check(downs > trials * 0.14 and downs < trials * 0.26, "a clean shove knocks down about 20%% of the time (%d / %d, seeded)" % [downs, trials])
	var p2 := _pair(80.0, 1, 7)
	var x0 := p2[1].position.x
	p2[1].receive_hit(push, p2[0], 1)
	for t in 30:
		p2[1].tick()
	var clean_push := p2[1].position.x - x0
	_free(p2)
	var blocked_down := 0
	var block_push := 0.0
	for k in 100:
		var p := _pair(80.0, 1, 2000 + k)
		var b := p[1]
		b.block_held = true
		b.call("_enter_state", Fighter.State.BLOCK)
		b.state_frame = 5
		var bx := b.position.x
		var r := b.receive_hit(push, p[0], 1)
		if r != CombatData.HitResult.BLOCKED or b.state == Fighter.State.KNOCKDOWN:
			blocked_down += 1
		for t in 30:
			b.tick()
		block_push = b.position.x - bx
		_free(p)
	_check(blocked_down == 0, "a blocked shove never knocks down (%d / 100)" % blocked_down)
	_check(block_push < clean_push * 0.7, "blocking cuts the push (%.0f px vs %.0f px)" % [block_push, clean_push])
	var p3 := _pair(80.0, 1, 3)
	p3[1].call("_enter_state", Fighter.State.DODGE)
	p3[1].state_frame = CombatData.DODGE_INVULN_START
	_check(p3[1].receive_hit(push, p3[0], 1) == CombatData.HitResult.WHIFF and p3[1].state == Fighter.State.DODGE,
		"invulnerable frames: the shove passes through, no knockdown")
	_free(p3)
	# One roll per hit: the same seed always gives the same outcome.
	var outcomes := []
	for rep in 2:
		var seq := ""
		for k in 20:
			var p := _pair(80.0, 1, 5000 + k)
			p[1].receive_hit(push, p[0], 1)
			seq += "D" if p[1].state == Fighter.State.KNOCKDOWN else "-"
			_free(p)
		outcomes.append(seq)
	_check(outcomes[0] == outcomes[1], "reproducible with a fixed seed (%s)" % outcomes[0])

	print("[belly bomb]")
	for case in [[150.0, true], [260.0, false]]:
		var p := _pair(case[0], 1)
		var a := p[0]
		var b := p[1]
		var start_x := a.position.x
		a.push_intent(_attack(CombatData.AttackType.BELLY_BOMB))
		var min_x := start_x
		var hit := false
		var bounced := false
		var land_lag := -1
		var knocked := false
		for t in 120:
			a.tick()
			b.tick()
			min_x = minf(min_x, a.position.x)
			if a.is_hitbox_active() and a.get_hitbox_world().intersects(b.get_hurtbox_world()):
				var r := b.receive_hit(a.current_attack, a, 1)
				a.confirm_hit(r)
				hit = hit or r == CombatData.HitResult.HIT
				bounced = bounced or a.jump_vx * a.facing < 0.0
			knocked = knocked or b.state == Fighter.State.KNOCKDOWN
			if a.state == Fighter.State.LAND and land_lag < 0:
				land_lag = a.stun_frames
		_check(min_x < start_x - 25.0, "belly bomb steps back first (%.0f px)" % (start_x - min_x))
		if case[1]:
			_check(hit and bounced and knocked and land_lag <= 12,
				"belly bomb in range: belly-first hit, heavy knockback, bounces off, quick landing (lag %d)" % land_lag)
		else:
			_check(not hit and land_lag >= 20, "belly bomb whiff: long recovery (lag %d)" % land_lag)
		_free(p)

	print("[finishers]")
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var p4 := _pair(80.0, 1)
	var picked := {}
	for i in 60:
		picked[FinisherDirector.choose(p4[0], p4[1], null, rng)] = true
	_check(picked.size() == 2 and picked.has(FinisherDirector.Kind.PAAYE_LATHI) and picked.has(FinisherDirector.Kind.SUPER_CHOR),
		"open floor: only Paaye Lathi and Super Chor (%s)" % [picked.keys()])
	_free(p4)

	print("[speech font]")
	var font := Hud.make_speech_font()
	_check(font.has_char(0x0986) and font.has_char(0x09CB), "speech font has Bengali glyphs (%s)" % (font as SystemFont).get_font_name())

	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var d := Driver.new()
	d.tree = self
	d.fails = _fails
	d.process_physics_priority = -100
	root.add_child(d)


class Driver extends Node:
	var tree: SceneTree
	var frame := 0
	var fails := 0
	var said: Dictionary = {}

	func check(cond: bool, msg: String) -> void:
		print(("  ok   " if cond else "  FAIL ") + msg)
		if not cond:
			fails += 1

	func _physics_process(_d: float) -> void:
		frame += 1
		var main := tree.current_scene
		var p: Fighter = main.get_node("Player")
		var e: Fighter = main.get_node("Enemy")
		var st := StyleRegistry.by_id(&"bangla_maar")
		if frame == 1:
			print("[speech bubbles]")
			main.call("select_style", &"bangla_maar")
			main.call("start_match", true)
			(main.get_node("EnemyAI") as EnemyAI).setup(null, null)
		if frame == 3:
			check(main.call("speech_text", p) == st.quotes["match_start"], "match start line")
			check(main.call("speech_text", e) == "", "a rival without lines stays silent")
		var jab := CombatData.get_attack(CombatData.AttackType.LIGHT)
		var slap := CombatData.get_attack(CombatData.AttackType.LIGHT_SLAP)
		match frame:
			5:
				# A lower-priority line never replaces a showing one.
				main.call("_speech_on_hit", CombatData.HitResult.HIT, jab, e, p)
				check(main.call("speech_text", p) == st.quotes["match_start"], "'hurt' does not interrupt the opening line")
			100:
				check(main.call("speech_text", p) == "", "bubble gone after its time")
				main.call("_speech_on_hit", CombatData.HitResult.HIT, jab, e, p)
				check(main.call("speech_text", p) == "", "quiet during the cooldown")
			200:
				main.call("_speech_on_hit", CombatData.HitResult.HIT, slap, p, e)
				check(main.call("speech_text", p) == st.quotes["slap"], "slap lands: the slap line")
				for k in 5:  # the same event repeated: one bubble, no restart
					main.call("_speech_on_hit", CombatData.HitResult.HIT, slap, p, e)
				said["slap_ticks"] = (main.get("_speech")[p] as Dictionary)["ticks"]
			202:
				check((main.get("_speech")[p] as Dictionary)["ticks"] < said["slap_ticks"], "a repeated event never restarts the bubble")
				p.health = 20
				main.call("_speech_on_hit", CombatData.HitResult.HIT, jab, e, p)
				check(main.call("speech_text", p) == st.quotes["low_health"], "low health: urgent line replaces the slap line")
			204:
				main.call("_speech_on_hit", CombatData.HitResult.HIT, jab, e, p)
				check(main.call("speech_text", p) == st.quotes["low_health"], "low-health line is said once and not cut off")
			400:
				main.call("_speech_on_hit", CombatData.HitResult.BLOCKED, jab, e, p)
				check(main.call("speech_text", p) == st.quotes["block"], "blocking line")
			560:
				p.health = 100
				p.position.x = 300.0
				e.position.x = 1000.0
				p.call("_enter_state", Fighter.State.IDLE)
				p.push_intent(_attack_intent(CombatData.AttackType.HAMMER_FIST))
			620:
				check(main.call("speech_text", p) == st.quotes["miss_heavy"], "whiffed hammer: the miss line (%s)" % main.call("speech_text", p))
				print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
				tree.quit(fails)

	func _attack_intent(t: CombatData.AttackType) -> CombatData.Intent:
		var i := CombatData.Intent.new()
		i.attack = t
		return i
