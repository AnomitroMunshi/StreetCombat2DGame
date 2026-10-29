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


## Runs `attack` from `gap` at a standing (or blocking) target: attacker
## travel, defender travel, final gap, hits, result, attacker travel after
## contact, whether the defender went down.
func _charge(attack: CombatData.Attack, gap: float, side: int, block: bool) -> Dictionary:
	var p := _pair(gap, side)
	var a: Fighter = p[0]
	var b: Fighter = p[1]
	var ax := a.position.x
	var bx := b.position.x
	var hits := 0
	var result := "-"
	var hit_x := INF
	var down := false
	if attack.signature:
		a.focus = CombatData.FOCUS_MAX
		a.push_intent(_attack(attack.type))
	else:
		a.call("_start_attack", attack.type, 0, true)
	for t in 70:
		var i := CombatData.Intent.new()
		i.block = block
		b.push_intent(i)
		a.tick()
		b.tick()
		var d := (b.position.x - a.position.x) * side
		if d < Fighter.PUSH_HALF_WIDTH * 2.0:
			var push := (Fighter.PUSH_HALF_WIDTH * 2.0 - d) * 0.5 * side
			a.position.x -= push
			b.position.x += push
		if a.state == Fighter.State.ATTACK and a.is_hitbox_active() and not a.swing_has_hit 				and a.get_hitbox_world().intersects(b.get_hurtbox_world()):
			var r := b.receive_hit(a.current_attack, a, 0)
			a.confirm_hit(r)
			hits += 1
			result = CombatData.HitResult.keys()[r]
			hit_x = a.position.x
		down = down or b.state == Fighter.State.KNOCKDOWN
	var out := {"attacker": (a.position.x - ax) * side, "defender": (b.position.x - bx) * side,
		"gap": (b.position.x - a.position.x) * side, "hits": hits, "result": result, "down": down,
		"after_hit": absf(a.position.x - hit_x) if hit_x != INF else 0.0}
	_free(p)
	return out


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
	if CombatData.get_attack(t).signature:
		i.signature = true
	else:
		i.attack = t
	return i


