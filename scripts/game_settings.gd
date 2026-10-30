class_name GameSettings
extends RefCounted
## Player settings: master / music / effects volume, fullscreen and key
## bindings, saved to user://settings.cfg. Static, so the values survive the
## scene reload of a rematch; loaded once at start-up. Effects volume covers
## the announcer too.

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
	if cfg.has_section("controls"):
		for action: String in cfg.get_section_keys("controls"):
			controls[StringName(action)] = int(cfg.get_value("controls", action))


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("display", "fullscreen", fullscreen)
	for action: StringName in controls:
		cfg.set_value("controls", String(action), controls[action])
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


# --- Controls -------------------------------------------------------------------

## Actions the player can rebind (one key each), in the order the panel lists
## them, with their panel names.
const REMAPPABLE: Array = [
	[&"move_left", "MOVE LEFT"], [&"move_right", "MOVE RIGHT"], [&"mod_up", "UP (with attack)"],
	[&"mod_down", "DOWN / CROUCH"], [&"jump", "JUMP"], [&"block", "BLOCK / PARRY"],
	[&"attack_light", "LIGHT ATTACK"], [&"attack_heavy", "HEAVY ATTACK"], [&"attack_technique", "TECHNIQUE"],
	[&"x_move", "X MOVE"], [&"signature", "SIGNATURE"],
]
## Keys kept for the menus and screens (never bound to a combat action).
const RESERVED_KEYS: Array[int] = [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_P, KEY_O, KEY_G, KEY_T, KEY_R, KEY_U, KEY_N,
	KEY_Q, KEY_F1, KEY_F2, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_H, KEY_PERIOD]
## Action -> physical keycode the player chose (only actions they changed).
static var controls: Dictionary = {}
## The project's own bindings, read once before any change (for reset).
static var _default_keys: Dictionary = {}


static func _remembers_defaults() -> void:
	if not _default_keys.is_empty():
		return
	for entry in REMAPPABLE:
		_default_keys[entry[0]] = _bound_key(entry[0])


## The physical key bound to an action (0 if none).
static func _bound_key(action: StringName) -> int:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			return int(key.physical_keycode) if key.physical_keycode != KEY_NONE else int(key.keycode)
	return 0


static func key_for(action: StringName) -> int:
	_remembers_defaults()
	return int(controls.get(action, _default_keys.get(action, _bound_key(action))))


## A short printable name for the key bound to an action ("J", "Space", "Shift").
static func key_label(action: StringName) -> String:
	var code := key_for(action)
	return OS.get_keycode_string(code) if code != 0 else "?"


## Binds `action` to `code`. An action already on that key takes the old key
## of `action` (a swap), so no key ever drives two actions. Reserved keys are
## refused (returns false).
static func bind(action: StringName, code: int) -> bool:
	if code in RESERVED_KEYS or code == KEY_NONE:
		return false
	var old := key_for(action)
	for entry in REMAPPABLE:
		if entry[0] != action and key_for(entry[0]) == code:
			controls[entry[0]] = old
	controls[action] = code
	apply_controls()
	return true


static func reset_controls() -> void:
	controls.clear()
	apply_controls()


## Writes every remappable action's key into the InputMap.
static func apply_controls() -> void:
	_remembers_defaults()
	for entry in REMAPPABLE:
		var action: StringName = entry[0]
		var code := key_for(action)
		InputMap.action_erase_events(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		InputMap.action_add_event(action, ev)
