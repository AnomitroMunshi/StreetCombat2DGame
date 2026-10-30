class_name TouchControls
extends CanvasLayer
## On-screen controls for touch screens (landscape): an 8-direction "clock"
## joystick bottom-left, J / K / L bottom-right with a wide BLOCK pill under
## them, a smaller X above (with its cooldown) and F, shown only at full Focus.
## Everything presses the same input actions as the keyboard (or, for rolls,
## the same dodge request), so all nine styles keep their own move mappings.
## Multi-touch: every finger is tracked separately.
##
## Joystick (clock directions, screen-relative):
##   12 flick: jump  ·  12 hold + J/K: W+J / W+K  ·  beyond 12 + J/K: Space+J / Space+K
##   2 / 10: jump right / left  ·  3 / 9: walk (a double flick dashes)
##   6 hold: crouch (6 + J/K: S+J / S+K)  ·  6 -> 4 / 6 -> 8 flick: roll right / left
## "Beyond 12" is extra upward travel past the joystick ring.
##
## Shown during fights and training when the device has a touch screen, or
## always when the TOUCH CONTROLS setting is on (for testing with a mouse).

enum Zone { NONE, N, NE, E, SE, S, SW, W, NW, BEYOND_N }

const STICK_CENTRE := Vector2(150.0, 585.0)
const STICK_RADIUS: float = 82.0
## The stick takes touches this far from its centre (thumbs land loosely).
const STICK_GRAB: float = 150.0
## Inside this fraction of the radius the stick is neutral.
const DEAD_ZONE: float = 0.35
## Upward travel past this fraction of the radius is "beyond 12".
const BEYOND: float = 1.3
## A 12 that returns to neutral within this many ticks is a flick (a jump).
const FLICK_TICKS: int = 12
## 6 -> 4 / 6 -> 8 rolls only after 6 was held this long (deliberate, never
## an accidental brush of the diagonal while walking).
const ROLL_HOLD: int = 3

## Buttons: [id, label, centre, radius, action]. BLOCK is a pill (radius = half height).
const BUTTONS: Array = [
	[&"j", "J", Vector2(1030.0, 575.0), 42.0, &"attack_light"],
	[&"k", "K", Vector2(1128.0, 560.0), 46.0, &"attack_heavy"],
	[&"l", "L", Vector2(1222.0, 548.0), 40.0, &"attack_technique"],
	[&"x", "X", Vector2(1080.0, 468.0), 30.0, &"x_move"],
	[&"f", "F", Vector2(1196.0, 452.0), 36.0, &"signature"],
	[&"block", "BLOCK", Vector2(1128.0, 664.0), 26.0, &"block"],
]
const BLOCK_HALF_WIDTH: float = 112.0

const REST_ALPHA: float = 0.4
const PRESSED_ALPHA: float = 0.85
const FILL := Color(0.08, 0.06, 0.06)
const RIM := Color(0.95, 0.76, 0.3)
const TEXT := Color(0.96, 0.92, 0.84)
const GLOW := Color(1.0, 0.72, 0.25)

## The TOUCH CONTROLS setting: show them even without a touch screen.
static var forced: bool = false
## The controls are on screen now (the HUD drops its keyboard hint line).
static var shown: bool = false
## A roll asked for by a 6 -> 4 / 6 -> 8 flick (world direction), read once
## by main.gd's player intent; 0 = none.
static var dodge_request: int = 0

var player: Fighter = null
## The stick's clock zone and knob offset (drawn).
var zone: Zone = Zone.NONE
var knob := Vector2.ZERO
## Fingers: touch index -> &"stick" or a button id.
var _fingers: Dictionary = {}
var _pressed: Dictionary = {}
var _held_actions: Dictionary = {}
## The zone as of the last tick, how long it has been held, and whether J / K
## went in while in it (a 12 with an attack is a hold, not a flick).
var _last_zone: Zone = Zone.NONE
## The zone the stick came from into the current one.
var _entered_from: Zone = Zone.NONE
var _zone_ticks: int = 0
var _attacked_in_zone: bool = false
## A one-tick press (flick jump, the power chord's Space) to release next tick.
var _jump_release: bool = false
var _canvas: Control


func _ready() -> void:
	layer = 5
	# Before main.gd reads the player's input this tick.
	process_physics_priority = -10
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.size = Vector2(1280.0, 720.0)
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)
	_canvas.visible = false


func setup(p: Fighter) -> void:
	player = p


## Shown in a fight (or training) on touch devices, or when forced.
func update_visibility(in_fight: bool) -> void:
	var on := in_fight and (forced or DisplayServer.is_touchscreen_available())
	shown = on
	if _canvas.visible != on:
		_canvas.visible = on
		if not on:
			_release_all()
	if on:
		_canvas.queue_redraw()


func is_shown() -> bool:
	return _canvas.visible


