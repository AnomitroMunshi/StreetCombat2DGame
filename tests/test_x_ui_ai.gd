extends SceneTree
## Real input edge and per-style AI readiness, plus public training readout.
var fails: int = 0

func check(ok: bool, message: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + message)
	if not ok:
		fails += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for st in StyleRegistry.all():
		for side in [-1, 1]:
			var me := Fighter.new()
			var target := Fighter.new()
			root.add_child(me)
			root.add_child(target)
			me.set_style(st)
			me.position = Vector2(640.0, 560.0)
			target.position = Vector2(640.0 + side * 65.0, 560.0)
			me.opponent = target
			target.opponent = me
			me.face_opponent()
			target.face_opponent()
			var ai := EnemyAI.new()
			root.add_child(ai)
			ai.setup(me, target)
			if st.id == &"capoeira":
				check(ai.compute_intent().slot != &"x_move", "Capoeira saves its committed X for an observable opening")
				target.dizzy_left = 70
				target.call("_enter_state", Fighter.State.DIZZY)
				ai.setup(me, target)
			check(ai.compute_intent().slot == &"x_move", "%s facing %d: ready AI chooses X in range" % [st.id, side])
			me.x_cooldown = 300
			check(ai.compute_intent().slot != &"x_move", "%s: AI waits for cooldown" % st.id)
			me.x_cooldown = 0
			target.position.x = 1100.0
			check(ai.compute_intent().slot != &"x_move", "%s: AI refuses out-of-range X" % st.id)
			var training := TrainingMode.new()
			root.add_child(training)
			training.setup(me, target)
			check(training.info_text().contains(st.move_name(st.input_map[&"x_move"])) and training.info_text().contains("READY"), "%s: training names ready X" % st.id)
			var cooldown_seconds := CombatData.get_attack(st.resolve(&"x_move", false)).x_cooldown_frames / CombatData.TICK_RATE
			check(training.info_text().contains("(%d s, no Focus)" % cooldown_seconds), "%s: training displays correct per-move total cooldown" % st.id)
			check(Hud._style_details(st).contains("%d s cooldown" % cooldown_seconds), "%s: roster displays correct per-move cooldown" % st.id)
			me.x_cooldown = 300
			check(training.info_text().contains("5.0 s"), "%s: training shows simulation cooldown" % st.id)
			training.free()
			ai.free()
			me.free()
			target.free()
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	# Stop scene simulation so this check owns input reads.
	main.set_physics_process(false)
	Input.action_press("x_move")
	var first: CombatData.Intent = main.call("_read_player_intent")
	check(first.slot == &"x_move", "fresh X input resolves new style slot")
	await physics_frame
	await physics_frame
	var held: CombatData.Intent = main.call("_read_player_intent")
	check(held.slot != &"x_move", "holding X never repeats its input edge")
	Input.action_release("x_move")
	var keys := InputMap.action_get_events("x_move")
	check(keys.filter(func(e): return e is InputEventKey).map(func(e): return e.physical_keycode) == [KEY_X], "physical X is the one key mapped (pad buttons alongside)")
	for st in StyleRegistry.all():
		main.player.set_style(st)
		var seconds := CombatData.get_attack(st.resolve(&"x_move", false)).x_cooldown_frames / CombatData.TICK_RATE
		check(String(main.call("_move_list_text")).contains("%d s cooldown, no Focus" % seconds), "%s training move list explains actual X cooldown" % st.id)
	main.queue_free()
	await process_frame
	print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
