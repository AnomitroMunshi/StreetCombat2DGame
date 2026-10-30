extends SceneTree
## AI difficulty: Easy / Normal / Hard scale each style's tuned personality
## (Normal is the tuning unchanged), a re-setup never keeps the previous
## level, and the pre-match AI button / G cycles the rival's level, which
## then survives a rematch.

class Driver extends Node:
	var tree: SceneTree
	var fails: int = 0
	var phase: String = "start"
	var phase_frame: int = 0

	func check(cond: bool, msg: String) -> void:
		print(("  ok   " if cond else "  FAIL ") + msg)
		if not cond:
			fails += 1

	func go(next: String) -> void:
		phase = next
		phase_frame = 0

	func _physics_process(_d: float) -> void:
		phase_frame += 1
		var main := tree.current_scene
		if main == null:
			return
		var hud: Hud = main.get_node("HUD")
		var ai: EnemyAI = main.get_node("EnemyAI")
		var state: String = main.call("get_round_state_name")
		match phase:
			"start":
				if phase_frame == 2:
					print("[pre-match button]")
					hud.style_chosen.emit(&"boxing")
					main.call("confirm_style")
				elif phase_frame == 4:
					check(state == "PRE_MATCH" and hud.is_difficulty_button_visible(), "the AI button is offered beside START MATCH")
					check(hud.get_difficulty_text() == "AI: NORMAL  [G]", "the default is Normal (%s)" % hud.get_difficulty_text())
					hud.difficulty_pressed.emit()
					check(EnemyAI.selected_difficulty == &"hard" and ai.difficulty == &"hard" and hud.get_difficulty_text() == "AI: HARD  [G]",
						"a press moves Normal -> Hard (%s)" % hud.get_difficulty_text())
					var key := InputEventKey.new()
					key.physical_keycode = KEY_G
					key.pressed = true
					tree.root.push_input(key)
				elif phase_frame == 6:
					check(EnemyAI.selected_difficulty == &"easy" and hud.get_difficulty_text() == "AI: EASY  [G]", "G moves Hard -> Easy (wraps round)")
					main.call("start_match", true)
				elif phase_frame == 8:
					check(state == "FIGHTING" and ai.difficulty == &"easy" and ai.reaction_frames == 11, "the fight uses the chosen level (reaction %d)" % ai.reaction_frames)
					main.call("cycle_difficulty")
					check(EnemyAI.selected_difficulty == &"easy", "the level is locked once the fight starts")
					main.call("restart_match")
					go("rematch")
			"rematch":
				if phase_frame == 4:
					check(ai.difficulty == &"easy" and hud.get_difficulty_text() == "AI: EASY  [G]", "a rematch keeps the level")
					EnemyAI.selected_difficulty = &"normal"
					print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
					tree.quit(1 if fails > 0 else 0)


var _fails: int = 0


func _check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


## The AI's tuned values for `style` at `level`, after a fresh setup.
func _tuned(style: StringName, level: StringName, ai: EnemyAI = null) -> Dictionary:
	var me := Fighter.new()
	var foe := Fighter.new()
	root.add_child(me)
	root.add_child(foe)
	me.set_style(StyleRegistry.by_id(style))
	foe.set_style(StyleRegistry.by_id(&"karate"))
	var own := ai == null
	if own:
		ai = EnemyAI.new()
		root.add_child(ai)
	ai.difficulty = level
	ai.setup(me, foe)
	var out := {}
	for key in EnemyAI.TUNABLE + ["reaction_frames", "signature_chance"]:
		out[key] = ai.get(key)
	me.free()
	foe.free()
	if own:
		ai.free()
	return out


func _initialize() -> void:
	print("[levels]")
	_check(EnemyAI.DIFFICULTIES == [&"easy", &"normal", &"hard"], "three levels, easiest first")
	for style in StyleRegistry.all():
		var e := _tuned(style.id, &"easy")
		var n := _tuned(style.id, &"normal")
		var h := _tuned(style.id, &"hard")
		var ordered: bool = e["reaction_frames"] > n["reaction_frames"] and n["reaction_frames"] > h["reaction_frames"]
		for key in ["block_chance", "parry_chance", "punish_chance"]:
			ordered = ordered and e[key] < n[key] and n[key] <= h[key]
		var capped: bool = true
		for key in EnemyAI.TUNABLE:
			capped = capped and h[key] <= 0.95
		var own: bool = true
		for key in style.ai_tuning:
			own = own and is_equal_approx(float(n[key]), float(style.ai_tuning[key]))
		_check(ordered and capped and own, "%s: Easy < Normal < Hard, Hard capped, Normal = the style's tuning" % style.id)
	var ai := EnemyAI.new()
	root.add_child(ai)
	_tuned(&"taekwondo", &"hard", ai)
	var again := _tuned(&"taekwondo", &"normal", ai)
	_check(again == _tuned(&"taekwondo", &"normal"), "a re-setup at Normal forgets a previous Hard")
	ai.free()

	EnemyAI.selected_difficulty = &"normal"
	var d := Driver.new()
	d.tree = self
	d.fails = _fails
	root.add_child(d)
	change_scene_to_file("res://scenes/main.tscn")
