extends SceneTree
## Actual-input comparison reel. REVIEW_SIDE=-1 mirrors all cases.
class Driver extends Node:
	var main: Node
	var tree: SceneTree
	var frame := 0
	var side := 1
	var seen := false
	var failures := 0
	var cases := [
		[&"capoeira", "L - CARTWHEEL KICK", "attack_technique", false, &"cap_cartwheel"],
		[&"capoeira", "X - HANDSTAND HAMMER", "x_move", false, &"meia_lua_tornado"],
		[&"capoeira", "S+K - LOW SWEEP", "attack_heavy", false, &"cap_low_sweep"],
		[&"jeet_kune_do", "AIR K - SIDE KICK", "attack_heavy", true, &"jump_kick"],
		[&"jeet_kune_do", "AIR L - FRONT SNAP KICK", "attack_technique", true, &"jkd_air_front"],
		[&"jeet_kune_do", "X - STEPPING SIDE KICK", "x_move", false, &"dragons_burst"],
	]
	func _physics_process(_delta: float) -> void:
		for action in ["attack_technique", "attack_heavy", "x_move", "jump", "mod_down"]:
			Input.action_release(action)
		var index := frame / 160
		var local := frame % 160
		if index >= cases.size():
			print("RESULT: ", "PASS" if failures == 0 else "FAIL", " actual-input variation reel: ", failures, " failures")
			tree.quit(0 if failures == 0 else 1)
			return
		var c: Array = cases[index]
		if local == 0:
			main.call("_reset_training")
			main.player.set_style(StyleRegistry.by_id(c[0]))
			main.audio.set_music(c[0])
			main.enemy.set_style(StyleRegistry.by_id(&"karate"))
			main.player.x_cooldown = 0
			main.player.position = Vector2(480 if side == 1 else 800, 560)
			main.enemy.position = main.player.position + Vector2(side * (170 if c[3] else 100), 0)
			main.player.prefight_pose = &""
			main.enemy.prefight_pose = &""
			main.player.face_opponent()
			main.enemy.face_opponent()
			main.player.reset_physics_interpolation()
			main.enemy.reset_physics_interpolation()
			main.hud.show_training(false)
			main.hud.set_countdown("")
			main.hud.set_banner(c[1], main.player.accent_color)
			seen = false
		if c[3] and local == 20:
			Input.action_press("jump")
		if c[4] == &"cap_low_sweep" and local >= 20 and local <= 26:
			Input.action_press("mod_down")
		if local == (32 if c[3] else 24):
			Input.action_press(c[2])
		if main.player.current_attack != null and main.player.current_attack.id == c[4]:
			seen = true
		if local == 159:
			if not seen:
				failures += 1
			print(c[1], ": input started correct move = ", seen)
		frame += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	main.select_style(&"boxing")
	main.start_training()
	main.training.infinite_focus = false
	var driver := Driver.new()
	driver.main = main
	driver.tree = self
	driver.side = -1 if OS.get_environment("REVIEW_SIDE") == "-1" else 1
	driver.process_physics_priority = -100
	root.add_child(driver)
