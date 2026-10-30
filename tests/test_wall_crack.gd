extends SceneTree
## Wall cracks land on the struck wall: arenas whose side cutouts are the wall
## (the temple's stone pillars, layout "crack_on_cutout") crack the solid part
## of the cutout, never the foliage beside it; other arenas keep the struck x.

var _fails := 0


func _check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func _initialize() -> void:
	var temple := StyleStage.new()
	root.add_child(temple)
	temple.setup(&"karate")
	var image: Image = temple.call("_cutout_alpha_image")
	for side in [-1, 1]:
		var layer: Dictionary = temple.cutout_layers()[0 if side < 0 else 1]
		var rect: Rect2 = layer["rect"]
		var src: Rect2 = layer["source"]
		for y in [360.0, 430.0, 500.0]:
			var fallback := 80.0 if side < 0 else 1200.0
			var x := temple.wall_crack_x(side, y, fallback)
			var sx := int(src.position.x + (x - rect.position.x) / rect.size.x * src.size.x)
			var sy := int(src.position.y + (y - rect.position.y) / rect.size.y * (src.size.y - 1.0))
			_check(x != fallback and image.get_pixel(sx, sy).a > 0.6,
				"temple %s pillar at y %d: crack x %.0f is on solid stone" % ["left" if side < 0 else "right", y, x])
	var gym := StyleStage.new()
	root.add_child(gym)
	gym.setup(&"boxing")
	_check(gym.wall_crack_x(-1, 430.0, 80.0) == 80.0, "the boxing gym keeps the struck x (its wall is the painted wall)")
	temple.free()
	gym.free()
	print("RESULT: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)
