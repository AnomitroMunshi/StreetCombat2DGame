class_name Hud
extends CanvasLayer
## Screen-space HUD: health bars, combo counters, round messages, control hints
## and the developer text panel. Reads Fighter state; never modifies it.

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

var _player: Fighter = null
var _enemy: Fighter = null
var _trail: Array[float] = [1.0, 1.0]
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


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.size = Vector2(SCREEN_W, 720.0)
	add_child(_canvas)
	_canvas.draw.connect(_on_canvas_draw)


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
	_letterbox = move_toward(_letterbox, _letterbox_target, real_delta * 4.0)
	var fighters: Array[Fighter] = [_player, _enemy]
	for i in fighters.size():
		var f := fighters[i]
		if f == null:
			continue
		var ratio := float(f.health) / float(f.max_health)
		_trail[i] = ratio if _trail[i] < ratio else move_toward(_trail[i], ratio, TRAIL_DRAIN_PER_SEC * delta)
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
	_canvas.draw_string(_font, Vector2(x, BAR_Y + BAR_HEIGHT + 20.0), "%d / %d" % [f.health, f.max_health],
		hp_align, BAR_WIDTH, 14, COLOR_DIM)
	# Stance name on the opposite side of the HP readout.
	var stance_align := HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
	_canvas.draw_string(_font, Vector2(x, BAR_Y + BAR_HEIGHT + 20.0), Stances.stance_name(f.stance),
		stance_align, BAR_WIDTH, 14, f.accent_color.lerp(COLOR_TEXT, 0.4))


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


func _shadow_text(pos: Vector2, text: String, size: int, align: HorizontalAlignment, width: float, color: Color) -> void:
	_canvas.draw_string(_font, pos + Vector2(2.0, 3.0), text, align, width, size, Color(0.0, 0.0, 0.0, color.a * 0.6))
	_canvas.draw_string(_font, pos, text, align, width, size, color)
