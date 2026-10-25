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
		return (main.get_node("Player") as Fighter).stance != (main.get_node("Enemy") as Fighter).stance

	func _physics_process(_d: float) -> void:
		frame += 1
		var main := tree.current_scene
		if frame == 1:
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
			1: check(p0_e0_differ(main), "match starts with different stances")
			3: check(intent.attack == CombatData.AttackType.KICK, "L alone -> side kick")
			7: check(intent.attack == CombatData.AttackType.HIGH_KICK, "W + L -> high kick")
			11: check(intent.attack == CombatData.AttackType.SWEEP, "S + L -> sweep")
			15:
				check(intent.attack == CombatData.AttackType.NONE and intent.crouch, "S alone -> crouch (no attack)")
			19: check(not intent.jump and intent.attack == CombatData.AttackType.NONE, "W alone does nothing (no jump)")
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
				check(p.stance != e.stance, "player and AI stances differ after cycling (P=%s, AI=%s)"
					% [Stances.stance_name(p.stance), Stances.stance_name(e.stance)])
				check(Stances.player_choice == p.stance, "player stance is remembered for restarts")
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
				check(e.stance != p.stance, "stances never match at the end of the test")
			225:
				# Quiet the AI and move it away so the player can stand and guard.
				(main.get_node("EnemyAI") as EnemyAI).setup(null, null)
				e.position.x = p.position.x + 400.0 if p.position.x < 640.0 else p.position.x - 400.0
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
