class_name Hud
extends CanvasLayer
## Screen-space HUD: health bars, combo counters, round messages, control hints,
## the match buttons (Start / Restart) and the developer text panel. Reads
## Fighter state; never modifies it. Buttons only emit signals for main.gd.

## The centred match button was pressed (mouse, touch, or Enter while focused).
signal start_pressed
signal restart_pressed

const SCREEN_W: float = 1280.0
const BAR_WIDTH: float = 480.0
const BAR_HEIGHT: float = 20.0
const BAR_MARGIN: float = 48.0
const BAR_Y: float = 44.0
const TRAIL_DRAIN_PER_SEC: float = 0.5
const LETTERBOX_HEIGHT: float = 62.0
const FLASH_DECAY_PER_SEC: float = 3.5

const COLOR_BAR_BG := Color(0.06, 0.05, 0.05, 0.85)
const COLOR_BAR_FILL := Color(0.95, 0.76, 0.3)
const COLOR_BAR_LOW := Color(0.9, 0.28, 0.22)
const COLOR_TRAIL := Color(1.0, 0.95, 0.88, 0.85)
const COLOR_TEXT := Color(0.96, 0.93, 0.87)
const COLOR_DIM := Color(0.96, 0.93, 0.87, 0.55)
## Posture bar: thin, under the health bar, filling from its centre outward.
const POSTURE_Y: float = BAR_Y + BAR_HEIGHT + 5.0
const POSTURE_H: float = 6.0
const COLOR_POSTURE := Color(0.98, 0.62, 0.2)
const COLOR_POSTURE_HIGH := Color(1.0, 0.25, 0.15)
const COLOR_POSTURE_LOCK := Color(0.6, 0.6, 0.65, 0.6)
const POPUP_LIFE: float = 0.9

var _player: Fighter = null
var _enemy: Fighter = null
var _trail: Array[float] = [1.0, 1.0]
## Displayed posture (eases toward the real value so gains and decay read).
var _posture_shown: Array[float] = [0.0, 0.0]
## Short callouts under a fighter's bar: {text, side (0 player, 1 enemy), age, color}.
var _popups: Array[Dictionary] = []
var _headline: String = ""
var _subline: String = ""
var _banner: String = ""
var _banner_color: Color = Color.WHITE
var _flash: float = 0.0
var _letterbox: float = 0.0
var _letterbox_target: float = 0.0
var _debug_visible: bool = true
var _debug_lines: PackedStringArray = PackedStringArray()
var _canvas: Control = null
var _font: Font = null
## Big centred countdown text ("3", "2", "1", "FIGHT!") and its age in seconds,
## for the pop-in scale animation.
var _count_text: String = ""
var _count_age: float = 0.0
var _show_hints: bool = true
var _button: Button = null
## Which signal the button emits right now (&"start" / &"restart").
var _button_mode: StringName = &""


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.size = Vector2(SCREEN_W, 720.0)
	add_child(_canvas)
	_canvas.draw.connect(_on_canvas_draw)
	_button = _make_button()
	add_child(_button)


## A large flat button, centred; works with mouse, touch and keyboard focus.
func _make_button() -> Button:
	var b := Button.new()
	b.size = Vector2(320.0, 72.0)
	# Below the fighters (bodies lie around y 470 under the K.O. camera).
	b.position = Vector2((SCREEN_W - b.size.x) * 0.5, 560.0)
	b.add_theme_font_size_override("font_size", 30)
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = {"normal": Color(0.08, 0.06, 0.06, 0.88), "hover": Color(0.42, 0.13, 0.11, 0.95),
			"pressed": Color(0.6, 0.18, 0.14, 1.0), "focus": Color(0.08, 0.06, 0.06, 0.88)}[state]
		box.border_color = Color(0.95, 0.76, 0.3)
		box.set_border_width_all(3)
		box.set_corner_radius_all(6)
		b.add_theme_stylebox_override(state, box)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.visible = false
	# No keyboard focus: a focused Button also reacts to Space, which is jump.
	# Enter is handled in _unhandled_input instead.
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_on_button_pressed)
	return b


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER):
		press_button()


