extends SceneTree
## AI signature use: with a full meter the AI walks into signature range and
## throws it (it does not wait for the opponent to wander in), and an opening
## (a dizzy opponent in range) draws it out at once. Seeded, every style.

var _fails: int = 0


func _check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func _setup(style: MartialArtStyle, gap: float, seed_value: int) -> Array:
	var me := Fighter.new()
	var target := Fighter.new()
	root.add_child(me)
	root.add_child(target)
	me.position = Vector2(640.0 - gap * 0.5, 560.0)
	target.position = Vector2(640.0 + gap * 0.5, 560.0)
	me.ground_y = 560.0
	target.ground_y = 560.0
	me.opponent = target
	target.opponent = me
	me.face_opponent()
	target.face_opponent()
	me.set_style(style)
	me.focus = CombatData.FOCUS_MAX
	var ai := EnemyAI.new()
	ai.rng_seed = seed_value
	root.add_child(ai)
	ai.setup(me, target)
	return [me, target, ai]


## Ticks until the AI starts its signature (-1 if it never does).
func _ticks_to_signature(p: Array, limit: int) -> int:
	var me: Fighter = p[0]
	var target: Fighter = p[1]
	var ai: EnemyAI = p[2]
	for t in limit:
		me.push_intent(ai.compute_intent())
		target.push_intent(CombatData.Intent.new())
		me.tick()
		target.tick()
		if me.in_signature:
			return t
	return -1


func _free(p: Array) -> void:
	for n in p:
		(n as Node).queue_free()


func _initialize() -> void:
	print("[full meter: walks in and throws it]")
	for st in StyleRegistry.all():
		var p := _setup(st, 320.0, 7)
		var t := _ticks_to_signature(p, 240)
		_check(t >= 0 and t < 240, "%s: signature within 4 s from 320 px against a passive opponent (%d ticks)" % [st.id, t])
		_free(p)

	print("[an opening draws it out]")
	for st in StyleRegistry.all():
		var p := _setup(st, 0.0, 11)
		var me: Fighter = p[0]
		var target: Fighter = p[1]
		# Just inside the signature's reach, opponent dizzy.
		var gap: float = minf((p[2] as EnemyAI).call("_signature_reach") - 10.0, 140.0)
		me.position.x = 640.0 - gap * 0.5
		target.position.x = 640.0 + gap * 0.5
		target.dizzy_left = 120
		target.call("_enter_state", Fighter.State.DIZZY)
		var t := _ticks_to_signature(p, 30)
		_check(t >= 0 and t <= 8, "%s: dizzy opponent in range -> signature at once (%d ticks)" % [st.id, t])
		_free(p)

	print("RESULT: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)
