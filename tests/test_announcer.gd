extends SceneTree
## Announcer: 3, 2, 1, FIGHT! once each on the countdown's own cues (FIGHT on
## the unlock tick), a pause between numbers adds nothing, training starts
## silently, and K.O. is said once when the round ends.

var _fails: int = 0


func _check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func _initialize() -> void:
	_run()


func _new_main() -> Node:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	return main


func _run() -> void:
	print("[countdown]")
	var main := _new_main()
	await physics_frame
	var audio: GameAudio = main.get_node("Audio")
	for id in GameAudio.VOICE_CLIPS:
		_check(ResourceLoader.exists(GameAudio.VOICE_CLIPS[id]), "clip %s exists" % id)
	main.call("confirm_style")
	main.call("start_match", false)
	var paused_once := false
	var said_at_fight: Array = []
	var t0 := Time.get_ticks_msec()
	while main.call("get_round_state_name") != "FIGHTING" and Time.get_ticks_msec() - t0 < 15000:
		await physics_frame
		if not paused_once and audio.announced.size() == 1:
			# Pause between "three" and "two": nothing more is said while frozen.
			paused_once = true
			main.call("toggle_pause")
			var n := audio.announced.size()
			for i in 20:
				await process_frame
			_check(audio.announced.size() == n, "paused: the countdown voice waits")
			main.call("toggle_pause")
	said_at_fight = audio.announced.duplicate()
	_check(said_at_fight == [&"three", &"two", &"one", &"fight"], "3, 2, 1, FIGHT! once each, in order (%s)" % [said_at_fight])
	_check(main.call("get_round_state_name") == "FIGHTING" and said_at_fight.back() == &"fight",
		"FIGHT is said on the tick the fighters unlock")
	for i in 30:
		await physics_frame
	_check(audio.announced.size() == 4, "nothing more during the fight")

	print("[K.O.]")
	main.call("_end_round")  # once per round, a double K.O. included
	_check(audio.announced.count(&"ko") == 1 and audio.announced.back() == &"ko", "K.O. is announced once when the round ends")
	main.queue_free()
	await process_frame

	print("[training]")
	main = _new_main()
	await physics_frame
	audio = main.get_node("Audio")
	main.call("start_training")
	for i in 30:
		await physics_frame
	_check(audio.announced.is_empty(), "training starts without a countdown voice (%s)" % [audio.announced])
	main.queue_free()
	await process_frame

	print("RESULT: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)
