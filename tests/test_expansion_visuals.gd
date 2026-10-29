extends SceneTree
## Pose registration/anatomy/support regression, not a gameplay contact census.
## CAPTURE_STYLE_VISUALS=1 renders a contact-pose sheet for each new style.
var failures: int = 0
var count: int = 0
var canvas: Node
var capture := OS.get_environment("CAPTURE_STYLE_VISUALS") == "1"
var out := "res://docs/reviews/style-move-polish"

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", message)

func run() -> void:
	if OS.get_environment("REVIEW_OUT") != "":
		out = OS.get_environment("REVIEW_OUT")
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
	polish_semantics()
	if capture:
		await capture_agility_sequences()
	print("RESULT: ", "PASS" if failures == 0 else "FAIL", " expansion visuals: ", count, " move/facing probes, ", failures, " failures")
	quit(0 if failures == 0 else 1)


## Authored startup/contact/recovery snapshots, not a gameplay contact test.
func capture_agility_sequences() -> void:
	var retained: Array[Node] = []
	var cases: Array = []
	for side in [1, -1]:
		for frame in [0, 7, 12, 18, 25, 32]:
			cases.append([&"capoeira", side, &"roll", frame])
	for side in [1, -1]:
		for phase in [0.45, 1.0, 1.35]:
			cases.append([&"jeet_kune_do", side, &"jkd_hammerfist", phase])
	for side in [1, -1]:
		for id in [&"jkd_chain_jab", &"jkd_chain_cross"]:
			cases.append([&"jeet_kune_do", side, id, 1.0])
	var cell := 0
	for c in cases:
		var fighter := load("res://scenes/fighter.tscn").instantiate() as Fighter
		canvas.add_child(fighter)
		fighter.set_style(StyleRegistry.by_id(c[0]))
		fighter.facing = c[1]
		var x := float(cell % 6) * 300.0 + 150.0
		var floor_y := float(cell / 6) * 260.0 + 235.0
		fighter.position = Vector2(x, floor_y)
		fighter.ground_y = floor_y
		var v := fighter.get_node("Visual") as FighterVisual
		v.set_process(false)
		v._sync_stance()
		var label := Label.new()
		if c[2] == &"roll":
			fighter.state = Fighter.State.JUMP
			fighter.airborne = true
			fighter.cap_roll_jump = true
			fighter.cap_roll_jump_frame = c[3]
			fighter.cap_roll_jump_dir = c[1]
			fighter.position.y -= 40
			v._height = 40
			v._pose = v._air_pose()
			v._tuck_amount = v._cap_roll_tuck()
			v._update_spin(0, 1)
			label.text = "Cap roll %s frame %s" % [c[1], c[3]]
		else:
			var attack := CombatData.get_attack(CombatData.type_for_id(c[2]))
			var time := attack.startup * minf(c[3], 1.0)
			if c[3] > 1.0:
				time = attack.startup + attack.active * (c[3] - 1.0) / 0.35
			v._pose = contact_pose(fighter, v, c[2], time)
			label.text = "%s %s %.2f" % [c[2], c[1], c[3]]
		v.queue_redraw()
		label.position = Vector2(x - 142, floor_y - 228)
		label.add_theme_font_size_override("font_size", 15)
		canvas.add_child(label)
		retained.append(fighter)
		retained.append(label)
		cell += 1
	await process_frame
	await RenderingServer.frame_post_draw
	(canvas as SubViewport).get_texture().get_image().save_png(out + "/agility_sequences.png")
	for node in retained: node.free()


func contact_pose(fighter: Fighter, visual: FighterVisual, id: StringName, time: float = -1.0) -> PackedFloat32Array:
	fighter.state = Fighter.State.ATTACK
	fighter.current_attack = CombatData.get_attack(CombatData.type_for_id(id))
	fighter.airborne = fighter.current_attack.air_only
	visual._swing_from = visual._guard.duplicate()
	return visual._attack_pose(float(fighter.current_attack.startup) if time < 0.0 else time)


