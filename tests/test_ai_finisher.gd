extends SceneTree
## Passive player vs AI until KO: the AI should perform a finisher on the player,
## and the result must only appear after the knocked-out body has come to rest.

class Driver extends Node:
	var tree: SceneTree
	var frame: int = 0
	var ko_frame: int = -1
	var fails: int = 0
	var changed: bool = false
	var change_frame: int = -1

	func check(cond: bool, msg: String) -> void:
		print(("  ok   " if cond else "  FAIL ") + msg)
		if not cond:
			fails += 1

	func _physics_process(_d: float) -> void:
		frame += 1
		var main := tree.current_scene
		if frame == 1:
			main.call("start_match", true)
		var p: Fighter = main.get_node("Player")
		var state: String = main.call("get_round_state_name")
		if ko_frame < 0 and state == "KO":
			ko_frame = frame
			print("  player KO'd at frame %d by finisher: %s" % [frame, main.get("last_finisher_name")])
			check(main.get("last_finisher_name") != "", "a finisher played before the KO")
		if state == "RESULT" and not changed:
			check(ko_frame > 0 and frame - ko_frame >= 50, "K.O. shown before the result (%d ticks)" % (frame - ko_frame))
			check(not p.airborne and not p.rolling and not p.settling, "loser at rest when the result appears")
			check((main.get_node("HUD") as Hud).is_button_visible() and (main.get_node("HUD") as Hud).is_change_style_visible(),
				"REMATCH and CHANGE STYLE offered")
			if not changed:
				changed = true
				(main.get_node("HUD") as Hud).press_change_style()
				change_frame = frame
		if changed and frame == change_frame + 5:
			check(main.call("get_round_state_name") == "STYLE_SELECT", "CHANGE STYLE after a match returns to style selection")
			print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
			tree.quit(fails)
		elif frame > 5000:
			check(false, "no result within 5000 ticks")
			tree.quit(1)


func _initialize() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var d := Driver.new()
	d.tree = self
	root.add_child(d)
