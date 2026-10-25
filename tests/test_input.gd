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
		if frame % 4 == 0 and frame < 255:
			for a in ["attack_kick", "mod_up", "mod_down", "jump", "move_left", "move_right", "cycle_stance"]:
				Input.action_release(a)
		match frame:
			2:
				Input.action_press("attack_kick")
			6:
				Input.action_press("mod_up")
				Input.action_press("attack_kick")
			10:
				Input.action_press("mod_down")
				Input.action_press("attack_kick")
			14:
				Input.action_press("mod_down")
			18:
				Input.action_press("mod_up")
		# Only read input ourselves on the mapping-check frames; elsewhere the
		# game is the only reader (reading twice would double-count taps).
		var intent := CombatData.Intent.new()
		if frame <= 19:
			intent = main.call("_read_player_intent")
		match frame:
			1: check(p0_e0_differ(main), "player and rival have different martial arts")
			3: check(intent.slot == &"kick", "L alone -> kick slot (%s)" % intent.slot)
			7: check(intent.slot == &"up_kick", "W + L -> up_kick slot (%s)" % intent.slot)
			11: check(intent.slot == &"down_kick", "S + L -> down_kick slot (%s)" % intent.slot)
			15:
				check(intent.slot == &"" and intent.crouch, "S alone -> crouch (no attack)")
			19: check(not intent.jump and intent.slot == &"", "W alone does nothing (no jump)")
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
				# Standing still, then away (A) + L together: back kick.
				Input.action_press("move_left")
				Input.action_press("attack_kick")
			261:
				Input.action_press("move_left")
			262:
				check(p.current_attack != null and p.current_attack.type == CombatData.AttackType.BACK_KICK,
					"standing + away + L -> back kick (%s)" % p.get_debug_label())
				Input.action_release("move_left")
				Input.action_release("attack_kick")
			300, 301, 302, 303, 304, 305, 306, 307, 308, 309, 310:
				# Retreating for a while, then L: stays a side kick.
				Input.action_press("move_left")
				if frame == 309:
					Input.action_press("attack_kick")
			311:
				check(p.current_attack != null and p.current_attack.type == CombatData.AttackType.KICK,
					"retreating + L -> side kick, not a back kick (%s)" % p.get_debug_label())
				Input.action_release("move_left")
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
