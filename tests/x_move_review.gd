extends SceneTree
## Rendered X contact matrix and timing/damage census. Run without --headless.
var rows: Array = []
var failures: int = 0
var out := "res://docs/reviews/x-impact"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 720)
	root.get_viewport().physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	RenderingServer.set_default_clear_color(Color(0.12, 0.14, 0.18))
	var floor_line := ColorRect.new()
	floor_line.position = Vector2(100, 562)
	floor_line.size = Vector2(1080, 2)
	floor_line.color = Color(0.35, 0.38, 0.4)
	root.add_child(floor_line)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var only := OS.get_environment("ONLY_STYLE")
	if only != "" and FileAccess.file_exists(out + "/census.json"):
		for row in JSON.parse_string(FileAccess.get_file_as_string(out + "/census.json")):
			if row["style"] != only: rows.append(row)
	for style in StyleRegistry.all():
		if only != "" and String(style.id) != only: continue
		for side in [1, -1]:
			for wall in [false, true]:
				for gap in [70.0, 90.0, max_gap(style)]:
					await review(style, side, wall, gap)
	var f := FileAccess.open(out + "/census.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(rows, "\t"))
	print("RESULT: ", "PASS" if failures == 0 else "FAIL", " X rendered contact census: ", rows.size(), " cases, ", failures, " failures")
	quit(0 if failures == 0 else 1)
func max_gap(style: MartialArtStyle) -> float:
	var move := CombatData.get_attack(style.resolve(&"x_move", false))
	if not move.sequence.is_empty(): move = CombatData.get_attack(CombatData.type_for_id(move.sequence[0]))
	var travel_ticks := move.startup if move.travel_start < 0 else maxi(0, move.startup - move.travel_start)
	var reach := move.hitbox.end.x + move.step + move.lunge * travel_ticks - move.backstep
	if move.leap_vy != 0.0:
		reach += move.leap_vx * maxi(0, move.startup - move.leap_at)
	return reach - 1.0
func review(style: MartialArtStyle, side: int, wall: bool, gap: float) -> void:
	var a: Fighter = load("res://scenes/fighter.tscn").instantiate()
	var b: Fighter = load("res://scenes/fighter.tscn").instantiate()
	a.position = Vector2(590, 560)
	b.position = Vector2(590 + side * gap, 560)
	if wall:
		b.position.x = Fighter.ARENA_MAX_X - 5 if side == 1 else Fighter.ARENA_MIN_X + 5
		a.position.x = b.position.x - side * gap
	a.z_index = 1
	root.add_child(a)
	root.add_child(b)
	a.opponent = b
	b.opponent = a
	a.set_style(style)
	b.set_style(StyleRegistry.by_id(&"karate"))
	a.face_opponent()
	b.face_opponent()
	var label := Label.new()
	label.text = "%s | X: %s | %s | %s" % [style.display_name, style.move_name(style.input_map[&"x_move"]), "RIGHT" if side == 1 else "LEFT", "WALL" if wall else "CENTRE"]
	label.position = Vector2(180, 100)
	label.add_theme_font_size_override("font_size", 24)
	root.add_child(label)
	for n in 5:
		await process_frame
	var press := CombatData.Intent.new()
	press.slot = &"x_move"
	a.push_intent(press)
	var attacker_start := a.position.x
	var target_start := b.position.x
	var peak_travel := 0.0
	var peak_air_travel := 0.0
	var contacts: Array = []
	var windows := {}
	var recovered := -1
	var clip_dir := out + "/" + String(style.id) + ("_right" if side == 1 else "_left")
	if not wall and gap == 90.0:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(clip_dir))
	for tick in 115:
		a.tick()
		b.tick()
		peak_travel = maxf(peak_travel, (b.position.x - target_start) * side)
		if b.airborne: peak_air_travel = maxf(peak_air_travel, (b.position.x - target_start) * side)
		await process_frame
		await RenderingServer.frame_post_draw
		if not wall and gap == 90.0:
			root.get_texture().get_image().save_png(clip_dir + "/frame_%03d.png" % tick)
		if a.current_attack != null and a.is_hitbox_active():
			var id := a.current_attack.id
			if not windows.has(id): windows[id] = [tick, tick]
			windows[id][1] = tick
			if not a.swing_has_hit and a.get_hitbox_world().intersects(b.get_hurtbox_world()) and b.can_be_hit():
				var point := (a.get_node("Visual") as FighterVisual).get_strike_point()
				var rect := b.get_hurtbox_world()
				var nearest := Vector2(clampf(point.x, rect.position.x, rect.end.x), clampf(point.y, rect.position.y, rect.end.y))
				var visible_gap := point.distance_to(nearest)
				var before := b.health
				var result := b.receive_hit(a.current_attack, a, a.combo_step)
				a.confirm_hit(result)
				contacts.append({"id": id, "tick": tick, "damage": before - b.health, "visible_gap": visible_gap})
				if visible_gap > 12.0:
					failures += 1
					print("FAIL visible contact ", style.id, " side ", side, " wall ", wall, " gap ", visible_gap)
		if recovered < 0 and tick > 5 and a.can_act(): recovered = tick
		if a.position.x < Fighter.ARENA_MIN_X or a.position.x > Fighter.ARENA_MAX_X:
			failures += 1
	if contacts.is_empty():
		failures += 1
		print("FAIL no contact ", style.id, " side ", side, " wall ", wall)
	var row := {"style": style.id, "gap": gap, "side": side, "wall": wall, "contacts": contacts, "windows": windows, "recovered_tick": recovered, "damage": b.max_health - b.health, "attacker_travel": (a.position.x - attacker_start) * side, "peak_target_travel": peak_travel, "peak_air_travel": peak_air_travel, "target_end_x": b.position.x}
	rows.append(row)
	print(JSON.stringify(row))
	a.free()
	b.free()
	label.free()
