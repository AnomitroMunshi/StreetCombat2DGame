extends SceneTree
## Training ground, driven through the real scene: entering from the pre-match
## screen, the move readout and frame advantage, the dummy never going down,
## health refill, the blocking dummy, pause and single-frame step, speed, the
## finisher tester returning to training, and exiting back to the pre-match.

class Driver extends Node:
	var tree: SceneTree
	var frame: int = 0
	var fails: int = 0
	var phase: String = "start"
	var phase_frame: int = 0
	var tick_mark: int = 0
	var saw_slow: bool = false

	func check(cond: bool, msg: String) -> void:
		print(("  ok   " if cond else "  FAIL ") + msg)
		if not cond:
			fails += 1

	func go(next: String) -> void:
		phase = next
		phase_frame = 0

	func place(p: Fighter, e: Fighter, gap: float) -> void:
		for f: Fighter in [p, e]:
			f.velocity_x = 0.0
		p.position.x = 560.0
		e.position.x = 560.0 + gap
		p.face_opponent()
		e.face_opponent()

	func _physics_process(_d: float) -> void:
		frame += 1
		phase_frame += 1
		for a in ["attack_light", "attack_heavy"]:
			Input.action_release(a)
		var main := tree.current_scene
		if main == null:
			return
		var p: Fighter = main.get_node("Player")
		var e: Fighter = main.get_node("Enemy")
		var hud: Hud = main.get_node("HUD")
		var state: String = main.call("get_round_state_name")
		var tr: TrainingMode = main.get("training")
		match phase:
			"start":
				if phase_frame == 2:
					hud.style_chosen.emit(&"kickboxing")
					main.call("confirm_style")
				if phase_frame == 3:
					check(state == "PRE_MATCH" and hud.is_training_button_visible(), "TRAINING is offered beside START MATCH")
					hud.press_training()
				if phase_frame == 5:
					check(state == "FIGHTING" and tr != null, "TRAINING starts the fight at once")
					check(hud.is_training_visible(), "training panels shown")
					check(p.min_health == 1 and e.min_health == 1, "both fighters are kept at 1 HP minimum")
					go("jab")
			"jab":
				if phase_frame == 5:
					place(p, e, 85.0)
				if phase_frame == 8:
					Input.action_press("attack_light")
				if phase_frame == 70:
					check(tr.last_move != null and tr.last_move.display_name == "Jab", "last move readout: Jab")
					check(tr.last_result == "HIT", "result readout: HIT (%s)" % tr.last_result)
					check(tr.advantage_text.ends_with("on hit"), "frame advantage measured on hit (%s)" % tr.advantage_text)
					check(tr.info_text().contains("startup 5"), "frame data shown (startup)")
					go("immortal")
			"immortal":
				if phase_frame == 5:
					place(p, e, 90.0)
				if phase_frame == 8:
					Input.action_press("attack_heavy")
				if p.state == Fighter.State.ATTACK and p.get_phase() == Fighter.Phase.STARTUP:
					e.health = 3  # lethal for the cross, set right before it lands
				if phase_frame == 70:
					check(e.health == 1 and e.state != Fighter.State.FINISHED and state == "FIGHTING",
						"a lethal hit leaves the dummy at 1 HP, no finisher (hp %d)" % e.health)
				if phase_frame == 200:
					check(e.health == e.max_health and p.health == p.max_health, "health refills to full once the action settles (%d / %d)" % [e.health, e.max_health])
					go("block")
			"block":
				if phase_frame == 1:
					main.call("training_action", &"dummy")
					main.call("training_action", &"dummy")
					check(tr.dummy_mode == TrainingMode.Dummy.BLOCK, "dummy mode cycles to BLOCK ALL")
					place(p, e, 85.0)
				if phase_frame == 25:
					Input.action_press("attack_light")
				if phase_frame == 90:
					check(tr.last_result == "BLOCKED", "the blocking dummy blocks (%s)" % tr.last_result)
					check(tr.advantage_text.ends_with("on blocked"), "frame advantage measured on block (%s)" % tr.advantage_text)
					go("pause")
			"pause":
				if phase_frame == 1:
					main.call("training_action", &"pause")
				if phase_frame == 3:
					tick_mark = main.get("_tick")
				if phase_frame == 12:
					check(tree.paused and main.get("_tick") == tick_mark, "pause freezes the game")
					main.call("training_action", &"step")
				if phase_frame == 16:
					check(main.get("_tick") == tick_mark + 1 and tree.paused, "step advances exactly one frame (%d)" % (main.get("_tick") - tick_mark))
					main.call("training_action", &"pause")
				if phase_frame == 18:
					check(not tree.paused, "unpaused")
					go("speed")
			"speed":
				if phase_frame == 1:
					main.call("training_action", &"speed")
					check(is_equal_approx(Engine.time_scale, 0.5), "speed: 50%")
					main.call("training_action", &"speed")
					main.call("training_action", &"speed")
					check(is_equal_approx(Engine.time_scale, 1.0), "speed cycles back to 100%")
					main.call("training_action", &"dummy")
					main.call("training_action", &"dummy")
					main.call("training_action", &"dummy")
					check(tr.dummy_mode == TrainingMode.Dummy.STAND, "dummy back to STAND")
					go("finisher")
			"finisher":
				if phase_frame == 20:
					main.call("training_action", &"play_finisher")
				if phase_frame == 22:
					check(state == "FINISHER", "PLAY FINISHER starts the selected finisher")
				if state == "FINISHER" and Engine.physics_ticks_per_second < 60:
					saw_slow = true
				if phase_frame > 30 and state == "FIGHTING" and phase == "finisher":
					check(saw_slow, "the finisher actually slows the simulation (cinematic speed)")
				if phase_frame > 30 and state == "FIGHTING":
					check(main.get("last_finisher_name") != "", "a finisher played (%s)" % main.get("last_finisher_name"))
					check(e.health == e.max_health and e.state == Fighter.State.IDLE and p.state == Fighter.State.IDLE,
						"after the finisher both are back, fresh, in training")
					check(is_equal_approx(Engine.time_scale, 1.0) and Engine.physics_ticks_per_second == 60,
						"game speed restored after the finisher (ticks %d)" % Engine.physics_ticks_per_second)
					go("exit")
				elif phase_frame == 900:
					check(false, "finisher returned to training")
					go("exit")
			"exit":
				if phase_frame == 1:
					main.call("training_action", &"exit")
				if phase_frame == 20:
					check(state == "PRE_MATCH" and tr == null, "EXIT returns to the pre-match screen (%s)" % state)
					check(not tree.paused and is_equal_approx(Engine.time_scale, 1.0) and Engine.physics_ticks_per_second == 60,
						"nothing left paused or slowed")
					print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
					tree.quit(fails)


func _initialize() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var d := Driver.new()
	d.tree = self
	d.process_mode = Node.PROCESS_MODE_ALWAYS
	d.process_physics_priority = -100
	root.add_child(d)
