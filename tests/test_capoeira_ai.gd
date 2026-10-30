extends SceneTree
## Capoeira's committed handstand X waits for observable openings.
var failures := 0

func check(ok: bool, message: String) -> void:
	print("ok " if ok else "FAIL ", message)
	if not ok: failures += 1

func pair(id: StringName, side: int) -> Array:
	var a := Fighter.new()
	var b := Fighter.new()
	var ai := EnemyAI.new()
	root.add_child(a)
	root.add_child(b)
	root.add_child(ai)
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
	ai.setup(a, b)
	return [a, b, ai]

func dispose(p: Array) -> void:
	for n in p: n.free()

func _initialize() -> void:
	for side in [1, -1]:
		var p := pair(&"capoeira", side)
		check(p[2].compute_intent().slot != &"x_move", "Capoeira does not spend long X into neutral")
		p[1].call("_enter_state", Fighter.State.ATTACK)
		p[1].current_attack = CombatData.get_attack(CombatData.AttackType.HEAVY)
		p[1].state_frame = 1
		check(p[2].compute_intent().slot != &"x_move", "visible enemy startup does not count as safe X opening")
		p[1].state_frame = p[1].current_attack.startup + p[1].current_attack.active
		check(p[2].compute_intent().slot == &"x_move", "visible long recovery permits Capoeira X")
		p[1].state_frame = p[1].current_attack.total_frames() - 2
		check(p[2].compute_intent().slot != &"x_move", "almost-ended recovery does not bait X")
		p[1].current_attack = null
		p[1].call("_enter_state", Fighter.State.DIZZY)
		p[1].dizzy_left = 60
		check(p[2].compute_intent().slot == &"x_move", "stun permits X as a visible punish")
		p[0].x_cooldown = 10
		check(p[2].compute_intent().slot != &"x_move", "opening does not bypass X cooldown")
		p[0].x_cooldown = 0
		var intent := CombatData.Intent.new()
		intent.slot = &"x_move"
		p[0].push_intent(intent)
		p[0].tick()
		var cd: int = p[0].x_cooldown
		p[0].receive_hit(CombatData.get_attack(CombatData.AttackType.LIGHT), p[1], 1)
		check(p[0].state == Fighter.State.HITSTUN and cd == 900 and p[0].x_cooldown == cd, "X still interrupts normally and keeps cooldown")
		dispose(p)
		p = pair(&"jeet_kune_do", side)
		check(p[2].compute_intent().slot == &"x_move", "other styles retain their existing ready/in-range X policy")
		dispose(p)
	print("RESULT: ", "PASS" if failures == 0 else "FAIL", " Capoeira AI: ", failures, " failures")
	quit(0 if failures == 0 else 1)
