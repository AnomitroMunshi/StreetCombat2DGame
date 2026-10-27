extends SceneTree
## When a hit knocks down: a lone hit never rolls its random blowback; a combo
## follow-up or a counter hit can; certain blowbacks always apply; the
## KNOCKDOWN_COMBO_HITS-th hit of a combo always knocks down. Seeded.

var _fails: int = 0


func _check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func _pair(seed_value: int) -> Array[Fighter]:
	var a := Fighter.new()
	var b := Fighter.new()
	root.add_child(a)
	root.add_child(b)
	a.position = Vector2(600.0, 560.0)
	b.position = Vector2(680.0, 560.0)
	a.ground_y = 560.0
	b.ground_y = 560.0
	a.opponent = b
	b.opponent = a
	a.face_opponent()
	b.face_opponent()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	b.set("_rng", rng)
	return [a, b]


func _free(p: Array[Fighter]) -> void:
	for f in p:
		f.queue_free()


func _initialize() -> void:
	# The heaviest uncertain blowback in the game data.
	var heavy: CombatData.Attack = null
	var certain: CombatData.Attack = null
	for t in CombatData.AttackType.values():
		if t == CombatData.AttackType.NONE:
			continue
		var at := CombatData.get_attack(t)
		if at.blowback_chance > 0.0 and at.blowback_chance < 1.0 and not at.knockdown and at.stun == 0 \
				and (heavy == null or at.blowback_chance > heavy.blowback_chance):
			heavy = at
		if at.blowback_chance >= 1.0 and not at.knockdown and at.stun == 0 and certain == null:
			certain = at
	print("[%s: %.0f%% blowback]" % [heavy.display_name, heavy.blowback_chance * 100.0])
	var trials := 300
	var lone := 0
	var countered := 0
	var follow := 0
	for k in trials:
		var p := _pair(100 + k)
		p[1].receive_hit(heavy, p[0], 1)
		if p[1].state == Fighter.State.KNOCKDOWN:
			lone += 1
		_free(p)
		p = _pair(100 + k)
		p[1].call("_start_attack", CombatData.AttackType.HEAVY, 0, false)  # caught starting an attack
		p[1].receive_hit(heavy, p[0], 1)
		if p[1].state == Fighter.State.KNOCKDOWN and p[1].knockdown_cause == &"blowback":
			countered += 1
		_free(p)
		p = _pair(100 + k)
		p[1].receive_hit(CombatData.get_attack(CombatData.AttackType.LIGHT), p[0], 1)
		p[1].tick()
		p[1].receive_hit(heavy, p[0], 1)
		if p[1].state == Fighter.State.KNOCKDOWN and p[1].knockdown_cause == &"blowback":
			follow += 1
		_free(p)
	var expect := heavy.blowback_chance * CombatData.BLOWBACK_CHANCE_SCALE
	_check(lone == 0, "a lone hit never knocks down (%d / %d)" % [lone, trials])
	_check(countered > trials * expect * 0.6 and countered < trials * expect * 1.4,
		"as a counter hit it can (%d / %d, expected ~%.0f)" % [countered, trials, trials * expect])
	_check(follow > trials * expect * 0.6 and follow < trials * expect * 1.4,
		"as a combo follow-up it can (%d / %d, expected ~%.0f)" % [follow, trials, trials * expect])

	if certain != null:
		print("[%s: certain blowback]" % certain.display_name)
		var p := _pair(5)
		p[1].receive_hit(certain, p[0], 1)
		_check(p[1].state == Fighter.State.KNOCKDOWN, "a certain blowback always knocks down, even alone")
		_free(p)

	print("[combo]")
	var p2 := _pair(9)
	var jab := CombatData.get_attack(CombatData.AttackType.LIGHT)
	var states := []
	for k in CombatData.KNOCKDOWN_COMBO_HITS:
		p2[1].receive_hit(jab, p2[0], 1)
		states.append(Fighter.State.keys()[p2[1].state])
		p2[1].tick()
	_check(states.back() == "KNOCKDOWN" and not "KNOCKDOWN" in states.slice(0, states.size() - 1),
		"hit %d of a combo knocks down, not before (%s)" % [CombatData.KNOCKDOWN_COMBO_HITS, states])
	_free(p2)

	print("RESULT: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)
