extends SceneTree
## Settings: the SETTINGS button is offered before the match and while paused
## (never mid-fight), the sliders set the Master / Music / SFX (+ Voice) bus
## volumes, closing the panel saves them, and they load back. Uses a scratch
## settings file, never the player's own.

const TEST_FILE := "user://test_settings_tmp.cfg"


class Driver extends Node:
	var tree: SceneTree
	var fails: int = 0
	var phase_frame: int = 0

	func check(cond: bool, msg: String) -> void:
		print(("  ok   " if cond else "  FAIL ") + msg)
		if not cond:
			fails += 1

	func bus_db(bus: StringName) -> float:
		return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))

	func bus_muted(bus: StringName) -> bool:
		return AudioServer.is_bus_mute(AudioServer.get_bus_index(bus))

	func _physics_process(_d: float) -> void:
		phase_frame += 1
		var main := tree.current_scene
		if main == null:
			return
		var hud: Hud = main.get_node("HUD")
		match phase_frame:
			2:
				hud.style_chosen.emit(&"boxing")
				main.call("confirm_style")
			4:
				print("[pre-match]")
				check(hud.is_settings_button_visible(), "SETTINGS is offered on the pre-match screen")
				var key := InputEventKey.new()
				key.physical_keycode = KEY_O
				key.pressed = true
				tree.root.push_input(key)
			6:
				check(hud.is_settings_open(), "O opens the panel")
				hud.settings_slider("music_volume").value = 40.0
				hud.settings_slider("sfx_volume").value = 0.0
				check(is_equal_approx(GameSettings.music_volume, 0.4) and absf(bus_db(GameAudio.MUSIC_BUS) - linear_to_db(0.4)) < 0.01,
					"the music slider sets the Music bus (%.1f dB)" % bus_db(GameAudio.MUSIC_BUS))
				check(bus_muted(GameAudio.SFX_BUS) and bus_muted(GameAudio.VOICE_BUS), "effects at 0 mutes effects and the announcer")
				check(not bus_muted(&"Master") and not bus_muted(GameAudio.MUSIC_BUS), "other buses stay on")
				var sfx_player: AudioStreamPlayer = main.get_node("Audio").get("_voices")[0]
				check(sfx_player.bus == GameAudio.SFX_BUS, "sound effects play on the SFX bus")
				hud.toggle_settings()
				check(not hud.is_settings_open() and FileAccess.file_exists(TEST_FILE), "closing the panel saves")
			8:
				print("[persist]")
				GameSettings.music_volume = 1.0
				GameSettings.sfx_volume = 1.0
				GameSettings.read_again()
				check(is_equal_approx(GameSettings.music_volume, 0.4) and is_equal_approx(GameSettings.sfx_volume, 0.0),
					"saved values load back (music %.2f, effects %.2f)" % [GameSettings.music_volume, GameSettings.sfx_volume])
				main.call("start_match", true)
			10:
				print("[match]")
				check(not hud.is_settings_button_visible(), "no SETTINGS button mid-fight")
				main.call("toggle_pause")
			12:
				check(hud.is_settings_button_visible(), "SETTINGS is offered while paused")
				main.call("toggle_pause")
			14:
				check(not hud.is_settings_button_visible(), "resuming hides it again")
				GameSettings.set_volume("music_volume", 1.0)
				GameSettings.set_volume("sfx_volume", 1.0)
				DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_FILE))
				print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
				tree.quit(1 if fails > 0 else 0)


func _initialize() -> void:
	GameSettings.file = TEST_FILE
	if FileAccess.file_exists(TEST_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_FILE))
	var d := Driver.new()
	d.tree = self
	d.process_mode = Node.PROCESS_MODE_ALWAYS  # keeps checking while paused
	root.add_child(d)
	change_scene_to_file("res://scenes/main.tscn")