## Shows the centred button as START MATCH or RESTART MATCH (mode &"" hides it).
func show_button(mode: StringName) -> void:
	_button_mode = mode
	_button.visible = mode != &""
	_button.disabled = mode == &""
	if mode == &"start":
		_button.text = "START MATCH"
	elif mode == &"restart":
		_button.text = "RESTART MATCH"


func is_button_visible() -> bool:
	return _button.visible


## Presses the button as a click would (used by tests and future touch input).
func press_button() -> void:
	if _button.visible and not _button.disabled:
		_on_button_pressed()


func _on_button_pressed() -> void:
	var mode := _button_mode
	if mode == &"":
		return
	# One press per showing: further clicks before main.gd reacts do nothing.
	show_button(&"")
	if mode == &"start":
		start_pressed.emit()
	else:
		restart_pressed.emit()


## Callout under a fighter's health bar ("GUARD BREAK", "COUNTER", "PARRY").
func popup(fighter: Fighter, text: String, color: Color) -> void:
	_popups.append({"text": text, "side": 0 if fighter == _player else 1, "age": 0.0, "color": color})


## Big centred countdown entry; a new text restarts the pop animation.
func set_countdown(text: String) -> void:
	if text != _count_text:
		_count_age = 0.0
	_count_text = text


func get_countdown() -> String:
	return _count_text


func set_hints_visible(on: bool) -> void:
	_show_hints = on


func setup(player: Fighter, enemy: Fighter) -> void:
	_player = player
	_enemy = enemy


func set_message(headline: String, subline: String) -> void:
	_headline = headline
	_subline = subline


## White screen flash for big impacts (0..1).
func flash(strength: float) -> void:
	_flash = maxf(_flash, strength)


## Cinematic black bars (finishers).
func set_letterbox(on: bool) -> void:
	_letterbox_target = 1.0 if on else 0.0


## Short highlighted line in the lower third (e.g. the finisher name).
func set_banner(text: String, color: Color) -> void:
	_banner = text
	_banner_color = color


func set_debug(visible_flag: bool, lines: PackedStringArray) -> void:
	_debug_visible = visible_flag
	_debug_lines = lines


func _process(delta: float) -> void:
	# Real time: flashes and bars keep their speed during slow motion.
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	_flash = maxf(_flash - FLASH_DECAY_PER_SEC * real_delta, 0.0)
	_count_age += real_delta
	_letterbox = move_toward(_letterbox, _letterbox_target, real_delta * 4.0)
	var fighters: Array[Fighter] = [_player, _enemy]
	for i in fighters.size():
		var f := fighters[i]
		if f == null:
			continue
		var ratio := float(f.health) / float(f.max_health)
		_trail[i] = ratio if _trail[i] < ratio else move_toward(_trail[i], ratio, TRAIL_DRAIN_PER_SEC * delta)
		var pr := f.posture / CombatData.POSTURE_MAX
		_posture_shown[i] = lerpf(_posture_shown[i], pr, 1.0 - exp(-14.0 * real_delta))
	for i in range(_popups.size() - 1, -1, -1):
		_popups[i]["age"] += real_delta
		if _popups[i]["age"] > POPUP_LIFE:
			_popups.remove_at(i)
	_canvas.queue_redraw()


