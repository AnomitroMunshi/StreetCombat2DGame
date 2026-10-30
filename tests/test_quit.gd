extends SceneTree
## QUIT: on the style-select home screen, pre-match, pause and result screens
## (with SETTINGS), never mid-fight; the first press only asks (CONFIRM QUIT)
## and the question lapses after QUIT_CONFIRM_TIME. Leaving training with Esc
## or a controller's Back reloads the scene without touching a freed viewport.

var _fails := 0


func _check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	var hud: Node = main.get("hud")
	var button: Button = hud.get("_quit_button")
	_check(hud.is_quit_button_visible(), "QUIT on the style-select home screen")
	main.call("select_style", &"karate")
	main.call("confirm_style")
	_check(hud.is_quit_button_visible(), "QUIT on the pre-match screen")
	_check(button.position.x < 100.0 and button.position.y > 600.0, "bottom left, clear of SETTINGS")
	button.pressed.emit()
	_check(button.text == "CONFIRM QUIT" and not main.is_queued_for_deletion(), "the first press only asks")
	hud.call("_disarm_quit")
	_check(button.text == "QUIT", "the question lapses")
	main.call("start_match", true)
	await physics_frame
	_check(not hud.is_quit_button_visible(), "no QUIT mid-fight")
	main.call("toggle_pause")
	_check(hud.is_quit_button_visible(), "QUIT on the pause screen")
	main.call("toggle_pause")
	_check(not hud.is_quit_button_visible(), "gone again on resume")
	paused = false

	# Training: Esc leaves (scene reload) without a freed-viewport error.
	main.queue_free()
	await process_frame
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	main.call("select_style", &"karate")
	main.call("start_training")
	await physics_frame
	_check(main.get("training") != null, "training started")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	main.call("_unhandled_input", esc)
	for i in 4:
		await process_frame
	_check(current_scene != null and current_scene != main, "the scene reloaded")
	print("RESULT: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)
