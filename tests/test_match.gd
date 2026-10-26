extends SceneTree
## Headless end-to-end match: loads main.tscn, drives the player through the
## real InputMap actions against the real AI, and checks invariants.

class Driver extends Node:
	var tree: SceneTree
	var main: Node = null
	var frame: int = 0
	var phase: String = "fight"
	var ko_frame: int = -1
	var hp_at_ko: Array[int] = []
	var restart_frame: int = -1
	var fails: int = 0
	var max_combo: int = 0
	var enemy_blocks: int = 0
	var player_hits_taken: int = 0
	var prev_player_hp: int = 100
	var prev_enemy_state: int = 0
	var ai_states_seen: Dictionary = {}
	var overlap_reported: bool = false

	func fail(msg: String) -> void:
		fails += 1
		printerr("  FAIL ", msg)

	func release_all() -> void:
		for a in ["move_left", "move_right", "attack_light", "attack_heavy", "attack_technique", "mod_up", "mod_down", "jump", "block", "restart"]:
			Input.action_release(a)

	func _physics_process(_d: float) -> void:
		frame += 1
		release_all()
		main = tree.current_scene
		if main == null:
			return
		var p: Fighter = main.get_node("Player")
		var e: Fighter = main.get_node("Enemy")
		var ai: EnemyAI = main.get_node("EnemyAI")
		if phase == "fight" and main.call("get_round_state_name") in ["STYLE_SELECT", "PRE_MATCH"]:
			# Fixed styles so the match is reproducible: the rival is otherwise random.
			main.call("select_style", &"kickboxing")
			e.set_style(StyleRegistry.by_id(&"boxing"))
			main.call("start_match", true)
		ai_states_seen[ai.get_state_name().get_slice(" ", 0)] = true

		if phase == "fight":
			if p.health > prev_player_hp:
				fail("player health increased")
			if p.health < prev_player_hp:
				player_hits_taken += 1
			prev_player_hp = p.health
			if e.state == Fighter.State.BLOCKSTUN and prev_enemy_state != Fighter.State.BLOCKSTUN:
				enemy_blocks += 1
			prev_enemy_state = e.state
			max_combo = maxi(max_combo, e.received_combo)
			# Pushboxes: standing bodies never overlap (checked after the game's tick).
			# (Finishers are choreographed and close in deliberately: FIGHTING only.)
			if main.call("get_round_state_name") == "FIGHTING" and not p.airborne and not e.airborne and not p.is_down() and not e.is_down() 					and absf(e.position.x - p.position.x) < Fighter.PUSH_HALF_WIDTH * 2.0 - 0.5 and not overlap_reported:
				overlap_reported = true
				fail("fighters overlapped: %.1f px apart" % absf(e.position.x - p.position.x))
			if p.state == Fighter.State.KO or e.state == Fighter.State.KO:
				phase = "ko"
				ko_frame = frame
				hp_at_ko = [p.health, e.health]
				print("  KO at frame %d  hp P=%d E=%d  finisher: %s" % [frame, p.health, e.health, main.get("last_finisher_name")])
				# A simultaneous lethal trade (double K.O.) correctly skips the finisher.
				var double_ko := p.health == 0 and e.health == 0
				if main.get("last_finisher_name") == "" and not double_ko:
					fail("no finisher played before KO")
				return
			# Scripted player: close distance, then J,J,K chains; block sometimes.
			var dist := absf(e.position.x - p.position.x)
			var cycle := frame % 90
			if dist > 100.0:
				Input.action_press("move_right" if e.position.x > p.position.x else "move_left")
			elif cycle >= 60 and cycle < 80:
				Input.action_press("block")
			elif cycle == 0 or cycle == 9 or cycle == 18:
				# J, K, then S + J (jab, cross, body hook).
				if cycle == 18:
					Input.action_press("mod_down")
				Input.action_press(["attack_light", "attack_heavy", "attack_light"][cycle / 9])
			elif cycle == 35:
				Input.action_press("mod_up")
				Input.action_press("attack_heavy")
			elif cycle == 44:
				Input.action_press("jump")
				Input.action_press("move_right" if e.position.x > p.position.x else "move_left")
			elif cycle == 58:
				Input.action_press("attack_technique")
			if frame > 7200:
				fail("no KO within 2 minutes of play")
				phase = "done"
		elif phase == "ko":
			# Mash attacks after KO: nothing must change.
			Input.action_press("attack_light" if frame % 2 == 0 else "attack_heavy")
			if [p.health, e.health] != hp_at_ko:
				fail("health changed after KO")
			if frame - ko_frame == 120:
				Input.action_press("restart")
				restart_frame = frame
				phase = "restarted"
		elif phase == "restarted":
			if frame - restart_frame == 5:
				if p.health != p.max_health or e.health != e.max_health or p.state == Fighter.State.KO 						or main.call("get_round_state_name") != "PRE_MATCH":
					fail("restart did not reset the match")
				else:
					print("  restart ok: fresh match back in PRE_MATCH")
				phase = "done"
		elif phase == "done":
			print("  max combo received by enemy: %d" % max_combo)
			print("  enemy block events: %d   hits taken by player: %d" % [enemy_blocks, player_hits_taken])
			print("  AI states seen: %s" % [ai_states_seen.keys()])
			if max_combo < 2:
				fail("never saw a multi-hit combo")
			if player_hits_taken == 0:
				fail("AI never landed a hit")
			print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
			tree.quit(1 if fails > 0 else 0)


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var main := scene.instantiate()
	root.add_child(main)
	current_scene = main
	var d := Driver.new()
	d.tree = self
	d.process_physics_priority = -100
	root.add_child(d)