func _on_canvas_draw() -> void:
	if _player == null or _enemy == null:
		return
	if _letterbox > 0.0:
		var h := LETTERBOX_HEIGHT * smoothstep(0.0, 1.0, _letterbox)
		_canvas.draw_rect(Rect2(0.0, 0.0, SCREEN_W, h), Color.BLACK)
		_canvas.draw_rect(Rect2(0.0, 720.0 - h, SCREEN_W, h), Color.BLACK)
	_draw_bar(_player, BAR_MARGIN, false, _trail[0])
	_draw_bar(_enemy, SCREEN_W - BAR_MARGIN - BAR_WIDTH, true, _trail[1])
	_draw_posture(_player, BAR_MARGIN, _posture_shown[0])
	_draw_posture(_enemy, SCREEN_W - BAR_MARGIN - BAR_WIDTH, _posture_shown[1])
	_draw_popups()
	_draw_combo(_enemy, BAR_MARGIN, HORIZONTAL_ALIGNMENT_LEFT)
	_draw_combo(_player, SCREEN_W - BAR_MARGIN - BAR_WIDTH, HORIZONTAL_ALIGNMENT_RIGHT)

	if _banner != "":
		# Lower third, clear of the health bars and the dev panel.
		var band := Rect2(0.0, 600.0, SCREEN_W, 52.0)
		_canvas.draw_rect(band, Color(0.0, 0.0, 0.0, 0.55))
		_canvas.draw_rect(Rect2(0.0, 600.0, SCREEN_W, 3.0), _banner_color)
		_canvas.draw_rect(Rect2(0.0, 649.0, SCREEN_W, 3.0), _banner_color)
		_shadow_text(Vector2(0.0, 638.0), _banner, 30, HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W, COLOR_TEXT)
	if _headline != "":
		_shadow_text(Vector2(0.0, 300.0), _headline, 72, HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W, COLOR_TEXT)
	if _subline != "":
		_shadow_text(Vector2(0.0, 350.0), _subline, 24, HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W, COLOR_DIM)
	if _count_text != "":
		_draw_countdown()

	if _show_hints:
		_canvas.draw_string(_font, Vector2(0.0, 706.0),
			"A/D move · 2×A/D dodge · SPACE jump · S crouch · J/K/U/O punches · L kick · W+L high · S+L sweep · I front kick · SHIFT block · S+SHIFT low block · Q stance · R restart",
			HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W, 13, COLOR_DIM)

	if _flash > 0.0:
		_canvas.draw_rect(Rect2(0.0, 0.0, SCREEN_W, 720.0), Color(1.0, 0.97, 0.9, _flash * 0.75))

	if _debug_visible and not _debug_lines.is_empty():
		var line_h := 17.0
		var panel := Rect2(12.0, 96.0, 470.0, line_h * _debug_lines.size() + 12.0)
		_canvas.draw_rect(panel, Color(0.0, 0.0, 0.0, 0.55))
		for i in _debug_lines.size():
			_canvas.draw_string(_font, Vector2(20.0, 114.0 + i * line_h), _debug_lines[i],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 1.0, 0.75))


func _draw_bar(f: Fighter, x: float, mirrored: bool, trail: float) -> void:
	var ratio := float(f.health) / float(f.max_health)
	var frame := Rect2(x - 3.0, BAR_Y - 3.0, BAR_WIDTH + 6.0, BAR_HEIGHT + 6.0)
	_canvas.draw_rect(frame, COLOR_BAR_BG)
	_canvas.draw_rect(_bar_rect(x, trail, mirrored), COLOR_TRAIL)
	_canvas.draw_rect(_bar_rect(x, ratio, mirrored), COLOR_BAR_LOW if ratio < 0.3 else COLOR_BAR_FILL)
	_canvas.draw_rect(frame, Color(1.0, 1.0, 1.0, 0.25), false, 1.0)

	var align := HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
	_canvas.draw_string(_font, Vector2(x, BAR_Y - 10.0), f.fighter_name, align, BAR_WIDTH, 20, COLOR_TEXT)
	var swatch_x := x + BAR_WIDTH - 12.0 if not mirrored else x
	_canvas.draw_rect(Rect2(swatch_x, BAR_Y - 24.0, 12.0, 12.0), f.accent_color)
	var hp_align := HORIZONTAL_ALIGNMENT_LEFT if mirrored else HORIZONTAL_ALIGNMENT_RIGHT
	_canvas.draw_string(_font, Vector2(x, BAR_Y + BAR_HEIGHT + 27.0), "%d / %d" % [f.health, f.max_health],
		hp_align, BAR_WIDTH, 14, COLOR_DIM)
	# Stance name on the opposite side of the HP readout.
	var stance_align := HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
	_canvas.draw_string(_font, Vector2(x, BAR_Y + BAR_HEIGHT + 27.0), Stances.stance_name(f.stance),
		stance_align, BAR_WIDTH, 14, f.accent_color.lerp(COLOR_TEXT, 0.4))


