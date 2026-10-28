extends SceneTree
## Movement through the real scene and keys (AI quiet): jump cross-ups, rolls,
## dodges, walking (must never pass through), wall cases, facing after a side
## change, and left/right symmetry. Each scenario restarts from a fresh layout.

class Driver extends Node:
	var tree: SceneTree
	var fails: int = 0
	var frame: int = 0
	var step_i: int = -1
	var step_frame: int = 0
	var p: Fighter
	var e: Fighter
	var main: Node
	var log_lines: Array[String] = []
	var crossed_seen: bool = false
	var min_gap_ground: float = 1e9

	func check(cond: bool, msg: String) -> void:
		print(("  ok   " if cond else "  FAIL ") + msg)
		if not cond:
			fails += 1
			for l in log_lines.slice(-12):
				print("       ", l)

	func release_all() -> void:
		for a in ["move_left", "move_right", "jump", "mod_down", "attack_light", "attack_technique", "block"]:
			Input.action_release(a)

	## Scenario: [name, player x, enemy x, setup Callable(frame) -> void, length, verify Callable]
	func scenarios() -> Array:
		return [
			["jump over a standing rival (facing right)", 545.0, 640.0, func(f: int) -> void:
				if f >= 2 and f < 40: Input.action_press("move_right")
				if f == 2: Input.action_press("jump"),
				90, func() -> void:
				check(p.position.x > e.position.x + 50.0, "player landed on the far side (p %.0f, e %.0f)" % [p.position.x, e.position.x])
				check(p.facing == -1 and e.facing == 1, "both fighters face each other after the cross-up")],
			["jump over a standing rival (facing left)", 735.0, 640.0, func(f: int) -> void:
				if f >= 2 and f < 40: Input.action_press("move_left")
				if f == 2: Input.action_press("jump"),
				90, func() -> void:
				check(p.position.x < e.position.x - 50.0, "player landed on the far side, mirrored (p %.0f, e %.0f)" % [p.position.x, e.position.x])
				check(p.facing == 1 and e.facing == -1, "facing swapped, mirrored")],
			["roll through the rival (hold S, double-tap toward)", 560.0, 640.0, func(f: int) -> void:
				Input.action_press("mod_down")
				if f == 2 or f == 6: Input.action_press("move_right"),
				80, func() -> void:
				check(p.position.x > e.position.x + 50.0, "forward roll ends on the far side (p %.0f, e %.0f)" % [p.position.x, e.position.x])],
			["backward roll retreats", 560.0, 640.0, func(f: int) -> void:
				Input.action_press("mod_down")
				if f == 2 or f == 6: Input.action_press("move_left"),
				80, func() -> void:
				check(p.position.x < 470.0 and p.facing == 1, "backward roll retreated %.0f px, still facing the rival" % (560.0 - p.position.x))],
			["walking never passes through", 560.0, 640.0, func(f: int) -> void:
				Input.action_press("move_right"),
				120, func() -> void:
				check(p.position.x < e.position.x, "walking into the rival never ends on the other side")
				check(min_gap_ground >= Fighter.PUSH_HALF_WIDTH * 2.0 - 0.5, "grounded bodies never overlap (min %.1f px)" % min_gap_ground)],
			["dodge from mid range: a short step, no pass-through", 530.0, 640.0, func(f: int) -> void:
				if f == 2 or f == 6: Input.action_press("move_right"),
				60, func() -> void:
				check(p.position.x < e.position.x, "a dodge from 110 px never crosses the rival (p %.0f)" % p.position.x)],
			["dodge toward a very close rival slips behind them", 570.0, 640.0, func(f: int) -> void:
				if f == 2 or f == 6: Input.action_press("move_right"),
				60, func() -> void:
				check(p.position.x > e.position.x + 50.0, "close dodge slips past to the far side (p %.0f, e %.0f)" % [p.position.x, e.position.x])
				check(p.facing == -1 and e.facing == 1, "both turn to face each other after the slip")],
			["close slip, mirrored", 710.0, 640.0, func(f: int) -> void:
				if f == 2 or f == 6: Input.action_press("move_left"),
				60, func() -> void:
				check(p.position.x < e.position.x - 50.0, "mirrored close dodge slips past (p %.0f, e %.0f)" % [p.position.x, e.position.x])],
			["roll toward a rival pinned at the right wall", Fighter.ARENA_MAX_X - 110.0, Fighter.ARENA_MAX_X - 20.0, func(f: int) -> void:
				Input.action_press("mod_down")
				if f == 2 or f == 6: Input.action_press("move_right"),
				90, func() -> void:
				check(absf(p.position.x - e.position.x) >= Fighter.PUSH_HALF_WIDTH * 2.0 - 0.5, "no room: fighters end separated, not stuck inside each other")
				check(p.position.x <= Fighter.ARENA_MAX_X and e.position.x <= Fighter.ARENA_MAX_X, "both inside the arena")],
			["jump over a rival standing at the left wall", Fighter.ARENA_MIN_X + 130.0, Fighter.ARENA_MIN_X + 30.0, func(f: int) -> void:
				if f >= 2 and f < 40: Input.action_press("move_left")
				if f == 2: Input.action_press("jump"),
				100, func() -> void:
				check(absf(p.position.x - e.position.x) >= Fighter.PUSH_HALF_WIDTH * 2.0 - 0.5, "wall cross-up resolves to a clean separation (gap %.0f)" % absf(p.position.x - e.position.x))
				check(p.position.x >= Fighter.ARENA_MIN_X and e.position.x >= Fighter.ARENA_MIN_X, "both inside the arena")],
			["jump over a rival walking toward you", 520.0, 660.0, func(f: int) -> void:
				if f >= 2 and f < 40: Input.action_press("move_right")
				if f == 2: Input.action_press("jump")
				if f < 30: e.position.x -= 2.0,
				90, func() -> void:
				check(p.position.x > e.position.x + 50.0, "cleared a moving rival (p %.0f, e %.0f)" % [p.position.x, e.position.x])],
			["both jump at the same time", 580.0, 660.0, func(f: int) -> void:
				if f == 2:
					Input.action_press("jump")
					var ji := CombatData.Intent.new()
					ji.jump = true
					e.push_intent(ji),
				80, func() -> void:
				check(absf(p.position.x - e.position.x) >= Fighter.PUSH_HALF_WIDTH * 2.0 - 0.5 and p.position.x < e.position.x,
					"simultaneous jumps land separated, sides kept (p %.0f, e %.0f)" % [p.position.x, e.position.x])],
			["after a cross-up, an attack hits the rival's turned guard in the back", 545.0, 640.0, func(f: int) -> void:
				var ai: EnemyAI = main.get_node("EnemyAI")
				if f == 1:
					ai.setup(e, p)
					ai.aggression = 0.0
					ai.reaction_frames = 9999
					ai.parry_chance = 0.0
					ai.dodge_chance = 0.0
					ai.anti_air_chance = 0.0  # this scenario is about the guard, not anti-air
					e.x_cooldown = CombatData.X_COOLDOWN_FRAMES  # keep the held-guard fixture from starting an X move
				ai.set("_state", EnemyAI.AIState.BLOCK)
				ai.set("_timer", 100)
				if f >= 2 and f < 40: Input.action_press("move_right")
				if f == 2: Input.action_press("jump")
				if f == 50: Input.action_press("attack_light")
				if e.state == Fighter.State.HITSTUN and not crossed_seen:
					crossed_seen = true
					log_lines.append("rival hit while %s, facing %d" % [e.get_state_name(), e.facing]),
				90, func() -> void:
				check(crossed_seen and e.health < 100, "landing behind and jabbing beats the held guard (rival hp %d)" % e.health)
				crossed_seen = false
				var ai: EnemyAI = main.get_node("EnemyAI")
				ai.setup(null, null)],
			["AI waits a human reaction time after a side change", 545.0, 640.0, func(f: int) -> void:
				var ai: EnemyAI = main.get_node("EnemyAI")
				if f == 1:
					ai.setup(e, p)
					ai.aggression = 0.0
					ai.reaction_frames = 6
					ai.anti_air_chance = 0.4
				if f >= 2 and f < 40: Input.action_press("move_right")
				if f == 2: Input.action_press("jump")
				var w: int = ai.get("_side_wait")
				if w > 0 and not crossed_seen:
					crossed_seen = true
					log_lines.append("side wait %d" % w)
					check(w >= ai.reaction_frames, "AI pauses %d ticks (>= reaction %d) when the player crosses" % [w, ai.reaction_frames]),
				90, func() -> void:
				check(crossed_seen, "AI noticed the side change")
				crossed_seen = false
				(main.get_node("EnemyAI") as EnemyAI).setup(null, null)],
		]

	func _physics_process(_d: float) -> void:
		frame += 1
		main = tree.current_scene
		if main == null:
			return
		p = main.get_node("Player")
		e = main.get_node("Enemy")
		if frame == 1:
			main.call("start_match", true)
		var list := scenarios()
		if step_i < 0 or step_frame >= int(list[step_i][4]):
			if step_i >= 0:
				(list[step_i][5] as Callable).call()
			step_i += 1
			if step_i >= list.size():
				print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
				tree.quit(fails)
				return
			print("[%s]" % list[step_i][0])
			(main.get_node("EnemyAI") as EnemyAI).setup(null, null)
			for f: Fighter in [p, e]:
				f.call("_enter_state", Fighter.State.IDLE)
				f.airborne = false
				f.velocity_x = 0.0
				f.velocity_y = 0.0
				f.jump_vx = 0.0
				f.position.y = 560.0
				f.health = 100
				f.stop_combat()
			p.position.x = list[step_i][1]
			e.position.x = list[step_i][2]
			p.face_opponent()
			e.face_opponent()
			step_frame = 0
			min_gap_ground = 1e9
			log_lines.clear()
			release_all()
			return
		step_frame += 1
		release_all()
		(list[step_i][3] as Callable).call(step_frame)
		log_lines.append("t%d p x%.0f h%.0f %s f%d | e x%.0f %s" % [step_frame, p.position.x, 560.0 - p.position.y,
			p.get_state_name(), p.facing, e.position.x, e.get_state_name()])
		if not p.airborne and not e.airborne and not p.is_crossing() and not e.is_crossing() and step_frame > 1:
			min_gap_ground = minf(min_gap_ground, absf(p.position.x - e.position.x))


func _initialize() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var d := Driver.new()
	d.tree = self
	d.process_physics_priority = -100
	root.add_child(d)
