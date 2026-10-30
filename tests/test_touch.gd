extends SceneTree
## Touch controls: hidden on the menus, shown in the fight when forced on (a
## desktop has no touch screen), and a real screen touch on a button presses
## its action: LIGHT throws the style's light attack, and UP + LIGHT together
## (two fingers) throw the up-light move.

class Driver extends Node:
	var tree: SceneTree
	var fails: int = 0
	var frame: int = 0

	func check(cond: bool, msg: String) -> void:
		print(("  ok   " if cond else "  FAIL ") + msg)
		if not cond:
			fails += 1

	func touch(tc: TouchControls, action: StringName, finger: int, down: bool) -> void:
		var b: TouchScreenButton = tc.buttons[action]
		var ev := InputEventScreenTouch.new()
		ev.index = finger
		ev.pressed = down
		# Window coordinates (the headless window is not 1280 x 720).
		ev.position = tree.root.get_final_transform() * (b.position + Vector2(b.shape.radius, b.shape.radius))
		tree.root.push_input(ev)

	func _physics_process(_d: float) -> void:
		frame += 1
		var main := tree.current_scene
		if main == null:
			return
		var tc: TouchControls = main.get("touch")
		var p: Fighter = main.get_node("Player")
		match frame:
			2:
				main.get_node("HUD").style_chosen.emit(&"boxing")
				main.call("confirm_style")
			4:
				check(tc != null and not tc.is_shown(), "hidden on the pre-match screen")
				main.call("start_match", true)
			8:
				check(tc.is_shown(), "shown in the fight (TOUCH CONTROLS on)")
				check(tc.buttons.size() == 11, "eleven buttons (pad, attacks, jump, block, X, signature)")
				touch(tc, &"attack_light", 0, true)
			9:
				check(Input.is_action_pressed(&"attack_light"), "touching LIGHT presses the light action")
				touch(tc, &"attack_light", 0, false)
			12:
				check(p.current_attack != null and p.current_attack.type == p.style.resolve(&"light", false),
					"and the boxer throws the jab (%s)" % (p.current_attack.id if p.current_attack else "nothing"))
				check(not Input.is_action_pressed(&"attack_light"), "lifting the finger releases it")
			60:
				touch(tc, &"mod_up", 0, true)
			62:
				touch(tc, &"attack_light", 1, true)
			66:
				check(p.current_attack != null and p.current_attack.type == p.style.resolve(&"up_light", false),
					"UP + LIGHT with two fingers throws the up-light move (%s)" % (p.current_attack.id if p.current_attack else "nothing"))
				touch(tc, &"attack_light", 1, false)
				touch(tc, &"mod_up", 0, false)
			70:
				GameSettings.touch_controls = false
				print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
				tree.quit(1 if fails > 0 else 0)


func _initialize() -> void:
	GameSettings.file = "user://test_touch_tmp.cfg"  # never the player's file
	GameSettings.touch_controls = true
	var d := Driver.new()
	d.tree = self
	root.add_child(d)
	change_scene_to_file("res://scenes/main.tscn")
