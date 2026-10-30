class_name TouchControls
extends CanvasLayer
## On-screen controls for touch screens: a direction pad on the left and the
## attack / jump / block buttons on the right. Each is a TouchScreenButton
## bound to the same input action as the keyboard key, so the combat code
## reads touch exactly like keys, and multi-touch chords work (hold UP and tap
## LIGHT for W+J; hold DOWN and BLOCK for a low block). Double-tapping a
## direction dodges, as on the keyboard.
##
## Shown during fights and training when the device has a touch screen, or
## always when the TOUCH CONTROLS setting is on (for testing with a mouse).

const PAD_RADIUS: float = 52.0
const BUTTON_RADIUS: float = 46.0
const FILL := Color(0.08, 0.06, 0.06, 0.55)
const RIM := Color(0.95, 0.76, 0.3, 0.75)
const TEXT := Color(0.96, 0.92, 0.84, 0.95)

## [action, label, centre] in the 1280 x 720 canvas.
const LAYOUT: Array = [
	[&"move_left", "◀", Vector2(110.0, 565.0)], [&"move_right", "▶", Vector2(290.0, 565.0)],
	[&"mod_up", "▲", Vector2(200.0, 475.0)], [&"mod_down", "▼", Vector2(200.0, 655.0)],
	[&"attack_light", "LIGHT", Vector2(1000.0, 620.0)], [&"attack_heavy", "HEAVY", Vector2(1110.0, 560.0)],
	[&"attack_technique", "TECH", Vector2(1210.0, 480.0)], [&"jump", "JUMP", Vector2(1100.0, 670.0)],
	[&"block", "BLOCK", Vector2(890.0, 670.0)], [&"x_move", "X", Vector2(1210.0, 640.0)],
	[&"signature", "SIG", Vector2(1210.0, 380.0)],
]

## The TOUCH CONTROLS setting: show them even without a touch screen.
static var forced: bool = false
## The buttons are on screen now (the HUD drops its keyboard hint line).
static var shown: bool = false
var buttons: Dictionary = {}


func _ready() -> void:
	layer = 5
	for entry in LAYOUT:
		var action: StringName = entry[0]
		var pad := action in [&"move_left", &"move_right", &"mod_up", &"mod_down"]
		var r := PAD_RADIUS if pad else BUTTON_RADIUS
		var b := TouchScreenButton.new()
		b.action = action
		b.texture_normal = _disc(r, false)
		b.texture_pressed = _disc(r, true)
		var shape := CircleShape2D.new()
		shape.radius = r
		b.shape = shape
		b.shape_centered = true
		# Sliding a thumb onto a button presses it (rolling across the pad).
		b.passby_press = pad
		b.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
		b.position = entry[2] - Vector2(r, r)
		var label := Label.new()
		label.text = entry[1]
		label.add_theme_color_override("font_color", TEXT)
		label.add_theme_font_size_override("font_size", 22 if pad else 15)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = Vector2(r * 2.0, r * 2.0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(label)
		b.visible = false
		add_child(b)
		buttons[action] = b


## Shown in a fight (or training) on touch devices, or when forced. Each
## button is shown or hidden itself (a TouchScreenButton turns its touch
## input on and off with its own visibility).
func update_visibility(in_fight: bool) -> void:
	var on := in_fight and (forced or DisplayServer.is_touchscreen_available())
	shown = on
	for b: TouchScreenButton in buttons.values():
		if b.visible != on:
			b.visible = on


func is_shown() -> bool:
	return not buttons.is_empty() and buttons.values()[0].visible


## A soft disc with a rim (brighter while pressed).
static func _disc(r: float, pressed: bool) -> ImageTexture:
	var size := int(ceil(r * 2.0))
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(r, r)
	var fill := FILL.lerp(Color(0.6, 0.18, 0.14, 0.75), 1.0 if pressed else 0.0)
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d > r:
				continue
			var col := RIM if d > r - 3.0 else fill
			col.a *= clampf(r - d, 0.0, 1.0)  # anti-aliased edge
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