## Posture: empty = invisible track; fills from the centre outward, turns red
## near full, flashes white while broken, shows a grey track while locked.
func _draw_posture(f: Fighter, x: float, shown: float) -> void:
	var track := Rect2(x, POSTURE_Y, BAR_WIDTH, POSTURE_H)
	_canvas.draw_rect(track.grow(1.0), Color(0.0, 0.0, 0.0, 0.5))
	if f.posture_lock > 0 and not f.is_posture_broken():
		_canvas.draw_rect(track, COLOR_POSTURE_LOCK)
		return
	var ratio := 1.0 if f.is_posture_broken() else clampf(shown, 0.0, 1.0)
	if ratio <= 0.001:
		return
	var w := BAR_WIDTH * ratio
	var fill := Rect2(x + (BAR_WIDTH - w) * 0.5, POSTURE_Y, w, POSTURE_H)
	var color := COLOR_POSTURE.lerp(COLOR_POSTURE_HIGH, smoothstep(0.6, 0.95, ratio))
	if f.is_posture_broken():
		color = Color.WHITE if int(Time.get_ticks_msec() / 80) % 2 == 0 else COLOR_POSTURE_HIGH
	_canvas.draw_rect(fill, color)


func _draw_popups() -> void:
	for pop in _popups:
		var t: float = pop["age"] / POPUP_LIFE
		var x := BAR_MARGIN if pop["side"] == 0 else SCREEN_W - BAR_MARGIN - BAR_WIDTH
		var align := HORIZONTAL_ALIGNMENT_LEFT if pop["side"] == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		var c: Color = pop["color"]
		c.a = 1.0 - smoothstep(0.6, 1.0, t)
		var rise := -10.0 * t
		_shadow_text(Vector2(x, BAR_Y + 100.0 + rise), pop["text"], 26, align, BAR_WIDTH, c)


func _bar_rect(x: float, ratio: float, mirrored: bool) -> Rect2:
	var w := BAR_WIDTH * clampf(ratio, 0.0, 1.0)
	var left := x + BAR_WIDTH - w if mirrored else x
	return Rect2(left, BAR_Y, w, BAR_HEIGHT)


## Shows the combo the given fighter is *receiving*, under the attacker's bar.
func _draw_combo(victim: Fighter, x: float, align: HorizontalAlignment) -> void:
	if victim.received_combo < 2 or victim.combo_display_frames <= 0:
		return
	var alpha := clampf(victim.combo_display_frames / 20.0, 0.0, 1.0)
	_shadow_text(Vector2(x, BAR_Y + 62.0), "%d HITS" % victim.received_combo, 30, align, BAR_WIDTH,
		Color(1.0, 0.85, 0.4, alpha))


## Countdown number: pops in large, settles, fades near the end of its second.
## "FIGHT!" gets a bigger pop and a flash bar behind it.
func _draw_countdown() -> void:
	var fight := _count_text.begins_with("FIGHT")
	var pop := 1.0 + 0.6 * exp(-_count_age * 12.0)
	var alpha := clampf(1.0 - (_count_age - 0.7) / 0.3, 0.0, 1.0) if not fight else clampf(1.0 - (_count_age - 0.5) / 0.25, 0.0, 1.0)
	if alpha <= 0.0:
		return
	var size := (110.0 if fight else 130.0) * pop
	var centre := Vector2(SCREEN_W * 0.5, 300.0)
	if fight:
		var bar_h := 120.0 * clampf(_count_age * 8.0, 0.0, 1.0)
		_canvas.draw_rect(Rect2(0.0, centre.y - bar_h * 0.5, SCREEN_W, bar_h), Color(0.42, 0.13, 0.11, 0.7 * alpha))
	var text_color := Color(1.0, 0.86, 0.45, alpha) if fight else Color(COLOR_TEXT, alpha)
	var baseline := Vector2(0.0, centre.y + size * 0.36)
	_canvas.draw_string(_font, baseline + Vector2(3.0, 4.0), _count_text, HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W, int(size), Color(0, 0, 0, 0.6 * alpha))
	_canvas.draw_string(_font, baseline, _count_text, HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W, int(size), text_color)


func _shadow_text(pos: Vector2, text: String, size: int, align: HorizontalAlignment, width: float, color: Color) -> void:
	_canvas.draw_string(_font, pos + Vector2(2.0, 3.0), text, align, width, size, Color(0.0, 0.0, 0.0, color.a * 0.6))
	_canvas.draw_string(_font, pos, text, align, width, size, color)
