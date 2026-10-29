extends SceneTree
## Both intro silhouettes and the landing back to guard, in both directions.
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", message)

func run() -> void:
	root.size = Vector2i(1280, 720)
	RenderingServer.set_default_clear_color(Color(0.2, 0.22, 0.25))
	for side in [1, -1]:
		var fighters: Array[Fighter] = []
		for id in [&"capoeira", &"jeet_kune_do"]:
			var f: Fighter = load("res://scenes/fighter.tscn").instantiate()
			root.add_child(f)
			f.set_style(StyleRegistry.by_id(id))
			f.position = Vector2(420 if id == &"capoeira" else 860, 540)
			f.ground_y = 540
			f.facing = side
			f.prefight_pose = f.style.intro_pose
			fighters.append(f)
			var v := f.get_node("Visual") as FighterVisual
			v._sync_stance()
			check(v._pose_library.has(f.prefight_pose), "%s intro registered" % id)
		for tick in 180:
			await process_frame
			if tick == 70:
				var v := fighters[0].get_node("Visual") as FighterVisual
				var mirror := Transform2D(0.0, Vector2(side, 1), 0.0, fighters[0].position)
				var joints := v._plant_cap_hands(mirror * v._solve_joints(v._pose))
				check(absf(joints[FighterVisual.J_HAND_B].y - 536) < 0.6, "intro supporting palm reaches floor")
				check(joints[FighterVisual.J_FOOT_F].y < joints[FighterVisual.J_HIP].y - 65, "intro feet held above hips")
				check(not v._wants_plant(), "intro does not plant elevated feet")
			if tick == 90:
				for f in fighters: f.prefight_pose = &""
		var v := fighters[0].get_node("Visual") as FighterVisual
		check(v._cap_intro_exit == 0 and not v._cap_intro_balance(), "intro returns to combat guard")
		check(absf(v._pose[FighterVisual.TORSO]) < 0.8, "Capoeira stands up after intro")
		for f in fighters: f.free()
	print("RESULT: ", "PASS" if failures == 0 else "FAIL", " reference intros: ", failures, " failures")
	quit(0 if failures == 0 else 1)
