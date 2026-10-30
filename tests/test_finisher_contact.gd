extends SceneTree
## Every style finisher, facing right and left, from a 120 px gap (wall
## finishers against both walls; airborne finishers on a victim rising, near
## the apex and falling, from 70 and 120 px): each blow
## must land with its intended limb within FinisherDirector.CONTACT_SLOP of the
## victim's drawn body, each hit beat must emit exactly once, and the finisher
## must complete. Contact is measured on the drawn skeleton (FighterVisual
## draws headless too); a case where nothing was drawn fails rather than
## passing on the fallback.

const STYLES := {
	&"boxing": [&"final_bell", &"eight_count", &"falling_cross", &"corner_count"],
	&"taekwondo": [&"cyclone_360", &"heavens_heel", &"skyfall_axe", &"corner_cyclone"],
	&"muay_thai": [&"eight_limbs", &"iron_knee", &"iron_corner"],
	&"karate": [&"one_inch_verdict", &"crimson_crescent", &"skyline_verdict"],
	&"kung_fu": [&"hundred_palms", &"dragons_descent", &"descending_dragon_palm", &"wall_of_palms"], &"kickboxing": [&"last_combination", &"knockout_rhythm", &"air_breaker", &"corner_breaker"],
	&"capoeira": [&"rodas_end", &"handstand_havoc", &"sky_wheel", &"corner_carnival"],
	&"jeet_kune_do": [&"one_inch_ending", &"no_second_chance", &"dragon_intercept", &"end_of_line"],
	&"bangla_maar": [&"paaye_lathi", &"super_chor", &"bangla_air_smash", &"deowal_dhakka"],
}
const START_GAP: float = 120.0
## Airborne cases: the victim's vertical speed when the finisher starts
## (rising, near the apex, falling) and the start gaps.
const AIR_VY: Array[float] = [-9.0, -2.0, 5.0]
const AIR_GAPS: Array[float] = [70.0, 120.0]
## Wall cases: how far the victim starts from the wall (WALL_RANGE is 170).
const WALL_DISTS: Array[float] = [60.0, 110.0, 160.0]
const CASE_TICKS: int = 260

var _cases: Array = []
var _case: int = -1
var _frame: int = 0
var _main: Node = null
var _fin = null
var _events: int = 0
## Wall cases: a wall impact reported while the victim was off the wall.
var _wall_early: int = 0
var _walls: int = 0
## The last finisher event already counted (main keeps it through hitstop).
var _seen_event: Dictionary = {}
var _fails: int = 0


func _initialize() -> void:
	# ONLY=<finisher id> runs that finisher's cases alone (tuning).
	var only := OS.get_environment("ONLY")
	for style in STYLES:
		if OS.get_environment("ONLY_STYLE") != "" and not String(style) in OS.get_environment("ONLY_STYLE").split(","):
			continue
		for fid in STYLES[style]:
			if only != "" and not String(fid) in only.split(","):
				continue
			var k := FinisherDirector.kind_for_id(fid)
			for left in [false, true]:
				if k in FinisherDirector.AIR_KINDS:
					for vy in AIR_VY:
						for gap in AIR_GAPS:
							_cases.append([style, fid, left, gap, vy])
				elif k in FinisherDirector.WALL_KINDS:
					for d in WALL_DISTS:
						_cases.append([style, fid, left, START_GAP, d])
				else:
					_cases.append([style, fid, left, START_GAP, 0.0])
	_next_case()


