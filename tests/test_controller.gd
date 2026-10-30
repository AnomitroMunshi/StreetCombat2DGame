extends SceneTree
## Controller: SELECT cycles the style, START confirms and starts the match,
## X throws the light attack, the left stick walks, START pauses and resumes,
## and the keyboard keys keep working alongside the pad.

class Driver extends Node:
	var tree: SceneTree
	var fails: int = 0
	var frame: int = 0
	var first_style: StringName = &""
	var start_x: float = 0.0

	func check(cond: bool, msg: String) -> void:
		print(("  ok   " if cond else "  FAIL ") + msg)
		if not cond:
			fails += 1

	func button(index: int, down: bool) -> void:
		var ev := InputEventJoypadButton.new()
		ev.button_index = index
		ev.pressed = down
		Input.parse_input_event(ev)

	func stick_x(value: float) -> void:
		var ev := InputEventJoypadMotion.new()
		ev.axis = JOY_AXIS_LEFT_X
		ev.axis_value = value
		Input.parse_input_event(ev)

	func _physics_process(_d: float) -> void:
		frame += 1
		var main := tree.current_scene
		if main == null:
			return
		var p: Fighter = main.get_node("Player")
		var state: String = main.call("get_round_state_name")
		match frame:
			2:
				print("[menus]")
				first_style = p.style.id
				button(JOY_BUTTON_BACK, true)
			3:
				button(JOY_BUTTON_BACK, false)
			4:
				check(state != "STYLE_SELECT" or p.style.id != first_style, "SELECT cycles the style (%s -> %s)" % [first_style, p.style.id])
				button(JOY_BUTTON_START, true)
			5:
				button(JOY_BUTTON_START, false)
			6:
				check(state == "PRE_MATCH", "START confirms the style (%s)" % state)
				main.call("start_match", true)  # skip the intro; START here would play it
			8:
				print("[combat]")
				check(state == "FIGHTING", "fighting")
				button(JOY_BUTTON_X, true)
			9:
				button(JOY_BUTTON_X, false)
			12:
				check(p.current_attack != null and p.current_attack.type == p.style.resolve(&"light", false),
					"X throws the light attack (%s)" % (p.current_attack.id if p.current_attack else "nothing"))
			60:
				start_x = p.position.x
				stick_x(1.0 if p.facing == 1 else -1.0)
			80:
				stick_x(0.0)
				check(absf(p.position.x - start_x) > 20.0, "the left stick walks (%.0f px)" % absf(p.position.x - start_x))
				check(InputMap.action_get_events(&"attack_light").any(func(e): return e is InputEventKey),
					"the keyboard key is still bound alongside the pad")
				button(JOY_BUTTON_START, true)
			81:
				button(JOY_BUTTON_START, false)
			83:
				check(main.get("match_paused"), "START pauses the fight")
				button(JOY_BUTTON_START, true)
			84:
				button(JOY_BUTTON_START, false)
			86:
				check(not main.get("match_paused"), "START again resumes")
				print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
				tree.quit(1 if fails > 0 else 0)


func _initialize() -> void:
	GameSettings.file = "user://test_controller_tmp.cfg"  # never the player's file
	var d := Driver.new()
	d.tree = self
	d.process_mode = Node.PROCESS_MODE_ALWAYS  # keeps checking while paused
	root.add_child(d)
	change_scene_to_file("res://scenes/main.tscn")
