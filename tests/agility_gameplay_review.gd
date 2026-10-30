extends SceneTree
## Actual-input mirrored clip: crossover, stun, knockdown and JKD strikes.
class Driver extends Node:
	var main: Node
	var tree: SceneTree
	var side := 1
	var frame := 0
	var failures := 0
	var hits := 0
	var seen_counter := 0
	var saw_stun := false
	var saw_down := false
	var saw_break := false
	var crossed := false
	var cases := [
		[&"capoeira", "ROLLING CROSSOVER JUMP", "jump", "", false, "cross"],
		[&"capoeira", "L - CARTWHEEL STUN", "attack_technique", "", false, "stun"],
		[&"capoeira", "S+K - KNOCKDOWN SWEEP", "attack_heavy", "mod_down", false, "down"],
		[&"jeet_kune_do", "J - FAST JAB-CROSS", "attack_light", "", false, "double"],
		[&"jeet_kune_do", "K - HEAVY HAMMERFIST", "attack_heavy", "", false, "single"],
		[&"jeet_kune_do", "W+K - HOOK STUN", "attack_heavy", "mod_up", false, "stun"],
		[&"jeet_kune_do", "W+K - HOOK GUARD BREAK", "attack_heavy", "mod_up", true, "break"],
	]
	func _physics_process(_delta: float) -> void:
		main.hud.hide_speech(main.player)
		main.hud.hide_speech(main.enemy)
		for action in ["move_left", "move_right", "jump", "attack_light", "attack_heavy", "attack_technique", "mod_down", "mod_up"]:
			Input.action_release(action)
		var index := frame / 200
		var local := frame % 200
		if index >= cases.size():
			print("RESULT: ", "PASS" if failures == 0 else "FAIL", " agility actual-input review: ", failures, " failures")
			tree.quit(0 if failures == 0 else 1)
			return
		var c: Array = cases[index]
		if local == 0:
			main.call("_reset_training")
			main.player.set_style(StyleRegistry.by_id(c[0]))
			main.audio.set_music(c[0])
			main.enemy.set_style(StyleRegistry.by_id(&"karate"))
			main.player.position = Vector2(480 if side == 1 else 800, 560)
			main.enemy.position = main.player.position + Vector2(side * (120 if c[5] == "cross" else 80), 0)
			main.player.prefight_pose = &""
			main.enemy.prefight_pose = &""
			main.player.face_opponent()
			main.enemy.face_opponent()
			main.player.reset_physics_interpolation()
			main.enemy.reset_physics_interpolation()
			main.training.dummy_mode = TrainingMode.Dummy.BLOCK if c[4] else TrainingMode.Dummy.STAND
			main.hud.set_countdown("")
			main.hud.set_banner(c[1], main.player.accent_color)
			hits = 0
			seen_counter = main.enemy.hit_counter
			saw_stun = false
			saw_down = false
			saw_break = false
			crossed = false
		if c[3] != "" and local >= 20 and local <= 28:
			Input.action_press(c[3])
		if c[5] == "cross" and local >= 20 and local <= 70:
			Input.action_press("move_right" if side == 1 else "move_left")
		if local == 24:
			Input.action_press(c[2])
		if local > 24:
			if main.enemy.hit_counter > seen_counter:
				hits += main.enemy.hit_counter - seen_counter
				seen_counter = main.enemy.hit_counter
			saw_stun = saw_stun or main.enemy.dizzy_left > 0
			saw_down = saw_down or main.enemy.state == Fighter.State.KNOCKDOWN
			saw_break = saw_break or main.enemy.state == Fighter.State.BROKEN
			crossed = crossed or ((main.player.position.x - main.enemy.position.x) * side > 45 and not main.player.airborne)
		if local == 199:
			var passed: bool = {"cross": crossed, "stun": saw_stun, "down": saw_down, "double": hits == 2, "single": hits == 1, "break": saw_break}[c[5]]
			if not passed: failures += 1
			print(c[1], ": ", "PASS" if passed else "FAIL", " hits=", hits, " stun=", saw_stun, " down=", saw_down, " break=", saw_break, " crossed=", crossed)
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
