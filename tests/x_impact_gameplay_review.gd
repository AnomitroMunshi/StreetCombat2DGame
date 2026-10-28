extends SceneTree
## Real-scene X review: actual input, hitstop, audio, pushboxes and knockback.
## Run with --write-movie <output.avi>; set REVIEW_SIDE=-1 for left facing.
class Driver extends Node:
	var main: Node
	var tree: SceneTree
	var frame := 0
	var side := 1
	var styles: Array = []
	var rows: Array = []
	var failures := 0
	var row: Dictionary = {}
	var target_start := 0.0
	var seen_hits := 0
	var baseline_head := 0.0
	func _physics_process(_delta: float) -> void:
		Input.action_release("x_move")
		var index := frame / 200
		var local := frame % 200
		if index >= styles.size():
			var out := FileAccess.open("res://docs/reviews/x-impact/gameplay_%s.json" % ("right" if side == 1 else "left"), FileAccess.WRITE)
			out.store_string(JSON.stringify(rows, "\t"))
			print("RESULT: ", "PASS" if failures == 0 else "FAIL", " real-scene X impact review, ", failures, " failures")
			tree.quit(0 if failures == 0 else 1)
			return
		if local == 0:
			main.call("_reset_training")
			var st: MartialArtStyle = styles[index]
			main.player.set_style(st)
			main.enemy.set_style(StyleRegistry.by_id(&"karate"))
			main.player.x_cooldown = 0
			main.enemy.x_cooldown = 600
			main.player.position = Vector2(480 if side == 1 else 800, 560)
			main.enemy.position = main.player.position + Vector2(side * 90, 0)
			main.player.prefight_pose = &""
			main.enemy.prefight_pose = &""
			main.player.face_opponent()
			main.enemy.face_opponent()
			main.player.reset_physics_interpolation()
			main.enemy.reset_physics_interpolation()
			main.hud.show_training(false)
			main.hud.set_countdown("")
			main.hud.set_banner("%s X - %s" % [st.display_name.to_upper(), st.move_name(st.input_map[&"x_move"])], main.player.accent_color)
			target_start = main.enemy.position.x
			seen_hits = main.enemy.hit_counter
			row = {"style": st.id, "side": side, "cooldown_seconds": CombatData.get_attack(st.resolve(&"x_move", false)).x_cooldown_frames / CombatData.TICK_RATE, "peak_travel": 0.0, "peak_air_travel": 0.0, "hits": []}
		if local == 20:
			var joints: PackedVector2Array = main.enemy.get_node("Visual").get("_last_joints")
			baseline_head = (joints[FighterVisual.J_HEAD].x - main.enemy.position.x) * main.enemy.facing
		if local == 24:
			Input.action_press("x_move")
		if local > 24:
			if main.enemy.hit_counter > seen_hits:
				seen_hits = main.enemy.hit_counter
				var attack: CombatData.Attack = main.player.current_attack
				var joints: PackedVector2Array = main.enemy.get_node("Visual").get("_last_joints")
				var head_local: float = (joints[FighterVisual.J_HEAD].x - main.enemy.position.x) * main.enemy.facing
				row["hits"].append({"tick": local, "id": attack.id if attack != null else &"", "damage": attack.damage if attack != null else 0, "head_recoil_px": baseline_head - head_local, "x_flinch": main.enemy.get_node("Visual").call("_has_x_flinch")})
			row["peak_travel"] = maxf(row["peak_travel"], (main.enemy.position.x - target_start) * side)
			if main.enemy.airborne:
				row["peak_air_travel"] = maxf(row["peak_air_travel"], (main.enemy.position.x - target_start) * side)
		if local == 199:
			var damage := 0
			for contact in row["hits"]: damage += contact["damage"]
			if damage != 18: failures += 1
			if row["style"] in [&"karate", &"kung_fu"]:
				if not row["hits"][0]["x_flinch"] or row["hits"][0]["head_recoil_px"] < 20.0: failures += 1
			if row["style"] == &"kickboxing" and row["peak_air_travel"] < 250.0: failures += 1
			if row["style"] == &"bangla_maar" and row["peak_air_travel"] < 140.0: failures += 1
			rows.append(row)
			print(JSON.stringify(row))
		frame += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	main.select_style(&"boxing")
	main.start_training()
	main.training.infinite_focus = false
	var d := Driver.new()
	d.main = main
	d.tree = self
	d.styles = StyleRegistry.all()
	d.side = -1 if OS.get_environment("REVIEW_SIDE") == "-1" else 1
	d.process_physics_priority = -100
	root.add_child(d)
