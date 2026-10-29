extends SceneTree
## Requested Capoeira mobility/status and JKD rapid hands through real ticks.
var failures := 0

func check(ok: bool, message: String) -> void:
	print("ok " if ok else "FAIL ", message)
	if not ok: failures += 1

func pair(id: StringName, side: int) -> Array[Fighter]:
	var a := Fighter.new()
	var b := Fighter.new()
	root.add_child(a)
	root.add_child(b)
	a.position = Vector2(640 - 40 * side, 560)
	b.position = Vector2(640 + 40 * side, 560)
	a.ground_y = 560
	b.ground_y = 560
	a.opponent = b
	b.opponent = a
	a.set_style(StyleRegistry.by_id(id))
	b.set_style(StyleRegistry.by_id(&"karate"))
	a.face_opponent()
	b.face_opponent()
	return [a, b]

func dispose(p: Array[Fighter]) -> void:
	for f in p: f.free()

func attack_contacts(p: Array[Fighter], slot: StringName, block := false, crouch := false) -> Array:
	var intent := CombatData.Intent.new()
	intent.slot = slot
	p[0].push_intent(intent)
	var hits: Array = []
	for tick in 100:
		var defense := CombatData.Intent.new()
		defense.block = block
		defense.crouch = crouch
		p[1].push_intent(defense)
		p[0].tick()
		p[1].tick()
		if p[0].is_hitbox_active() and not p[0].swing_has_hit and p[1].can_be_hit() and p[0].get_hitbox_world().intersects(p[1].get_hurtbox_world()):
			var attack := p[0].current_attack
			var result := p[1].receive_hit(attack, p[0], 1)
			p[0].confirm_hit(result)
			hits.append([attack.id, tick + 1, result])
	return hits

func hands(side: int) -> void:
	var p := pair(&"jeet_kune_do", side)
	var hits := attack_contacts(p, &"light")
	check(hits.size() == 2 and hits[0][0] == &"jkd_chain_jab" and hits[1][0] == &"jkd_chain_cross", "one J input produces alternating jab and cross")
	check(hits.size() == 2 and hits[0][1] == 4 and hits[1][1] - hits[0][1] <= 8, "rapid hands start after 3 ticks and follow promptly")
	check(p[1].health == p[1].max_health - 12 and p[0].focus < CombatData.FOCUS_MAX, "jab-cross deals 12 total without requiring Focus")
	check(p[0].style.can_chain(CombatData.AttackType.JKD_CHAIN_CROSS, CombatData.AttackType.JKD_HAMMERFIST), "only final automatic strike exposes parent cancel routes")
	dispose(p)
	p = pair(&"jeet_kune_do", side)
	hits = attack_contacts(p, &"light", true)
	check(hits.size() == 2 and hits.all(func(hit): return hit[2] == CombatData.HitResult.BLOCKED) and p[1].health == p[1].max_health, "both fast punches obey normal block")
	dispose(p)
	p = pair(&"jeet_kune_do", side)
	for type in [CombatData.AttackType.JKD_CHAIN_JAB, CombatData.AttackType.JKD_CHAIN_CROSS]:
		var raw := CombatData.Intent.new()
		raw.attack = type
		p[0].push_intent(raw)
		p[0].tick()
		check(p[0].state == Fighter.State.IDLE, "internal rapid hand cannot be injected directly")
	var start := CombatData.Intent.new()
	start.slot = &"light"
	p[0].push_intent(start)
	p[0].tick()
	p[0].receive_hit(CombatData.get_attack(CombatData.AttackType.LIGHT), p[1], 1)
	for tick in 30: p[0].tick()
	check(not p[0].is_mid_sequence() and p[1].health == p[1].max_health, "interrupting jab drops the remaining cross")
	dispose(p)
	for crouch in [false, true]:
		p = pair(&"jeet_kune_do", side)
		hits = attack_contacts(p, &"heavy", true, crouch)
		check(hits.size() == 1 and (p[1].health < p[1].max_health if crouch else p[1].health == p[1].max_health), "hammerfist is an overhead; standing guard stops it")
		dispose(p)

