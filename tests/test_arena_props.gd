extends SceneTree
## Every style arena has three breakable props (the seven generated sheets in
## arena_props_v1 plus the temple's dojo set): measured sprite rectangles,
## intact and broken on the same floor baseline, inside the walls, clear of
## both starting spots, and each breaks once from a strong nearby impact.

var _fails := 0


func _check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func _initialize() -> void:
	for id: StringName in [&"boxing", &"muay_thai", &"karate", &"kung_fu", &"taekwondo", &"kickboxing", &"capoeira", &"jeet_kune_do"]:
		var s := StyleStage.new()
		root.add_child(s)
		s.setup(id)
		var ok := s.props.size() == 3
		var notes := PackedStringArray()
		for p: Dictionary in s.props:
			var rect: Rect2 = p["rect"]
			var broken: Rect2 = p["broken_rect"]
			if absf(rect.end.y - broken.end.y) > 0.5:
				ok = false
				notes.append("%s baseline" % p["id"])
			if rect.position.x < Fighter.ARENA_MIN_X - 10.0 or rect.end.x > Fighter.ARENA_MAX_X + 10.0:
				ok = false
				notes.append("%s outside the walls" % p["id"])
			for start in [440.0, 840.0]:
				if rect.position.x < start + 30.0 and rect.end.x > start - 30.0:
					ok = false
					notes.append("%s on a starting spot" % p["id"])
			if (p["intact"] as Rect2).size.x < 20.0 or (p["broken_src"] as Rect2).size.x < 20.0:
				ok = false
				notes.append("%s empty sprite" % p["id"])
		_check(ok, "%s: three grounded props clear of the lane %s" % [id, notes])
		var first: Dictionary = s.props[0]
		var broke := s.impact((first["rect"] as Rect2).get_center().x, 99.0)
		var again := s.impact((first["rect"] as Rect2).get_center().x, 99.0)
		_check(first in broke and not first in again, "%s: %s breaks once" % [id, first["id"]])
		s.free()
	print("RESULT: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)