func is_pressed(id: StringName) -> bool:
	return _pressed.get(id, false)


func f_visible() -> bool:
	return player != null and player.focus >= CombatData.FOCUS_MAX


# --- Touch input ----------------------------------------------------------------

## Canvas position of a touch. The viewport has already mapped the event from
## window to 1280 x 720 canvas coordinates by the time _input sees it.
func _canvas_pos(screen: Vector2) -> Vector2:
	return screen


func _input(event: InputEvent) -> void:
	if not _canvas.visible:
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		var pos := _canvas_pos(touch.position)
		if touch.pressed:
			var id := _hit(pos)
			if id != &"":
				_fingers[touch.index] = id
				if id == &"stick":
					_move_stick(pos)
				else:
					_press_button(id)
				get_viewport().set_input_as_handled()
		elif _fingers.has(touch.index):
			var id: StringName = _fingers[touch.index]
			_fingers.erase(touch.index)
			if id == &"stick":
				_move_stick(STICK_CENTRE)
			else:
				_release_button(id)
			get_viewport().set_input_as_handled()
		return
	var drag := event as InputEventScreenDrag
	if drag != null and _fingers.get(drag.index, &"") == &"stick":
		_move_stick(_canvas_pos(drag.position))
		get_viewport().set_input_as_handled()


## Which control a touch at `pos` lands on (&"" for none).
func _hit(pos: Vector2) -> StringName:
	if pos.distance_to(STICK_CENTRE) <= STICK_GRAB:
		return &"stick"
	for b in BUTTONS:
		if b[0] == &"f" and not f_visible():
			continue
		var c: Vector2 = b[2]
		if b[0] == &"block":
			if absf(pos.x - c.x) <= BLOCK_HALF_WIDTH + 8.0 and absf(pos.y - c.y) <= float(b[3]) + 10.0:
				return b[0]
		elif pos.distance_to(c) <= float(b[3]) * 1.2:
			return b[0]
	return &""


func _press_button(id: StringName) -> void:
	_pressed[id] = true
	if id in [&"j", &"k"]:
		_attacked_in_zone = true
		if zone == Zone.BEYOND_N:
			# Beyond 12 + J / K: the Space + J / K power chord (pressed together).
			_tap_jump()
	Input.action_press(_action_of(id))
	_canvas.queue_redraw()


func _release_button(id: StringName) -> void:
	_pressed[id] = false
	Input.action_release(_action_of(id))
	_canvas.queue_redraw()


static func _action_of(id: StringName) -> StringName:
	for b in BUTTONS:
		if b[0] == id:
			return b[4]
	return &""


func _move_stick(pos: Vector2) -> void:
	var offset := pos - STICK_CENTRE
	knob = offset.limit_length(STICK_RADIUS)
	zone = zone_for(offset)
	_canvas.queue_redraw()


## The clock zone of a stick offset from its centre.
static func zone_for(offset: Vector2) -> Zone:
	if offset.length() < STICK_RADIUS * DEAD_ZONE:
		return Zone.NONE
	# 0 = up (12), clockwise in 45-degree sectors.
	var sector := int(round(fposmod(atan2(offset.x, -offset.y), TAU) / (TAU / 8.0))) % 8
	if sector == 0 and -offset.y > STICK_RADIUS * BEYOND:
		return Zone.BEYOND_N
	return [Zone.N, Zone.NE, Zone.E, Zone.SE, Zone.S, Zone.SW, Zone.W, Zone.NW][sector]


# --- Stick -> actions, once per tick (before the player's input is read) --------

func _physics_process(_delta: float) -> void:
	if _jump_release:
		_jump_release = false
		Input.action_release(&"jump")
	if not _canvas.visible:
		return
	if zone != _last_zone:
		_on_zone_change(_last_zone, zone)
	else:
		_zone_ticks += 1
	_hold(&"move_right", zone in [Zone.E, Zone.NE])
	_hold(&"move_left", zone in [Zone.W, Zone.NW])
	_hold(&"mod_up", zone == Zone.N)
	_hold(&"mod_down", zone in [Zone.S, Zone.SE, Zone.SW])
	_canvas.queue_redraw()


func _on_zone_change(old: Zone, new: Zone) -> void:
	# 12 flick: into 12 and straight back out with no attack thrown: jump.
	var flick := _zone_ticks <= FLICK_TICKS and _entered_from == Zone.NONE and not _attacked_in_zone
	if old == Zone.N and new == Zone.NONE and flick:
		_tap_jump()
	# 2 / 10: jump right / left, on entry.
	if new in [Zone.NE, Zone.NW] and not old in [Zone.NE, Zone.NW]:
		_tap_jump()
	# 6 -> 4 / 6 -> 8 flick: roll right / left (crouch stays held).
	if old == Zone.S and _zone_ticks >= ROLL_HOLD and new in [Zone.SE, Zone.SW]:
		dodge_request = 1 if new == Zone.SE else -1
	_entered_from = old
	_last_zone = new
	_zone_ticks = 0
	_attacked_in_zone = false