func statuses(side: int) -> void:
	for spec in [[&"capoeira", &"technique"], [&"jeet_kune_do", &"up_heavy"]]:
		var p := pair(spec[0], side)
		var move := CombatData.get_attack(p[0].style.resolve(spec[1], false))
		var result := p[1].receive_hit(move, p[0], 1)
		check(result == CombatData.HitResult.HIT and p[1].dizzy_left > 0, "%s clean hit schedules dizzy" % spec[0])
		p[1].dizzy_left = 0
		p[1].dizzy_immunity = 100
		p[1].received_combo = 0
		p[1].receive_hit(move, p[0], 1)
		check(p[1].dizzy_left == 0, "stun immunity prevents repeated stun loops")
		dispose(p)
		p = pair(spec[0], side)
		p[1].call("_enter_state", Fighter.State.BLOCK)
		p[1].block_held = true
		p[1].parry_window = 0
		p[1].state_frame = CombatData.BLOCK_STARTUP_FRAMES
		result = p[1].receive_hit(move, p[0], 1)
		check(result == (CombatData.HitResult.GUARD_BREAK if spec[0] == &"jeet_kune_do" else CombatData.HitResult.BLOCKED) and p[1].dizzy_left == 0, "hook breaks guard; cartwheel blocks normally; neither stuns through guard")
		dispose(p)
		p = pair(spec[0], side)
		p[1].call("_enter_state", Fighter.State.BLOCK)
		p[1].block_held = true
		p[1].parry_window = 4
		check(p[1].receive_hit(move, p[0], 1) == CombatData.HitResult.PARRIED, "stun and guard-break moves remain parryable")
		dispose(p)
	var p := pair(&"capoeira", side)
	var hits := attack_contacts(p, &"down_heavy")
	check(hits.size() == 1 and p[1].knockdown_cause == &"move", "Capoeira low sweep knocks opponent off feet")
	dispose(p)
	p = pair(&"capoeira", side)
	hits = attack_contacts(p, &"down_heavy", true, true)
	check(hits.size() == 1 and hits[0][2] == CombatData.HitResult.BLOCKED and p[1].knockdown_cause == &"", "low guard stops sweep without knockdown")
	dispose(p)

func crossover(side: int, wall: bool) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	var p: Fighter = main.player
	var e: Fighter = main.enemy
	p.set_style(StyleRegistry.by_id(&"capoeira"))
	e.set_style(StyleRegistry.by_id(&"karate"))
	e.position = Vector2((Fighter.ARENA_MAX_X - 50 if side == 1 else Fighter.ARENA_MIN_X + 50) if wall else 640, 560)
	p.position = e.position - Vector2(side * 110, 0)
	p.ground_y = 560
	e.ground_y = 560
	p.face_opponent()
	e.face_opponent()
	var was_air := false
	var crossed := false
	var vulnerable := false
	var facing_locked := true
	for tick in 100:
		var intent := CombatData.Intent.new()
		intent.move = side if not was_air or p.airborne else 0
		intent.jump = tick == 0
		p.push_intent(intent)
		p.tick()
		e.tick()
		main.call("_resolve_pushboxes")
		if p.cap_roll_jump:
			vulnerable = vulnerable or p.can_be_hit()
			p.face_opponent()
			facing_locked = facing_locked and p.facing == side
		if p.airborne: was_air = true
		crossed = crossed or (p.position.x - e.position.x) * side > 0
	check(was_air and crossed and (p.position.x - e.position.x) * side >= 59.5, "rolling jump crosses opponent and separates on landing, wall%s" % wall)
	check(vulnerable and facing_locked and not p.cap_roll_jump and not p.airborne, "roll stays vulnerable, retains takeoff facing in air, and clears on landing")
	check(p.position.x >= Fighter.ARENA_MIN_X and p.position.x <= Fighter.ARENA_MAX_X and e.position.x >= Fighter.ARENA_MIN_X and e.position.x <= Fighter.ARENA_MAX_X, "crossover keeps both roots inside walls")
	check(p.facing == -side, "landed Capoeira turns back toward opponent")
	main.free()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(StyleRegistry.rejected().is_empty(), "style definitions validate")
	for side in [1, -1]:
		hands(side)
		statuses(side)
		crossover(side, false)
		crossover(side, true)
	var p := pair(&"jeet_kune_do", 1)
	var intent := CombatData.Intent.new()
	intent.move = 1
	intent.jump = true
	p[0].push_intent(intent)
	for tick in 12: p[0].tick()
	check(p[0].airborne and not p[0].cap_roll_jump, "JKD retains ordinary jump")
	dispose(p)
	print("RESULT: ", "PASS" if failures == 0 else "FAIL", " agile styles: ", failures, " failures")
	quit(0 if failures == 0 else 1)
