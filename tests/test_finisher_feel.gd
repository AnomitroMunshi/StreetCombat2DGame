extends SceneTree
## Finisher build-up (FIN-FEEL-01/04): a finisher whose knockout blow follows
## a wind-up holds its breath first (FinisherDirector.in_hush: slower playback,
## music ducked to near silence, camera leaning in) and then snaps into the
## blow at full speed; a chain whose last beat before the blow is itself a
## strike keeps its momentum (no hush). Playback speed only: the hit events
## and their order are unchanged.

var _fails := 0
var _cases := [[&"boxing", &"final_bell", true], [&"bangla_maar", &"super_chor", false]]
var _case := -1
var _main: Node = null
var _fin = null
var _frame := 0
var _hush_ticks := 0
var _hush_speed_ok := true
var _hush_duck_ok := true
var _strike_after_hush := -1.0
var _was_hush := false


func _check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func _initialize() -> void:
	_next()


func _next() -> void:
	if _main != null:
		_main.queue_free()
	_case += 1
	_frame = 0
	_fin = null
	_hush_ticks = 0
	_hush_speed_ok = true
	_hush_duck_ok = true
	_strike_after_hush = -1.0
	_was_hush = false
	if _case >= _cases.size():
		Engine.time_scale = 1.0
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
		e.set_style(StyleRegistry.by_id(&"karate"))
		_main.set("rounds_to_win", 1)
		_main.call("start_match", true)
		(_main.get_node("EnemyAI") as EnemyAI).setup(null, null)
	if _frame == 30:
		e.position.x = 720.0
		p.position.x = 600.0
		p.face_opponent()
		e.face_opponent()
		e.health = 0
		_main.call("_start_finisher", p, e, FinisherDirector.kind_for_id(c[1]))
		_fin = _main.get("_finisher")
	if _fin != null and _frame > 30 and not _fin.done:
		var audio := _main.get_node("Audio")
		if _fin.in_hush():
			_hush_ticks += 1
			_hush_speed_ok = _hush_speed_ok and is_equal_approx(_fin.playback_speed(), FinisherDirector.HUSH_SPEED)
			_hush_duck_ok = _hush_duck_ok and is_equal_approx(float(audio.get("_bgm_duck_db")), float(_main.FIN_HUSH_DUCK_DB))
		elif _was_hush and _strike_after_hush < 0.0:
			_strike_after_hush = _fin.playback_speed()
		_was_hush = _fin.in_hush()
	if _fin != null and (_fin.done or _frame > 600):
		if c[2]:
			_check(_hush_ticks >= FinisherDirector.HUSH_TICKS - 1, "%s holds its breath before the knockout (%d hush ticks)" % [c[1], _hush_ticks])
			_check(_hush_speed_ok, "%s: the hush plays slower" % c[1])
			_check(_hush_duck_ok, "%s: the music drops away in the hush" % c[1])
			_check(is_equal_approx(_strike_after_hush, 1.0), "%s: the knockout blow snaps in at full speed (%.2f)" % [c[1], _strike_after_hush])
		else:
			_check(_hush_ticks == 0, "%s keeps its chain's momentum (no hush)" % c[1])
		_check(_fin.done, "%s completes" % c[1])
		_next()
	return false
