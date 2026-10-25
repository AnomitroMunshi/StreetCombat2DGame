extends SceneTree
## Match flow: PRE_MATCH -> STANCE_PREP -> COUNTDOWN -> FIGHTING, driven through
## the real scene and InputMap. Checks the input lock, the countdown order and
## timing, that both sides unlock on the same tick, that mashing the button
## cannot start a second countdown, and that restarting mid-countdown returns to
## a clean pre-match with no stale countdown.

const ATTACK_KEYS: Array[String] = ["attack_light", "attack_heavy", "attack_kick", "attack_front_kick",
	"attack_backhand", "attack_uppercut", "jump", "block", "move_right", "move_left"]


class Driver extends Node:
	var tree: SceneTree
	var frame: int = 0
	var fails: int = 0
	var phase: String = "pre"
	var phase_frame: int = 0
	var counts: Array[String] = []
	var count_frames: Array[int] = []
	var poses_seen: Dictionary = {}
	var fight_frame: int = -1
	var player_first_attack: int = -1
	var locked_ok: bool = true
	var marks_ok: bool = false
	var pre_positions: Array[float] = []

	func check(cond: bool, msg: String) -> void:
		print(("  ok   " if cond else "  FAIL ") + msg)
		if not cond:
			fails += 1

	func release_all() -> void:
		for a in ATTACK_KEYS:
			Input.action_release(a)

	func _physics_process(_d: float) -> void:
		frame += 1
		phase_frame += 1
		var main := tree.current_scene
		if main == null:
			return
		var p: Fighter = main.get_node("Player")
		var e: Fighter = main.get_node("Enemy")
		var hud: Hud = main.get_node("HUD")
		var state: String = main.call("get_round_state_name")
		# Mash everything every other frame for the whole test.
		release_all()
		if frame % 2 == 0:
			Input.action_press(ATTACK_KEYS[(frame / 2) % ATTACK_KEYS.size()])
		for f: Fighter in [p, e]:
			poses_seen[f.prefight_pose] = true

		match phase:
			"pre":
				if phase_frame == 1:
					check(state == "PRE_MATCH", "game launches in PRE_MATCH (%s)" % state)
					check(hud.is_button_visible(), "START MATCH button is shown")
					pre_positions = [p.position.x, e.position.x]
				if state != "PRE_MATCH" or p.state != Fighter.State.IDLE or e.state != Fighter.State.IDLE:
					locked_ok = false
				if phase_frame == 60:
					check(locked_ok, "mashing keys before START: nobody moves, attacks or leaves IDLE")
					check(is_equal_approx(p.position.x, pre_positions[0]) and is_equal_approx(e.position.x, pre_positions[1]),
						"fighters stay on their pre-match spots")
					hud.press_button()
					hud.press_button()  # mashing the button
					main.call("start_match")  # and a stray direct call
					check(not hud.is_button_visible(), "button hides on click")
					phase = "prep"
					phase_frame = 0
					locked_ok = true
			"prep":
				var text := hud.get_countdown()
				if text != "" and (counts.is_empty() or counts[-1] != text):
					counts.append(text)
					count_frames.append(frame)
				if state == "FIGHTING" and fight_frame < 0:
					fight_frame = frame
				if fight_frame < 0:
					# Locked: no attacks, blocks, jumps, dodges for either side.
					for f: Fighter in [p, e]:
						if f.state not in [Fighter.State.IDLE, Fighter.State.WALK]:
							locked_ok = false
					if state == "COUNTDOWN" and not marks_ok:
						marks_ok = is_equal_approx(p.position.x, 440.0) and is_equal_approx(e.position.x, 840.0)
				elif player_first_attack < 0 and p.state == Fighter.State.ATTACK:
					player_first_attack = frame
				if fight_frame > 0 and frame - fight_frame == 30:
					check(locked_ok, "no combat action by either side before FIGHT")
					check(marks_ok, "both fighters reached their start marks before the countdown")
					check(poses_seen.has(&"relaxed") and poses_seen.has(&"salute") and poses_seen.has(&"glare"),
						"pre-fight poses played: relaxed, salute (player), glare (rival)")
					check(p.stance != e.stance, "player and rival start in different stances")
					check(counts == ["3", "2", "1", "FIGHT!"], "countdown order 3, 2, 1, FIGHT! (%s)" % [counts])
					var spacing_ok := count_frames.size() == 4
					for i in range(1, count_frames.size()):
						spacing_ok = spacing_ok and count_frames[i] - count_frames[i - 1] == 60
					check(spacing_ok, "one second (60 ticks) per number (%s)" % [count_frames])
					check(count_frames.size() == 4 and count_frames[3] == fight_frame, "FIGHT! appears on the unlock tick")
					check(player_first_attack > 0 and player_first_attack - fight_frame <= 2,
						"player can act right at FIGHT (attack on +%d)" % (player_first_attack - fight_frame))
					# Restart test: a fresh scene, start, then restart in the middle of "2".
					main.call("restart_match")
					phase = "restart_pre"
					phase_frame = 0
			"restart_pre":
				if phase_frame == 3:
					check(state == "PRE_MATCH" and p.health == p.max_health, "restart returns to PRE_MATCH with full health")
					hud.press_button()
				elif phase_frame == 3 + 100 + 75:
					check(state == "COUNTDOWN" and hud.get_countdown() == "2", "second match counting down (%s %s)" % [state, hud.get_countdown()])
					main.call("restart_match")
					phase = "restart_check"
					phase_frame = 0
			"restart_check":
				if state != "PRE_MATCH" or hud.get_countdown() != "":
					locked_ok = false
				if phase_frame == 300:
					check(locked_ok, "restart mid-countdown: stays in PRE_MATCH, the old countdown never fires")
					check(hud.is_button_visible(), "START MATCH is offered again")
					check(p.state == Fighter.State.IDLE and e.state == Fighter.State.IDLE, "both fighters idle")
					check(p.posture == 0.0 and e.posture == 0.0 and p.posture_lock == 0, "posture reset on restart")
					check(not p.is_crossing() and not e.is_crossing(), "no crossing / roll state survives a restart")
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