func polish_semantics() -> void:
	for side in [1, -1]:
		var fighter := load("res://scenes/fighter.tscn").instantiate() as Fighter
		root.add_child(fighter)
		fighter.position = Vector2(640.0, 560.0)
		fighter.ground_y = 560.0
		fighter.facing = side
		fighter.set_style(StyleRegistry.by_id(&"capoeira"))
		var v := fighter.get_node("Visual") as FighterVisual
		v.set_process(false)
		v._sync_stance()
		var wheel := contact_pose(fighter, v, &"cap_cartwheel")
		var meia := contact_pose(fighter, v, &"meia_lua_tornado")
		check(wheel[FighterVisual.TORSO] - meia[FighterVisual.TORSO] > 0.4, "Capoeira X slants away from vertical cartwheel")
		var split := v._solve_joints(meia)
		check(split[FighterVisual.J_FOOT_B].x - split[FighterVisual.J_FOOT_F].x > 160.0, "Capoeira X has a wide split handstand")
		check(split[FighterVisual.J_HAND_F].y < -35.0, "Capoeira X free hand stays off the floor")
		var sweep := contact_pose(fighter, v, &"cap_low_sweep")
		var j := v._solve_joints(sweep)
		check(j[FighterVisual.J_FOOT_F].y > -25.0 and j[FighterVisual.J_FOOT_F].y < -3.0, "sweep heel stays low above floor")
		check(j[FighterVisual.J_HIP_F].distance_to(j[FighterVisual.J_FOOT_F]) > 85.0, "sweep attacking leg extends without a frog fold")
		check(j[FighterVisual.J_FOOT_F].x - j[FighterVisual.J_KNEE_B].x > 35.0, "sweep heel separates from bent support knee")
		check(j[FighterVisual.J_KNEE_B].y < -3.0, "sweep support knee clears floor")
		var load := contact_pose(fighter, v, &"cap_low_sweep", fighter.current_attack.startup * 0.4)
		var recoil := contact_pose(fighter, v, &"cap_low_sweep", fighter.current_attack.startup + fighter.current_attack.active + fighter.current_attack.recovery * 0.5)
		check(v._solve_joints(load)[FighterVisual.J_FOOT_F].x < j[FighterVisual.J_FOOT_F].x - 35.0, "sweep visibly loads before extending")
		check(v._solve_joints(recoil)[FighterVisual.J_FOOT_F].x < j[FighterVisual.J_FOOT_F].x - 35.0, "sweep retracts heel before standing")
		fighter.state = Fighter.State.FINISHER
		fighter.script_pose = &"cap_rasteira_hit"
		check(v._cap_supported_move(), "finisher sweep uses the same planted-hand support")
		fighter.script_pose = &""
		fighter.state = Fighter.State.JUMP
		fighter.airborne = true
		fighter.cap_roll_jump = true
		fighter.cap_roll_jump_dir = side
		fighter.cap_roll_jump_frame = 12
		v._update_spin(1.0 / 60.0, 1.0)
		var first_angle := v._body_rot
		var roll_pose := v._air_pose()
		check(roll_pose[FighterVisual.TH_F] > 2.4 and roll_pose[FighterVisual.SH_F] < 0.0, "Capoeira somersault draws knees tightly into the chest")
		check(v._cap_roll_tuck() > 0.9 and first_angle > 0.5 and first_angle < PI, "Capoeira rolls as a tucked body after takeoff")
		fighter.cap_roll_jump_frame = fighter.cap_roll_jump_duration - 5
		v._update_spin(1.0 / 60.0, 1.0)
		check(v._body_rot > first_angle and absf(v._body_rot - TAU) < 0.05, "Capoeira finishes one full somersault before landing")
		check(v._cap_roll_tuck() < 0.1, "Capoeira opens the legs before landing")
		fighter.cap_roll_jump = false
		fighter.set_style(StyleRegistry.by_id(&"jeet_kune_do"))
		v._sync_stance()
		var jab := contact_pose(fighter, v, &"jkd_chain_jab")
		check(FighterVisual._attack_joint(fighter.current_attack.type) == FighterVisual.J_HAND_F, "JKD jab-cross starts with the lead fist")
		var cross := contact_pose(fighter, v, &"jkd_chain_cross")
		check(FighterVisual._attack_joint(fighter.current_attack.type) == FighterVisual.J_HAND_B, "JKD jab-cross finishes with the rear fist")
		check(jab[FighterVisual.SPREAD] > 20 and cross[FighterVisual.SPREAD] < -20, "JKD jab-cross reverses shoulder drive between punches")
		check(cross[FighterVisual.HIP_X] - jab[FighterVisual.HIP_X] > 7 and cross[FighterVisual.PIVOT] > 0.9, "JKD cross drives the hip and rear heel")
		var hammer := contact_pose(fighter, v, &"jkd_hammerfist")
		var hammer_load := contact_pose(fighter, v, &"jkd_hammerfist", fighter.current_attack.startup * 0.45)
		var hammer_before := v._solve_joints(hammer_load)
		var hammer_after := v._solve_joints(hammer)
		check(FighterVisual._attack_joint(fighter.current_attack.type) == FighterVisual.J_HAND_B, "JKD hammerfist uses its raised rear fist")
		check(hammer_before[FighterVisual.J_HAND_B].y < hammer_before[FighterVisual.J_HEAD].y - 12, "JKD hammerfist winds up above the head")
		check(hammer_after[FighterVisual.J_HAND_B].y - hammer_before[FighterVisual.J_HAND_B].y > 40, "JKD hammerfist has a descending contact arc")
		check(absf(hammer[FighterVisual.UA_B] - hammer[FighterVisual.LA_B]) > 0.4, "JKD hammerfist retains its bent elbow at contact")
		var air_side := contact_pose(fighter, v, &"jump_kick")
		var air_front := contact_pose(fighter, v, &"jkd_air_front")
		check(absf(air_side[FighterVisual.TORSO] - air_front[FighterVisual.TORSO]) > 0.5, "JKD air side kick counterlean differs from upright front snap")
		check(absf(air_side[FighterVisual.SPREAD] - air_front[FighterVisual.SPREAD]) > 12.0, "JKD air front kick squares the hips")
		var step := contact_pose(fighter, v, &"dragons_burst")
		var collect := contact_pose(fighter, v, &"dragons_burst", fighter.current_attack.startup * 0.28)
		var chamber := contact_pose(fighter, v, &"dragons_burst", fighter.current_attack.startup * 0.64)
		var gathered := v._solve_joints(collect)
		check(absf(gathered[FighterVisual.J_FOOT_F].x - gathered[FighterVisual.J_FOOT_B].x) < 25.0, "JKD X gathers rear foot before driving")
		check(chamber[FighterVisual.TH_F] > 2.0 and chamber[FighterVisual.SH_F] < 0.0, "JKD X has a raised folded side chamber")
		check(step[FighterVisual.HIP_X] - collect[FighterVisual.HIP_X] > 25.0, "JKD X transfers weight through the finishing hip")
		check(collect[FighterVisual.SPREAD] > 15 and step[FighterVisual.SPREAD] < -15, "JKD X turns shoulders and hips through edge-on into side stance")
		check(chamber[FighterVisual.PIVOT] > 0.9 and collect[FighterVisual.PIVOT] < 0.2, "JKD support foot pivots before heel extension")
		check(collect[FighterVisual.UA_F] - step[FighterVisual.UA_F] > 1.2, "JKD lead arm counterbalances the hip turn instead of staying rigid")
		check(FighterVisual._attack_joint(fighter.current_attack.type) == FighterVisual.J_FOOT_F, "JKD X is one heel kick, never a punch")
		fighter.state = Fighter.State.FINISHER
		fighter.airborne = false
		var set_pose: PackedFloat32Array = v._pose_library[&"jkd_inch_set"]
		var hit_pose: PackedFloat32Array = v._pose_library[&"jkd_inch_hit"]
		var before := v._solve_joints(set_pose)
		var after := v._solve_joints(hit_pose)
		var stroke := (after[FighterVisual.J_HAND_F] - after[FighterVisual.J_HIP]).distance_to(before[FighterVisual.J_HAND_F] - before[FighterVisual.J_HIP])
		check(stroke <= 12.0, "one-inch punch has compact torso-relative stroke: %.2fpx" % stroke)
		check(hit_pose[FighterVisual.HIP_X] - set_pose[FighterVisual.HIP_X] >= 6.0 and hit_pose[FighterVisual.PIVOT] > 0.8, "one-inch punch drives through hip and rear heel")
		fighter.free()
