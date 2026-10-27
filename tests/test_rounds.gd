extends SceneTree
## Best of 3: every round ends in a finisher; the next round starts with both
## fighters up at full health on their marks, focus carried over, "ROUND 2" /
## "FINAL ROUND" then FIGHT. Two round wins end the match at once (2-0 never
## plays a third round); 1-1 goes to a final round.

var _fails: int = 0


func _check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func _initialize() -> void:
	_run()


func _new_main() -> Node:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	return main


func _state(main: Node) -> String:
	return main.call("get_round_state_name")


## Knocks out `loser` with a finisher and waits until the KO screen moves on
## (next round's call, or the result).
func _finish_round(main: Node, loser_is_enemy: bool) -> void:
	var p: Fighter = main.get_node("Player")
	var e: Fighter = main.get_node("Enemy")
	var winner := p if loser_is_enemy else e
	var loser := e if loser_is_enemy else p
	loser.health = 0
	main.call("_start_finisher", winner, loser, FinisherDirector.Kind.PALM_FLURRY)
	var t := 0
	while _state(main) in ["FINISHER", "KO", "FIGHTING"] and t < 1500:
		await physics_frame
		t += 1


func _run() -> void:
	print("[2-0: the match ends after round 2]")
	var main := _new_main()
	await physics_frame
	var audio: GameAudio = main.get_node("Audio")
	var p: Fighter = main.get_node("Player")
	var e: Fighter = main.get_node("Enemy")
	main.call("confirm_style")
	main.call("start_match", true)
	await physics_frame
	_check(p.max_health == main.MATCH_HEALTH and p.health == main.MATCH_HEALTH and e.health == main.MATCH_HEALTH,
		"a match round starts at %d health" % main.MATCH_HEALTH)
	p.focus = 40.0
	await _finish_round(main, true)
	_check(_state(main) == "COUNTDOWN" and main.round_number == 2 and main.round_wins == [1, 0],
		"round 1 to the player: on to round 2 (%s, round %d, wins %s)" % [_state(main), main.round_number, main.round_wins])
	_check(p.health == p.max_health and e.health == e.max_health and e.state != Fighter.State.KO and not e.airborne,
		"both back up at full health")
	_check(is_equal_approx(p.focus, 40.0), "focus carries over between rounds (%.0f)" % p.focus)
	_check(absf(p.position.x - main.PLAYER_START_X) < 1.0 and absf(e.position.x - main.ENEMY_START_X) < 1.0,
		"both back on their start marks")
	_check(audio.announced.back() == &"round_2", "ROUND 2 is called (%s)" % [audio.announced.back()])
	var t := 0
	while _state(main) != "FIGHTING" and t < 300:
		await physics_frame
		t += 1
	_check(_state(main) == "FIGHTING" and audio.announced.back() == &"fight" and t >= main.ROUND_CALL_TICKS - 2,
		"then FIGHT, after the round call (%d ticks)" % t)
	await _finish_round(main, true)
	_check(_state(main) == "RESULT" and main.round_wins == [2, 0] and main.round_number == 2,
		"2-0: straight to the result, no third round (%s, wins %s)" % [_state(main), main.round_wins])
	_check(main.get("_result_text") == "%s WINS" % p.fighter_name, "the player wins the match")
	_check(audio.announced.count(&"ko") == 2, "K.O. called once per round")
	main.queue_free()
	await process_frame

	print("[1-1: a final round decides it]")
	main = _new_main()
	await physics_frame
	audio = main.get_node("Audio")
	p = main.get_node("Player")
	main.call("confirm_style")
	main.call("start_match", true)
	await physics_frame
	await _finish_round(main, true)
	t = 0
	while _state(main) != "FIGHTING" and t < 300:
		await physics_frame
		t += 1
	await _finish_round(main, false)
	_check(_state(main) == "COUNTDOWN" and main.round_number == 3 and main.round_wins == [1, 1],
		"1-1: round 3 (%s, wins %s)" % [_state(main), main.round_wins])
	_check(audio.announced.back() == &"final_round", "FINAL ROUND is called")
	t = 0
	while _state(main) != "FIGHTING" and t < 300:
		await physics_frame
		t += 1
	await _finish_round(main, false)
	_check(_state(main) == "RESULT" and main.round_wins == [1, 2], "the rival takes the final round and the match (%s)" % [main.round_wins])
	main.queue_free()
	await process_frame

	print("[training has no rounds]")
	main = _new_main()
	await physics_frame
	main.call("start_training")
	await physics_frame
	_check((main.get_node("HUD") as Hud).get("_rounds_to_win") == 0, "no round pips in training")
	main.queue_free()
	await process_frame

	print("RESULT: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)
