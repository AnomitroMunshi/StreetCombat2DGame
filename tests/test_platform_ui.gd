extends SceneTree
## PC keeps the PC setup and the mobile UI only the mobile one: PC labels show
## key hints ([G] [U] [O]) and the settings panel offers fullscreen and key
## bindings; the mobile UI drops the key hints, shows volumes only, tells the
## tutorial in joystick / button terms and gives it tap buttons for skip /
## replay / leave. (The mobile UI is tested through the development TOUCH
## CONTROLS toggle; a mobile export turns it on by itself.)

var fails := 0


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		fails += 1


func _initialize() -> void:
	GameSettings.file = "user://test_platform_ui_tmp.cfg"  # never the player's file
	# Closing the panel saves: start (and end) without a leftover scratch file.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.file))
	call_deferred("run")


func run() -> void:
	for mobile in [false, true]:
		GameSettings.touch_controls = mobile
		var main: Node = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		current_scene = main
		for i in 2: await physics_frame
		main.call("_apply_touch_setting")
		var hud: Hud = main.get_node("HUD")
		hud.refresh_input_labels()
		main.call("select_style", &"boxing")
		main.call("confirm_style")
		await physics_frame
		print("[%s]" % ("mobile UI" if mobile else "PC"))
		var labels: String = hud.get("_button5").text + " " + hud.get("_button4").text + " " + hud.get("_settings_button").text
		check(labels.contains("[") != mobile, "key hints on the buttons: %s (%s)" % ["none" if mobile else "shown", labels])
		var sub: String = hud.get_message()[1]
		check(sub.begins_with("Tap") == mobile, "pre-match prompt: %s" % sub)
		hud.toggle_settings()
		check((hud.get("_settings_fullscreen") as Control).visible != mobile and (hud.get("_settings_controls") as Control).visible != mobile,
			"settings: fullscreen and key bindings %s" % ("hidden" if mobile else "offered"))
		hud.toggle_settings()
		main.call("start_tutorial")
		for i in 3: await physics_frame
		var lesson: String = hud.get_lesson_text()
		check(lesson.contains("joystick") == mobile, "tutorial words: %s" % ("joystick / buttons" if mobile else "keys"))
		check((hud.get("_lesson_buttons") as Control).visible == mobile, "tutorial tap buttons (skip / replay / leave) %s" % ("shown" if mobile else "hidden"))
		check((main.get("touch") as TouchControls).is_shown() == mobile, "touch controls %s" % ("on" if mobile else "off"))
		main.call("training_action", &"exit")
		for i in 2: await process_frame
		var current := current_scene
		if current != null:
			current.free()
		await process_frame
	GameSettings.touch_controls = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.file))
	print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
