extends SceneTree
## Real-scene screenshots and full-world layered art/damage previews.
const OUT := "res://docs/reviews/style-arenas"
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for tick in 4: await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var arenas: Array[StringName] = []
	for style in StyleRegistry.all(): arenas.append(style.id)
	arenas.append_array(StyleStage.SHARED_STREETS)
	for arena: StringName in arenas:
		var style := StyleRegistry.by_id(arena if not arena in StyleStage.SHARED_STREETS else &"karate")
		var main: Node = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		current_scene = main
		await process_frame
		main.select_style(style.id)
		main.match_arena_override = arena
		main.start_match(true)
		main.set_process(false)
		main.set_physics_process(false)
		main.enemy_ai.setup(null, null)
		main.hud.visible = false
		main.player.position = Vector2(430, 560)
		main.enemy.position = Vector2(850, 560)
		main.player.prefight_pose = &""
		main.enemy.prefight_pose = &""
		main.camera.position_smoothing_enabled = false
		main.camera.zoom = Vector2.ONE
		main.camera.position = Vector2(640, 360)
		main.camera.reset_smoothing()
		await settle()
		root.get_texture().get_image().save_png(OUT + "/%s_game.png" % arena)
		# Deliberate damage at floor contact and both wall surfaces.
		main.fx.floor_break(Vector2(640, 574), 3)
		main.fx.floor_scuff(Vector2(450, 578), 6)
		var walls: Array = main.stage.wall_rects(560)
		for wall: Rect2 in walls:
			main.fx.wall_crack(Vector2(wall.get_center().x, 430), 3, wall)
		for decal: Dictionary in main.fx.get("_decals"): decal["age"] = 50
		main.queue_redraw()
		await settle()
		root.get_texture().get_image().save_png(OUT + "/%s_damage.png" % arena)
		if main.stage is StyleStage:
			var viewport := SubViewport.new()
			viewport.size = Vector2i(1680, 1120)
			viewport.world_2d = World2D.new()
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var canvas := Node2D.new()
			canvas.position = Vector2(200, 200)
			viewport.add_child(canvas)
			var art := StyleStage.new()
			canvas.add_child(art)
			art.setup(arena)
			canvas.draw.connect(func(): art.draw_back(canvas, 560))
			canvas.queue_redraw()
			await settle()
			viewport.get_texture().get_image().save_png(OUT + "/%s_full_extents.png" % arena)
			if not art.has_backdrop() or art.cutout_layers().size() != 2:
				failures += 1
				print("FAIL missing layered art ", style.id)
			viewport.free()
		print("Captured ", style.id, " stage=", main.get_stage_name())
		main.free()
		await process_frame
	print("RESULT: ", "PASS" if failures == 0 else "FAIL", " stage render review: ", failures, " missing layer failures")
	quit(0 if failures == 0 else 1)