func _initialize() -> void:
	var st := StyleRegistry.by_id(&"bangla_maar")
	print("[style]")
	_check(st != null and st.validate().is_empty(), "Bangla Maar is registered and valid")
	_check(StyleRegistry.count() == 9, "nine styles (%d)" % StyleRegistry.count())
	var guard := Stances.pose(st.stance)
	_check(guard[2] < 0.9 and guard[4] < 0.9, "relaxed stance: neither hand raised into a guard (ua %.2f / %.2f)" % [guard[2], guard[4]])

	print("[every move, both directions]")
	for mid in [&"street_punch", &"thrust_kick", &"jor_dhakka", &"head_elbow", &"hammer_fist", &"stomach_shot", &"leg_kick",
			&"flying_slap", &"flying_chest_kick", &"belly_bomb"]:
		var res := []
		for side in [1, -1]:
			var gap := 150.0 if mid == &"belly_bomb" else (130.0 if mid.begins_with("flying") else 85.0)
			var p := _pair(gap, side)
			var a := p[0]
			var b := p[1]
			if CombatData.get_attack(CombatData.type_for_id(mid)).signature:
				a.focus = CombatData.FOCUS_MAX
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

	print("[jor dhakka]")
	var jd := CombatData.get_attack(CombatData.AttackType.JOR_DHAKKA)
	_check(StyleRegistry.by_id(&"bangla_maar").resolve(&"technique", false) == CombatData.AttackType.JOR_DHAKKA
		and jd.display_name == "Jor Dhakka", "L is Jor Dhakka")
	_check(jd.blowback_chance == 0.0 and not jd.knockdown, "no random knockdown inherited from the old shove")
	_check(jd.recovery >= 24, "a long recovery: punishable on a miss (%d)" % jd.recovery)
	var downs := 0
	for k in 200:
		var p := _pair(80.0, 1, 1000 + k)
		if p[1].receive_hit(jd, p[0], 1) == CombatData.HitResult.HIT and p[1].state == Fighter.State.KNOCKDOWN:
			downs += 1
		_free(p)
	_check(downs == 0, "a clean shoulder bash never knocks down (%d / 200, seeded)" % downs)
	for side in [1, -1]:
		var dir := "facing right" if side == 1 else "facing left"
		var res := _charge(jd, 150.0, side, false)
		_check(res["hits"] == 1, "one shoulder hit from 150 px (%d, %s)" % [res["hits"], dir])
		_check(res["attacker"] > 40.0 and res["defender"] > 70.0 and res["gap"] > 140.0,
			"closes in, heavy knockback, space made (attacker +%.0f, defender +%.0f, gap %.0f, %s)" % [res["attacker"], res["defender"], res["gap"], dir])
		_check(res["after_hit"] < 1.0, "the charge stops on contact: no chasing the body (%.1f px, %s)" % [res["after_hit"], dir])
		var blk := _charge(jd, 150.0, side, true)
		_check(blk["result"] == "GUARD_BREAK" and not blk["down"],
			"blocked: the charge breaks the guard, never a knockdown (%s, %s)" % [blk["result"], dir])
		var miss := _charge(jd, 260.0, side, false)
		_check(miss["hits"] == 0 and miss["attacker"] > 60.0 and miss["attacker"] < 110.0,
			"a miss: bounded charge (%.0f px), no hit (%s)" % [miss["attacker"], dir])
	print("[jor dhakka: off balance]")
	for side in [1, -1]:
		var po := _pair(80.0, side, 21)
		var r0 := po[1].receive_hit(jd, po[0], 1)
		_check(r0 == CombatData.HitResult.HIT and po[1].state == Fighter.State.STAGGER and po[1].stun_frames == jd.off_balance
			and po[1].thrown_off_balance, "a clean hit throws them off balance for %d ticks (facing %d, %s)" % [jd.off_balance, side, po[1].get_state_name()])
		_check(absf(po[1].velocity_x) > 5.0, "the knockback is kept while they reel (%.1f px/tick)" % po[1].velocity_x)
		po[1].receive_hit(CombatData.get_attack(CombatData.AttackType.STREET_PUNCH), po[0], 1)
		_check(po[1].last_hit_counter, "a follow-up on the reeling opponent is a counter hit")
		_free(po)
	var pq := _pair(80.0, 1, 22)
	pq[1].block_held = true
	pq[1].parry_buffer_frames = 3
	pq[1].call("_enter_block")
	_check(pq[1].receive_hit(jd, pq[0], 1) == CombatData.HitResult.PARRIED, "a parry still beats Jor Dhakka")
	_free(pq)
	var p3 := _pair(80.0, 1, 3)
	p3[1].call("_enter_state", Fighter.State.DODGE)
	p3[1].state_frame = CombatData.DODGE_INVULN_START
	_check(p3[1].receive_hit(jd, p3[0], 1) == CombatData.HitResult.WHIFF and p3[1].state == Fighter.State.DODGE,
		"invulnerable frames: the bash passes through")
	_free(p3)

	print("[guard breaker]")
	var hammer := CombatData.get_attack(CombatData.AttackType.HAMMER_FIST)
	var only := 0
	for st2 in StyleRegistry.all():
		for m in st2.moves():
			if CombatData.get_attack(CombatData.type_for_id(m)).guard_break:
				only += 1 if st2.id == &"bangla_maar" else 100
	_check(only == 2, "exactly two guard breakers in the game, both Bangla Maar's: the hammer and Jor Dhakka (%d)" % only)
	for side in [1, -1]:
		var pg := _pair(80.0, side)
		var g := pg[1]
		g.block_held = true
		g.call("_enter_state", Fighter.State.BLOCK)
		g.state_frame = 5
		var r := g.receive_hit(hammer, pg[0], 1)
		_check(r == CombatData.HitResult.GUARD_BREAK and g.state == Fighter.State.BROKEN,
			"a blocked hammer breaks the guard outright (facing %d, %s)" % [side, CombatData.HitResult.keys()[r]])
		_free(pg)
	var pp := _pair(80.0, 1)
	pp[1].block_held = true
	pp[1].parry_buffer_frames = 3
	pp[1].call("_enter_block")
	_check(pp[1].receive_hit(hammer, pp[0], 1) == CombatData.HitResult.PARRIED, "a parry still beats the hammer")
	_free(pp)
	var pb := _pair(80.0, 1)
	var gb := pb[1]
	gb.block_held = true
	gb.call("_enter_state", Fighter.State.BLOCK)
	gb.state_frame = 5
	var r_jab := gb.receive_hit(CombatData.get_attack(CombatData.AttackType.LIGHT_SLAP), pb[0], 1)
	_check(r_jab == CombatData.HitResult.BLOCKED, "other Bangla Maar moves are ordinary blocks")
	_free(pb)

	print("[belly bomb]")
	for case in [[150.0, true], [260.0, false]]:
		var p := _pair(case[0], 1)
		var a := p[0]
		var b := p[1]
		var start_x := a.position.x
		a.focus = CombatData.FOCUS_MAX
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
		_finisher_checks(main, p, e, st)

	## Both finishers through the real scene: the line, the blow landing with the
	## limb on the head, Paaye Lathi's head-toward-attacker fall and slide.
	func _finisher_checks(main: Node, p: Fighter, e: Fighter, st: MartialArtStyle) -> void:
		var kinds := [FinisherDirector.Kind.PAAYE_LATHI, FinisherDirector.Kind.SUPER_CHOR]
		var starts := [700, 1060]
		for i in 2:
			var f0: int = starts[i]
			if frame == f0 - 40 and i == 1:
				main.call("restart_match")
			if frame == f0 - 20 and i == 1:
				main.call("select_style", &"bangla_maar")
				e.set_style(StyleRegistry.by_id(&"bangla_maar"))  # a talking victim
				main.call("start_match", true)
				(main.get_node("EnemyAI") as EnemyAI).setup(null, null)
			if frame == f0:
				print("[%s]" % FinisherDirector.DISPLAY_NAMES[kinds[i]])
				p.position.x = 560.0
				e.position.x = 650.0
				p.call("_enter_state", Fighter.State.IDLE)
				e.call("_enter_state", Fighter.State.IDLE)
				p.face_opponent()
				e.face_opponent()
				e.health = 0
				said.erase("ko")
				said.erase("slid")
				main.call("_start_finisher", p, e, kinds[i])
			if frame == f0 + 2:
				check(main.call("speech_text", p) == st.quotes["finisher"], "finisher line: %s" % main.call("speech_text", p))
			if frame > f0 and frame < f0 + 300:
				if e.state == Fighter.State.KO and not said.has("ko"):
					said["ko"] = true
					var pj: PackedVector2Array = (p.get_node("Visual") as FighterVisual).get("_last_joints")
					var ej: PackedVector2Array = (e.get_node("Visual") as FighterVisual).get("_last_joints")
					var head: Vector2 = ej[FighterVisual.J_HEAD]
					if kinds[i] == FinisherDirector.Kind.PAAYE_LATHI:
						var toward := absf(head.x - p.position.x) < absf(ej[FighterVisual.J_HIP].x - p.position.x)
						check(e.script_flip and toward and head.y > e.ground_y - 45.0,
							"Paaye Lathi: lying on the floor, head towards the attacker (head %s, hip %s)" % [head, ej[FighterVisual.J_HIP]])
						var foot: Vector2 = pj[FighterVisual.J_FOOT_F]
						check(foot.distance_to(head) < 60.0, "Paaye Lathi: the punt lands with the foot on the head (%.0f px)" % foot.distance_to(head))
					else:
						var hand: Vector2 = pj[FighterVisual.J_HAND_F]
						check(hand.distance_to(head) < 25.0, "Super Chor: the open palm is on the face as the slap lands (%.0f px, hand %s head %s shoulder %s)" % [hand.distance_to(head), hand, head, pj[FighterVisual.J_SHOULDER_F]])
				if e.skidding:
					said["slid"] = true
				if i == 1 and said.has("ko") and frame == f0 + 120:
					check(main.call("speech_text", e) == st.quotes["knocked_out"], "knocked out: %s" % main.call("speech_text", e))
			if frame == f0 + 300:
				check(said.has("ko"), "%s knocks out" % FinisherDirector.DISPLAY_NAMES[kinds[i]])
				check(said.has("slid"), "%s: the body slides along the floor" % FinisherDirector.DISPLAY_NAMES[kinds[i]])
		if frame == starts[1] + 310:
			print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
			tree.quit(fails)

	func _attack_intent(t: CombatData.AttackType) -> CombatData.Intent:
		var i := CombatData.Intent.new()
		i.attack = t
		return i
