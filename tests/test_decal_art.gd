extends SceneTree
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for folder in StyleStage.DECAL_DIRS.values() + ["res://assets/art/decals/temple_stone_v1"]:
		var decal_data := FxLayer.load_decal_set(folder)
		check(decal_data["floor"].size() == 3 and decal_data["wall"].size() == 3, "%s provides full damage set" % folder)
		for texture: Texture2D in decal_data["floor"] + decal_data["wall"] + [decal_data["scuff"]]:
			check(texture != null, "%s texture imports" % folder)
			if texture == null: continue
			var image := texture.get_image()
			if image.is_compressed(): image.decompress()
			check(image.get_pixel(0, 0).a < 0.01, "%s has genuine transparent margins" % texture.resource_path)
		var fx := FxLayer.new()
		root.add_child(fx)
		fx.decal_set = decal_data
		fx.floor_y = 560
		fx.floor_break(Vector2(640, 560), 3)
		fx.floor_scuff(Vector2(500, 560), 5)
		for decal: Dictionary in fx.get("_decals"):
			var clip: Rect2 = decal["clip"]
			check(clip.has_area() and is_equal_approx(clip.position.y, 560), "floor marks cannot paint the wall above contact")
			check((decal["rect"] as Rect2).size.y < 40, "new floor damage stays shallow")
		var wall := Rect2(24, 96, 46, 470)
		fx.wall_crack(Vector2(55, 430), 3, wall)
		check((fx.get("_decals").back()["clip"] as Rect2) == wall, "wall mark remains clipped to its struck structure")
		fx.free()
	print("RESULT: ", "PASS" if failures == 0 else "FAIL", " material decals: ", failures, " failures")
	quit(0 if failures == 0 else 1)
