class_name GameSettings
extends RefCounted
## Player settings: master / music / effects volume and fullscreen, saved to
## user://settings.cfg. Static, so the values survive the scene reload of a
## rematch; loaded once at start-up. Effects volume covers the announcer too.

const PATH: String = "user://settings.cfg"
## Where settings are read and written (tests point this elsewhere).
static var file: String = PATH
## Volume sliders are linear 0..1; 0 mutes the bus.
static var master_volume: float = 1.0
static var music_volume: float = 1.0
static var sfx_volume: float = 1.0
static var fullscreen: bool = false
static var _loaded: bool = false


## Reads the saved settings once (missing file or keys keep the defaults).
static func load_once() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(file) != OK:
		return
	master_volume = clampf(float(cfg.get_value("audio", "master", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.save(file)


## Sets each bus's volume from its slider (buses that do not exist yet are
## skipped; GameAudio calls this again once it has created them).
static func apply_audio() -> void:
	_set_bus(&"Master", master_volume)
	_set_bus(GameAudio.MUSIC_BUS, music_volume)
	_set_bus(GameAudio.SFX_BUS, sfx_volume)
	_set_bus(GameAudio.VOICE_BUS, sfx_volume)


static func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)


static func _set_bus(bus: StringName, volume: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, volume <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(volume, 0.001)))


## A volume by name ("master_volume", "music_volume", "sfx_volume").
static func get_volume(key: String) -> float:
	match key:
		"master_volume": return master_volume
		"music_volume": return music_volume
		"sfx_volume": return sfx_volume
	return 0.0


static func set_volume(key: String, value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	match key:
		"master_volume": master_volume = value
		"music_volume": music_volume = value
		"sfx_volume": sfx_volume = value
	apply_audio()


## Reads the settings file again (tests).
static func read_again() -> void:
	_loaded = false
	load_once()
