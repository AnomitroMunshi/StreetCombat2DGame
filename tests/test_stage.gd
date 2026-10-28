extends SceneTree
## Stage selection and the Kolkata street (WB-01..05): only a PLAYER Bangla
## Maar gets it (a Bangla Maar rival alone does not; training and style select
## are the dojo); stone decals there, wood in the dojo; the walls line up
## with the arena bounds; props break once, from strong nearby impacts only,
## and what stands on a prop falls with it; a reset restores them.

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


func _free(main: Node) -> void:
	main.queue_free()
	await process_frame


func _run() -> void:
	print("[who gets the street]")
	var main := _new_main()
	await physics_frame
	main.call("select_style", &"bangla_maar")
	_check(main.call("get_stage_name") == "dojo", "style select: still the dojo")
	main.call("confirm_style")
	var name: String = main.call("get_stage_name")
	_check(name.begins_with("west_bengal_"), "player Bangla Maar: the Kolkata street (%s)" % name)
	_check(String((main.get("fx") as FxLayer).decal_set["floor"][0].resource_path).contains("west_bengal"),
		"stone damage decals on the street")
	main.call("change_style")
	_check(main.call("get_stage_name") == "dojo", "back to style select: the dojo")
	main.call("select_style", &"karate")
	(main.get_node("Enemy") as Fighter).set_style(StyleRegistry.by_id(&"bangla_maar"))
	main.call("confirm_style")
	_check(main.call("get_stage_name") == "dojo", "a Bangla Maar rival alone does not unlock it")
	_check(String((main.get("fx") as FxLayer).decal_set["floor"][0].resource_path).contains("dojo_wood"),
		"wood damage decals in the dojo")
	await _free(main)

	main = _new_main()
	await physics_frame
	main.call("select_style", &"bangla_maar")
	main.call("start_training")
	await physics_frame
	_check(main.call("get_stage_name") == "dojo", "training as Bangla Maar: the dojo")
	await _free(main)

	print("[walls and props]")
	main = _new_main()
	await physics_frame
	main.call("select_style", &"bangla_maar")
	main.call("start_match", true)
	await physics_frame
	var stage: WestBengalStage = main.get("stage")
	var walls := stage.wall_rects(560.0)
	_check(is_equal_approx(walls[0].end.x, Fighter.ARENA_MIN_X - WestBengalStage.WALL_INSET)
		and is_equal_approx(walls[1].position.x, Fighter.ARENA_MAX_X + WestBengalStage.WALL_INSET),
		"the stall and the shopfront stand at the arena's walls")
	var bench: Dictionary = {}
	var cups: Dictionary = {}
	var crate: Dictionary = {}
	for p in stage.props:
		match p["id"]:
			&"bench":
				bench = p
			&"cups":
				cups = p
			&"crate":
				crate = p
	var bench_x: float = (bench["rect"] as Rect2).get_center().x
	_check((bench["rect"] as Rect2).end.y >= 560.0 and (crate["rect"] as Rect2).end.y >= 560.0,
		"props stand on the street (bench foot %.0f, crate foot %.0f)" % [(bench["rect"] as Rect2).end.y, (crate["rect"] as Rect2).end.y])
	_check(stage.impact(bench_x, 3.0).is_empty(), "a light landing breaks nothing")
	_check(stage.impact(bench_x + 600.0, 20.0).is_empty(), "a far impact breaks nothing")
	var hit := stage.impact(bench_x, 12.0)
	_check(bench["broken"] and cups["broken"] and not crate["broken"] and hit.size() == 2,
		"a strong landing by the bench breaks it, and the cups on it fall too (%d broken)" % hit.size())
	_check(stage.impact(bench_x, 20.0).is_empty(), "a broken prop never breaks again")
	stage.reset_props()
	_check(not bench["broken"] and not cups["broken"], "a reset restores the props")
	await _free(main)

	print("RESULT: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)