func _check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func _next_case() -> void:
	if _main != null:
		_main.queue_free()
		_main = null
	_case += 1
	_frame = 0
	_fin = null
	_events = 0
	_wall_early = 0
	_walls = 0
	if _case >= _cases.size():
		print("RESULT: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
		quit(1 if _fails > 0 else 0)
		return
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	current_scene = _main


func _physics_process(_delta: float) -> bool:
	if _main == null or _case >= _cases.size():
		return false
	_frame += 1
	var c: Array = _cases[_case]
	var p: Fighter = _main.get_node("Player")
	var e: Fighter = _main.get_node("Enemy")
	if _frame == 1:
		_main.call("select_style", c[0])
		e.set_style(StyleRegistry.by_id(&"boxing" if c[0] == &"karate" else &"karate"))
		_main.set("rounds_to_win", 1)  # one finisher per case: no next round resets the bodies
		_main.call("start_match", true)
		(_main.get_node("EnemyAI") as EnemyAI).setup(null, null)
	if _frame == 30:
		var k := FinisherDirector.kind_for_id(c[1])
		e.position.x = 720.0
		if k in FinisherDirector.WALL_KINDS:
			e.position.x = Fighter.ARENA_MIN_X + c[4] if c[2] else Fighter.ARENA_MAX_X - c[4]
		p.position.x = e.position.x + (c[3] if c[2] else -c[3])
		p.face_opponent()
		e.face_opponent()
		p.reset_physics_interpolation()
		e.reset_physics_interpolation()
		e.health = 0
		if k in FinisherDirector.AIR_KINDS:
			e.scripted_launch(-6.0)
			for i in 8:  # into its flight
				e.tick()
			e.velocity_y = c[4]
		_main.call("_start_finisher", p, e, k)
		_fin = _main.get("_finisher")
	if _fin != null and _frame > 30:
		var ev: Dictionary = _main.get("_last_finisher_event")
		var fresh := not is_same(ev, _seen_event)
		_seen_event = ev
		if fresh and ev.get("final", false) and c[0] == &"jeet_kune_do":
			_check(not ev.get("high", true), "JKD body finisher emits body-hit feedback")
		if fresh and not ev.is_empty() and ev.get("wall", false):
			_walls += 1
			var bound := Fighter.ARENA_MIN_X if c[2] else Fighter.ARENA_MAX_X
			if absf(e.position.x - bound) > FinisherDirector.AT_WALL:
				_wall_early += 1
	if _frame == CASE_TICKS:
		_report(c)
		_next_case()
	return false


func _report(c: Array) -> void:
	var label := "%s %s %s" % [c[0], c[1], "left" if c[2] else "right"]
	if FinisherDirector.kind_for_id(c[1]) in FinisherDirector.AIR_KINDS:
		label += " (gap %d, vy %+.0f)" % [c[3], c[4]]
	elif FinisherDirector.kind_for_id(c[1]) in FinisherDirector.WALL_KINDS:
		label += " (%d px from the wall)" % c[4]
	if _fin == null:
		_check(false, label + ": finisher started")
		return
	var hits := 0
	for b: Dictionary in _fin.get("_beats"):
		if b.get("hit", false):
			hits += 1
	var gaps: Array[float] = _fin.contact_gaps
	var worst := -INF
	var unmeasured := 0
	for g in gaps:
		if is_nan(g):
			unmeasured += 1
		else:
			worst = maxf(worst, g)
	_check(unmeasured == 0, label + ": every blow measured on the drawn bodies (%d unmeasured)" % unmeasured)
	_check(_fin.done, label + ": completes")
	_check(gaps.size() == hits, label + ": each of %d blows lands once (%d)" % [hits, gaps.size()])
	_check(worst <= FinisherDirector.CONTACT_SLOP and worst > -INF,
		label + ": every blow within %.0f px of the body (worst %.1f)" % [FinisherDirector.CONTACT_SLOP, worst])
	if worst > FinisherDirector.CONTACT_SLOP or c[1] == &"corner_carnival":
		print("  contact gaps by beat: ", gaps)
	var k := FinisherDirector.kind_for_id(c[1])
	var e: Fighter = _main.get_node("Enemy")
	if k in FinisherDirector.WALL_KINDS:
		_check(_walls > 0 and _wall_early == 0,
			label + ": the wall cracks only with the body against it (%d impacts, %d early)" % [_walls, _wall_early])
	if k in FinisherDirector.AIR_KINDS:
		_check(e.spiked and not e.airborne, label + ": the victim is driven into the floor and lands")
