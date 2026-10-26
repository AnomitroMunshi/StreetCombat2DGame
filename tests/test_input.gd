extends SceneTree
## Checks the real keyboard mapping through main.gd's input reader.

class Driver extends Node:
	var tree: SceneTree
	var frame: int = 0
	var fails: int = 0
	var parry_seen: bool = false

	func check(cond: bool, msg: String) -> void:
		print(("  ok   " if cond else "  FAIL ") + msg)
		if not cond:
			fails += 1

	func p0_e0_differ(main: Node) -> bool:
		return (main.get_node("Player") as Fighter).style.id != (main.get_node("Enemy") as Fighter).style.id

	func _physics_process(_d: float) -> void:
		frame += 1
		var main := tree.current_scene
		if frame == 1:
			# Taekwondo has a kick on every kick button (and a back kick).
			main.call("select_style", &"taekwondo")
			main.call("start_match", true)
		# Godot reports a scripted press as "just pressed" on the next physics
		# frame, so: press on frame N, check on N + 1, release on N + 2.
		if frame % 4 == 0 and frame < 255 and frame != 260:
			for a in ["attack_light", "attack_heavy", "attack_technique", "mod_up", "mod_down", "jump",
					"move_left", "move_right", "cycle_stance"]:
				Input.action_release(a)
		# Each mapping check: keys pressed on frame N, read on N + 1.
		var cases := {
			2: [["attack_light"], &"light", "J alone -> light"],
			6: [["attack_heavy"], &"heavy", "K alone -> heavy"],
			10: [["attack_technique"], &"technique", "L alone -> technique"],
			14: [["mod_up", "attack_light"], &"up_light", "W + J -> up_light"],
			18: [["mod_up", "attack_heavy"], &"up_heavy", "W + K -> up_heavy"],
			22: [["mod_down", "attack_light"], &"down_light", "S + J -> down_light"],
			26: [["mod_down", "attack_heavy"], &"down_heavy", "S + K -> down_heavy"],
			30: [["move_left", "attack_light"], &"light", "A + J -> light (A is never a modifier)"],
			34: [["move_right", "attack_heavy"], &"heavy", "D + K -> heavy (D is never a modifier)"],
			38: [["mod_up", "mod_down", "attack_light"], &"up_light", "W + S + J -> up_light (W wins)"],
			42: [["mod_up", "attack_technique"], &"technique", "W + L -> technique (L has no variants)"],
			46: [["mod_down"], &"", "S alone -> crouch (no attack)"],
			50: [["mod_up"], &"", "W alone does nothing (no jump)"],
		}
		if cases.has(frame):
			for a in cases[frame][0]:
				Input.action_press(a)
		# Only read input ourselves on the mapping-check frames; elsewhere the
		# game is the only reader (reading twice would double-count taps).
		var intent := CombatData.Intent.new()
		if frame <= 51:
			intent = main.call("_read_player_intent")
		if cases.has(frame - 1):
			var c: Array = cases[frame - 1]
			check(intent.slot == c[1], "%s (%s)" % [c[2], intent.slot])
			if frame == 47:
				check(intent.crouch, "S alone crouches")
			if frame == 51:
				check(not intent.jump, "W alone is not a jump")
		if frame == 1:
			check(p0_e0_differ(main), "player and rival have different martial arts")
		match frame:
			100:
				Input.action_press("move_right")  # first tap
			104:
				Input.action_press("move_right")  # second tap (released at 104 first), 4 frames later
			132:
				Input.action_press("move_left")
			152:
				Input.action_press("move_left")  # too slow: 20 frames apart
		if frame >= 200 and frame < 215:
			Input.action_press("mod_down")
		if frame >= 210 and frame < 215:
			Input.action_press("block")
		if frame == 215:
			Input.action_release("mod_down")
			Input.action_release("block")
		if frame >= 170 and frame <= 186 and frame % 4 == 2:
			Input.action_press("cycle_stance")
		var p: Fighter = main.get_node("Player")
		var e: Fighter = main.get_node("Enemy")
		match frame:
			107:
				check(p.state == Fighter.State.DODGE, "double-tap D -> player dodges (state %s)" % p.get_state_name())
			154:
				check(p.state != Fighter.State.DODGE, "taps 20 frames apart -> no dodge")
			190:
				check(p.style.id == &"taekwondo" and p.stance == p.style.stance, "Q during a match does not change the locked style or stance")
				check(StyleRegistry.player_choice == p.style.id, "player style is remembered for restarts")
			206:
				check(p.state == Fighter.State.CROUCH and p.is_crouched(), "holding S -> player crouches")
			214:
				check(p.state == Fighter.State.BLOCK and p.is_crouched(), "S + Shift -> low block")
			220:
				check(not p.is_crouched(), "releasing S stands back up")
			221:
				var w_bound := false
				for ev in InputMap.action_get_events("jump"):
					if (ev as InputEventKey).physical_keycode == KEY_W:
						w_bound = true
				check(not w_bound and InputMap.action_get_events("jump").size() == 1, "jump is bound to Space only")
				check(e.style.id != p.style.id, "styles still differ at the end of the test")
			156:
				# Quiet the AI and move it away so the player can crouch, stand and guard.
				(main.get_node("EnemyAI") as EnemyAI).setup(null, null)
				e.position.x = p.position.x + 400.0 if p.position.x < 640.0 else p.position.x - 400.0
				# A hit landed just before this (knockdown / get-up) must not
				# still be playing when the crouch checks run.
				p.airborne = false
				p.position.y = p.ground_y
				p.call("_enter_state", Fighter.State.IDLE)
			260:
				# Standing still, then away (A) + K together: still the plain K move.
				Input.action_press("move_left")
				Input.action_press("attack_heavy")
			261:
				Input.action_press("move_left")
			262:
				check(p.current_attack != null and p.current_attack.type == CombatData.AttackType.KICK,
					"standing + away + K -> side kick, no back kick (%s)" % p.get_debug_label())
				Input.action_release("move_left")
				Input.action_release("attack_heavy")
			300, 301, 302, 303, 304, 305, 306, 307, 308, 309, 310:
				# Walking toward while pressing W + K: the high variant, not a toward move.
				Input.action_press("move_right" if p.facing > 0 else "move_left")
				if frame == 309:
					Input.action_press("mod_up")
					Input.action_press("attack_heavy")
			311:
				check(p.current_attack != null and p.current_attack.type == CombatData.AttackType.HIGH_KICK,
					"walking toward + W + K -> high roundhouse (%s)" % p.get_debug_label())
				Input.action_release("move_left")
				Input.action_release("move_right")
				Input.action_release("mod_up")
				Input.action_release("attack_heavy")
			340, 341, 342:
				Input.action_press("block")
				if p.state == Fighter.State.BLOCK:
					parry_seen = parry_seen or p.is_parry_active()
			343:
				check(parry_seen, "pressing Shift opens a parry window (%s)" % p.get_debug_label())
				Input.action_release("block")
			350:
				print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
				tree.quit(fails)

func _initialize() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var d := Driver.new()
	d.tree = self
	d.process_physics_priority = -100
	root.add_child(d)
