extends SceneTree
## Rendered strike-point checks for the revised normals, mirrored near walls.
var failures := 0
var rows: Array = []
const OUT := "res://docs/reviews/agility-balance"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	for spec in [[&"capoeira", &"technique"], [&"capoeira", &"down_heavy"], [&"jeet_kune_do", &"light"], [&"jeet_kune_do", &"heavy"], [&"jeet_kune_do", &"up_heavy"]]:
		for side in [1, -1]:
			for wall in [false, true]:
				for gap in [80.0, 100.0]:
					await contact(spec[0], spec[1], side, wall, gap)
	var file := FileAccess.open(OUT + "/normal-contacts.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "\t"))
	print("RESULT: ", "PASS" if failures == 0 else "FAIL", " rendered revised normals: ", rows.size(), " cases, ", failures, " failures")
	quit(0 if failures == 0 else 1)

func contact(style: StringName, slot: StringName, side: int, wall: bool, gap: float) -> void:
	var a: Fighter = load("res://scenes/fighter.tscn").instantiate()
	var b: Fighter = load("res://scenes/fighter.tscn").instantiate()
	root.add_child(a)
	root.add_child(b)
	a.set_style(StyleRegistry.by_id(style))
	b.set_style(StyleRegistry.by_id(&"karate"))
	b.position = Vector2((Fighter.ARENA_MAX_X - 5 if side == 1 else Fighter.ARENA_MIN_X + 5) if wall else 640 + gap * side * 0.5, 560)
	a.position = b.position - Vector2(gap * side, 0)
	a.ground_y = 560
	b.ground_y = 560
	a.opponent = b
	b.opponent = a
	a.face_opponent()
	b.face_opponent()
	for tick in 5: await process_frame
	var intent := CombatData.Intent.new()
	intent.slot = slot
	a.push_intent(intent)
	var hits: Array = []
	var parent := CombatData.get_attack(a.style.resolve(slot, false))
	var expected_hits := maxi(1, parent.sequence.size())
	for tick in 80:
		a.tick()
		b.tick()
		await process_frame
		await RenderingServer.frame_post_draw
		if a.current_attack != null and a.is_hitbox_active() and not a.swing_has_hit and a.get_hitbox_world().intersects(b.get_hurtbox_world()) and b.can_be_hit():
			var point := (a.get_node("Visual") as FighterVisual).get_strike_point()
			var rect := b.get_hurtbox_world()
			var nearest := Vector2(clampf(point.x, rect.position.x, rect.end.x), clampf(point.y, rect.position.y, rect.end.y))
			var visible_gap := point.distance_to(nearest)
			var id := a.current_attack.id
			var result := b.receive_hit(a.current_attack, a, a.combo_step)
			a.confirm_hit(result)
			hits.append({"id": id, "tick": tick, "visible_gap": visible_gap})
			if visible_gap > 12:
				failures += 1
				print("FAIL drawn contact ", style, " ", slot, " side=", side, " wall=", wall, " gap=", visible_gap)
	if hits.size() != expected_hits:
		failures += 1
		print("FAIL contact count ", style, " ", slot, " side=", side, " wall=", wall, " start_gap=", gap, " contacts=", hits.size(), " expected=", expected_hits)
	rows.append({"style": style, "slot": slot, "side": side, "wall": wall, "start_gap": gap, "contacts": hits})
	a.free()
	b.free()