func _tap_jump() -> void:
	Input.action_press(&"jump")
	_jump_release = true


func _hold(action: StringName, on: bool) -> void:
	if _held_actions.get(action, false) == on:
		return
	_held_actions[action] = on
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _release_all() -> void:
	for action: StringName in _held_actions:
		if _held_actions[action]:
			Input.action_release(action)
	_held_actions.clear()
	for id: StringName in _pressed:
		if _pressed[id]:
			Input.action_release(_action_of(id))
	_pressed.clear()
	_fingers.clear()
	zone = Zone.NONE
	_last_zone = Zone.NONE
	knob = Vector2.ZERO
	dodge_request = 0


# --- Drawing ----------------------------------------------------------------------

func _draw_controls() -> void:
	var font := ThemeDB.fallback_font
	# Joystick: ring, the eight clock ticks, the "beyond 12" notch, the knob.
	var a := PRESSED_ALPHA if _fingers.values().has(&"stick") else REST_ALPHA
	_canvas.draw_circle(STICK_CENTRE, STICK_RADIUS, Color(FILL, a * 0.8))
	_canvas.draw_arc(STICK_CENTRE, STICK_RADIUS, 0.0, TAU, 48, Color(RIM, a), 2.5, true)
	for i in 8:
		var ang := TAU * i / 8.0
		var dir := Vector2(sin(ang), -cos(ang))
		var lit := zone != Zone.NONE and zone != Zone.BEYOND_N and int(zone) - 1 == i
		_canvas.draw_line(STICK_CENTRE + dir * (STICK_RADIUS - 12.0), STICK_CENTRE + dir * (STICK_RADIUS - 3.0),
			Color(GLOW, 0.95) if lit else Color(TEXT, a), 3.0 if lit else 2.0, true)
	var beyond := STICK_CENTRE + Vector2(0.0, -STICK_RADIUS * BEYOND)
	_canvas.draw_arc(beyond, 9.0, PI, TAU, 12, Color(GLOW, 0.95) if zone == Zone.BEYOND_N else Color(RIM, a), 2.0, true)
	_canvas.draw_circle(STICK_CENTRE + knob, 30.0, Color(TEXT, 0.35 + a * 0.4))
	# Buttons.
	for b in BUTTONS:
		var id: StringName = b[0]
		if id == &"f" and not f_visible():
			continue
		var c: Vector2 = b[2]
		var r: float = b[3]
		var pa := PRESSED_ALPHA if is_pressed(id) else REST_ALPHA
		if id == &"block":
			var rect := Rect2(c - Vector2(BLOCK_HALF_WIDTH, r), Vector2(BLOCK_HALF_WIDTH * 2.0, r * 2.0))
			_pill(rect, Color(FILL, pa * 0.9), Color(RIM, pa))
		else:
			if id == &"f":
				# Full Focus: a soft pulsing glow.
				var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)
				_canvas.draw_circle(c, r + 8.0 + pulse * 4.0, Color(GLOW, 0.18 + pulse * 0.12))
			_canvas.draw_circle(c, r, Color(FILL, pa * 0.9))
			_canvas.draw_arc(c, r, 0.0, TAU, 40, Color(GLOW if id == &"f" else RIM, pa + 0.1), 2.5, true)
			if id == &"x" and player != null and player.x_cooldown > 0:
				# Cooldown: a dark sweep that shrinks as X recharges.
				var left := clampf(float(player.x_cooldown) / _x_cooldown_total(), 0.0, 1.0)
				var pts := PackedVector2Array([c])
				for i in 25:
					var ang := -PI * 0.5 + TAU * left * i / 24.0
					pts.append(c + Vector2(cos(ang), sin(ang)) * (r - 2.0))
				_canvas.draw_colored_polygon(pts, Color(0.0, 0.0, 0.0, 0.55))
		var size := 15 if id == &"block" else (20 if r >= 40.0 else 16)
		var label: String = b[1]
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		_canvas.draw_string(font, c + Vector2(-w * 0.5, size * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
			Color(TEXT, minf(pa + 0.35, 1.0)))


func _x_cooldown_total() -> float:
	if player == null or player.style == null:
		return 900.0
	var t := player.style.resolve(&"x_move", false)
	return maxf(float(CombatData.get_attack(t).x_cooldown_frames), 1.0) if t != CombatData.AttackType.NONE else 900.0


func _pill(rect: Rect2, fill: Color, rim: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = rim
	box.set_border_width_all(2)
	box.set_corner_radius_all(int(rect.size.y * 0.5))
	box.anti_aliasing = true
	_canvas.draw_style_box(box, rect)
