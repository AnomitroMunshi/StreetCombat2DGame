extends SceneTree
## Music follows the player's style: menu theme while choosing, the chosen
## style's own track (or the procedural loop) for the match, crossfaded, never
## restarted when it is already playing, unaffected by the rival's style.

var _fails: int = 0


func _check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _initialize() -> void:
	_run()


func _run() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await _wait(5)
	var audio: GameAudio = main.get_node("Audio")
	var hud: Hud = main.get_node("HUD")
	var menu_stream: AudioStream = load(GameAudio.MUSIC_FILES[&"menu"][0])
	var bangla_stream: AudioStream = load(GameAudio.MUSIC_FILES[&"bangla_maar"][0])

	print("[style select]")
	_check(audio.get_music_id() == &"menu" and audio.get_music_stream() == menu_stream and audio.is_bgm_playing(),
		"style select plays the menu theme")
	hud.style_chosen.emit(&"bangla_maar")
	await _wait(3)
	_check(audio.get_music_id() == &"menu", "previewing a style keeps the menu theme")

	print("[match]")
	main.call("confirm_style")
	await _wait(3)
	_check(audio.get_music_id() == &"bangla_maar" and audio.get_music_stream() == bangla_stream,
		"confirming Bangla Maar plays its own track")
	var rival: Fighter = main.get_node("Enemy")
	rival.set_style(StyleRegistry.by_id(&"boxing"))
	await _wait(3)
	_check(audio.get_music_stream() == bangla_stream, "the rival's style never changes the music")
	await create_timer(GameAudio.MUSIC_FADE_TIME + 0.5).timeout  # the fade runs in real time
	var playing := 0
	for c in audio.get_children():
		if c is AudioStreamPlayer and (c as AudioStreamPlayer).bus == GameAudio.MUSIC_BUS and (c as AudioStreamPlayer).playing:
			playing += 1
	_check(playing == 1, "after the crossfade only one track plays (%d)" % playing)
	_check(AudioServer.get_bus_index(GameAudio.MUSIC_BUS) >= 0, "music has its own bus")

	print("[distinct tracks for all nine styles]")
	var track_paths: Array = []
	for st in StyleRegistry.all():
		_check(GameAudio.MUSIC_FILES.has(st.id) and ResourceLoader.exists(GameAudio.MUSIC_FILES[st.id][0]), "%s has its own track" % st.id)
		var path: String = GameAudio.MUSIC_FILES[st.id][0]
		_check(not track_paths.has(path), "%s music does not alias another style" % st.id)
		track_paths.append(path)
		if st.id in [&"capoeira", &"jeet_kune_do"]:
			main.change_style()
			main.select_style(st.id)
			main.confirm_style()
			await _wait(3)
			var stream := audio.get_music_stream()
			_check(audio.get_music_id() == st.id and stream == load(path) and stream is AudioStreamOggVorbis and stream.loop, "%s selects its dedicated looping OGG" % st.id)
			_check(stream.get_length() > 60, "%s has a full musical arrangement" % st.id)

	print("[styles without a track fall back]")
	main.call("change_style")
	await _wait(3)
	_check(audio.get_music_id() == &"menu", "CHANGE STYLE goes back to the menu theme")
	hud.style_chosen.emit(&"karate")
	main.call("confirm_style")
	await _wait(3)
	_check(audio.get_music_id() == &"karate" and audio.get_music_stream() is AudioStreamOggVorbis
		and (audio.get_music_stream() as AudioStreamOggVorbis).loop, "Karate plays its own looping track")
	var t0 := Time.get_ticks_msec()
	while audio.get_bgm_length() <= 0.0 and Time.get_ticks_msec() - t0 < 20000:
		await process_frame
	audio.set_music(&"some_new_style")
	await _wait(2)
	_check(audio.get_music_stream() is AudioStreamWAV, "a style with no track yet plays the procedural loop")

	print("[same track: no restart]")
	var before := audio.get_music_stream()
	audio.set_music(audio.get_music_id())
	audio.set_music(audio.get_music_id())
	_check(audio.get_music_stream() == before, "asking for the playing track again changes nothing")

	main.queue_free()
	await _wait(2)
	print("RESULT: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)
