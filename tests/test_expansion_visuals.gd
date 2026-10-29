extends SceneTree
## Pose registration/anatomy/support regression, not a gameplay contact census.
## CAPTURE_STYLE_VISUALS=1 renders a contact-pose sheet for each new style.
var failures: int = 0
var count: int = 0
var canvas: Node
var capture := OS.get_environment("CAPTURE_STYLE_VISUALS") == "1"
var out := "res://docs/reviews/capoeira-jkd"

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", message)

func run() -> void:
	root.size = Vector2i(1800, 1600)
	root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	canvas = root
	if capture:
		RenderingServer.set_default_clear_color(Color(0.36, 0.38, 0.4))
		var sheet := SubViewport.new()
		sheet.size = Vector2i(1800, 1600)
		sheet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		sheet.world_2d = World2D.new()
		root.add_child(sheet)
		canvas = sheet
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for style_id: StringName in [&"capoeira", &"jeet_kune_do"]:
		var style := StyleRegistry.by_id(style_id)
		check(style != null, "%s registered" % style_id)
		if style == null: continue
		var ids := style.moves()
		var sig := CombatData.get_attack(CombatData.type_for_id(style.signature))
		for child: StringName in sig.sequence:
			if not ids.has(child): ids.append(child)
		for parent_id: StringName in ids.duplicate():
			for child: StringName in CombatData.get_attack(CombatData.type_for_id(parent_id)).sequence:
				if not ids.has(child): ids.append(child)
		var retained: Array[Node] = []
		var cell := 0
		for id: StringName in ids:
			var attack := CombatData.get_attack(CombatData.type_for_id(id))
			if not attack.sequence.is_empty(): continue
			for side in [1, -1]:
				var fighter := load("res://scenes/fighter.tscn").instantiate() as Fighter
				canvas.add_child(fighter)
				fighter.set_style(style)
				fighter.facing = side
				fighter.state = Fighter.State.ATTACK
				fighter.current_attack = attack
				fighter.state_frame = attack.startup
				fighter.airborne = attack.air_only or attack.leap_vy != 0.0
				fighter.ground_y = 560.0
				fighter.position = Vector2(640.0, 522.0 if fighter.airborne else 560.0)
				var visual := fighter.get_node("Visual") as FighterVisual
				visual.set_process(false)
				visual._sync_stance()
				visual._swing_from = visual._guard.duplicate()
				var keys: Array = visual._kit_moves.get(style.kit, {}).get(attack.type, visual._moves.get(attack.type, []))
				check(not keys.is_empty(), "%s has own keys" % id)
				for t in [attack.startup * 0.4, float(attack.startup), float(attack.startup + attack.active + attack.recovery - 1)]:
					var pose := visual._attack_pose(t)
					check(pose.size() == FighterVisual.CHANNELS, "%s channel count" % id)
					for value in pose:
						check(is_finite(value), "%s finite joints" % id)
					var joints := visual._solve_joints(pose)
					check(absf(joints[FighterVisual.J_HIP].distance_to(joints[FighterVisual.J_NECK]) - FighterVisual.TORSO_LEN) < 0.1, "%s torso length" % id)
					check(absf(joints[FighterVisual.J_ELBOW_F].distance_to(joints[FighterVisual.J_HAND_F]) - FighterVisual.FOREARM) < 0.1, "%s arm length" % id)
				visual._pose = visual._attack_pose(float(attack.startup))
				visual._last_delta = 1.0 / 60.0
				if visual._cap_supported_move():
					var mirror := Transform2D(0.0, Vector2(side, 1.0), 0.0, fighter.position)
					var j := mirror * visual._solve_joints(visual._pose)
					j = visual._plant_cap_hands(j)
					var hand := FighterVisual.J_HAND_F if visual._cap_inverted_move() else FighterVisual.J_HAND_B
					check(absf(j[hand].y - fighter.ground_y + 4.0) < 0.5, "%s supporting palm on floor side%s" % [id, side])
					var anchor := j[hand]
					fighter.position.x += 2.0 * side
					mirror.origin = fighter.position
					j = visual._plant_cap_hands(mirror * visual._solve_joints(visual._pose))
					check(j[hand].distance_to(anchor) < 0.5, "%s palm remains anchored side%s" % [id, side])
				if capture:
					var x := float(cell % 6) * 300.0 + 150.0
					var floor_y := float(cell / 6) * 260.0 + 235.0
					fighter.ground_y = floor_y
					fighter.position = Vector2(x, floor_y - (38.0 if fighter.airborne else 0.0))
					visual._height = 38.0 if fighter.airborne else 0.0
					visual._cap_hand_anchors.clear()
					visual._spin_angle = PI * visual._back_turn(float(attack.startup)) if attack.spin else 0.0
					visual.queue_redraw()
					var label := Label.new()
					label.text = "%s %s" % [id, "R" if side == 1 else "L"]
					label.position = Vector2(x - 142.0, floor_y - 228.0)
					label.add_theme_font_size_override("font_size", 15)
					canvas.add_child(label)
					retained.append(fighter)
					retained.append(label)
				else:
					fighter.free()
				cell += 1
				count += 1
		if capture:
			await physics_frame
			await process_frame
			for node in retained:
				if node is Fighter: node.get_node("Visual").queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			(canvas as SubViewport).get_texture().get_image().save_png(out + "/%s_moves.png" % style_id)
			for node in retained: node.free()
	print("RESULT: ", "PASS" if failures == 0 else "FAIL", " expansion visuals: ", count, " move/facing probes, ", failures, " failures")
	quit(0 if failures == 0 else 1)
