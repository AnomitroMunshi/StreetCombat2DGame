extends SceneTree
## Beginner tutorial, played through the real scene with real inputs (Boxing):
## TUTORIAL from the pre-match screen, then every step finished by doing it
## (walk in, light hit, heavy hit, block 2 punches, low-block 2 sweeps, a
## 3-hit chain, the signature). Then skip (N) and replay (U).

const STEP_LIMIT: int = 900


class Driver extends Node:
	var tree: SceneTree
	var fails: int = 0
	var frame: int = 0
	var step_frames: int = 0
	var last_step: int = -1
	var pressed: Array = []
	var rival_style: StringName = &""

	func check(cond: bool, msg: String) -> void:
		print(("  ok   " if cond else "  FAIL ") + msg)
		if not cond:
			fails += 1

	func hold(actions: Array) -> void:
		for a in pressed:
			if not a in actions:
				Input.action_release(a)
		for a in actions:
			Input.action_press(a)
		pressed = actions

	func finish() -> void:
		hold([])
		print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
		tree.quit(1 if fails > 0 else 0)

	func _physics_process(_d: float) -> void:
		frame += 1
		var main := tree.current_scene
		if main == null:
			return
		var hud: Hud = main.get_node("HUD")
		var p: Fighter = main.get_node("Player")
		var e: Fighter = main.get_node("Enemy")
		if frame == 2:
			hud.style_chosen.emit(&"boxing")
			main.call("confirm_style")
			return
		if frame == 4:
			rival_style = e.style.id
			check(hud.is_tutorial_button_visible(), "TUTORIAL is offered on the pre-match screen")
			hud.tutorial_pressed.emit()
			return
		var tr: TrainingMode = main.get("training")
		if tr == null or tr.tutorial == null:
			if frame > 10:
				check(false, "the tutorial starts")
				finish()
			return
		var tut: Tutorial = tr.tutorial
		if tut.step != last_step:
			if last_step >= 0:
				print("  ok   step %d done in %d frames" % [last_step + 1, step_frames])
			last_step = tut.step
			step_frames = 0
			if tut.step == Tutorial.Step.LIGHT:
				check(hud.get_lesson_text().contains("J"), "the step text names the bound key (J)")
		step_frames += 1
		if step_frames > STEP_LIMIT:
			check(false, "step %d (%s) finishes by doing it" % [tut.step + 1, Tutorial.Step.keys()[tut.step]])
			finish()
			return
		var gap := absf(p.position.x - e.position.x)
		var toward := "move_right" if e.position.x > p.position.x else "move_left"
		var beat := step_frames % 40
		match tut.step:
			Tutorial.Step.MOVE:
				hold([toward])
			Tutorial.Step.LIGHT:
				hold([toward] if gap > 95.0 else (["attack_light"] if beat < 2 else []))
			Tutorial.Step.HEAVY:
				hold([toward] if gap > 95.0 else (["attack_heavy"] if beat < 2 else []))
			Tutorial.Step.BLOCK:
				hold(["block"])
			Tutorial.Step.LOW_BLOCK:
				hold(["block", "mod_down"])
			Tutorial.Step.CHAIN:
				var b := step_frames % 70
				if gap > 95.0 and b > 40:
					hold([toward])
				else:
					hold(["attack_light"] if b in [0, 1, 12, 13] else (["attack_heavy"] if b in [24, 25] else []))
			Tutorial.Step.SIGNATURE:
				hold(["signature"] if beat < 2 else [])
			Tutorial.Step.DONE:
				hold([])
				check(hud.get_lesson_text().contains("TUTORIAL COMPLETE"), "the last step says the tutorial is complete")
				print("[skip / replay]")
				main.call("training_action", &"lesson_replay")
				check(tut.step == Tutorial.Step.MOVE, "U replays from step 1")
				main.call("training_action", &"lesson_skip")
				main.call("training_action", &"lesson_skip")
				check(tut.step == Tutorial.Step.HEAVY, "N skips a step (now step %d)" % (tut.step + 1))
				main.call("training_action", &"lesson_skip")
				main.call("training_action", &"lesson_skip")
				check(tut.step == Tutorial.Step.LOW_BLOCK and e.style.id == &"kung_fu", "the low-block step borrows Kung Fu's sweep")
				main.call("training_action", &"lesson_skip")
				check(tut.step == Tutorial.Step.CHAIN and e.style.id == rival_style, "after it the dummy has its own style back (%s)" % e.style.id)
				finish()


func _initialize() -> void:
	var d := Driver.new()
	d.tree = self
	d.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(d)
	change_scene_to_file("res://scenes/main.tscn")
