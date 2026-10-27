extends SceneTree
## Every style finisher, facing right and left, from a 120 px gap: each blow
## must land with its intended limb within FinisherDirector.CONTACT_SLOP of the
## victim's drawn body, each hit beat must emit exactly once, and the finisher
## must complete. Contact is measured on the drawn skeleton (FighterVisual
## draws headless too); a case where nothing was drawn fails rather than
## passing on the fallback.

const STYLES := {
	&"boxing": [&"final_bell", &"eight_count"], &"taekwondo": [&"cyclone_360", &"heavens_heel"],
	&"muay_thai": [&"eight_limbs", &"iron_knee"], &"karate": [&"one_inch_verdict", &"crimson_crescent"],
	&"kung_fu": [&"hundred_palms", &"dragons_descent"], &"kickboxing": [&"last_combination", &"knockout_rhythm"],
	&"bangla_maar": [&"paaye_lathi", &"super_chor"],
}
const START_GAP: float = 120.0
const CASE_TICKS: int = 260

var _cases: Array = []
var _case: int = -1
var _frame: int = 0
var _main: Node = null
var _fin = null
var _events: int = 0
var _fails: int = 0


func _initialize() -> void:
	for style in STYLES:
		for fid in STYLES[style]:
			for left in [false, true]:
				_cases.append([style, fid, left])
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
		_main.call("start_match", true)
		(_main.get_node("EnemyAI") as EnemyAI).setup(null, null)
	if _frame == 30:
		e.position.x = 720.0
		p.position.x = e.position.x + (START_GAP if c[2] else -START_GAP)
		p.face_opponent()
		e.face_opponent()
		p.reset_physics_interpolation()
		e.reset_physics_interpolation()
		e.health = 0
		_main.call("_start_finisher", p, e, FinisherDirector.kind_for_id(c[1]))
		_fin = _main.get("_finisher")
	if _frame == CASE_TICKS:
		_report(c)
		_next_case()
	return false


func _report(c: Array) -> void:
	var label := "%s %s %s" % [c[0], c[1], "left" if c[2] else "right"]
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
