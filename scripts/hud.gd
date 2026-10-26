class_name Hud
extends CanvasLayer
## Screen-space HUD: health bars, combo counters, round messages, control hints,
## the match buttons (Start / Restart) and the developer text panel. Reads
## Fighter state; never modifies it. Buttons only emit signals for main.gd.

## The centred match button was pressed (mouse, touch, or Enter while focused).
signal start_pressed
signal restart_pressed
signal change_style_pressed
## Style selection: a card was picked (preview) / the choice was confirmed.
signal style_chosen(style_id: StringName)
signal style_confirmed
signal training_pressed
## A training panel button (same names as main.gd's training actions).
signal training_action(action: StringName)

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
## Focus bar: under the posture bar, filling from the inner end.
const FOCUS_Y: float = POSTURE_Y + POSTURE_H + 4.0
const FOCUS_H: float = 5.0
const COLOR_FOCUS := Color(0.95, 0.8, 0.35)
const COLOR_FOCUS_FULL := Color(1.0, 0.95, 0.65)

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
## Finisher cinematics: vignette amount, focus-line amount and their centre.
var _cine: float = 0.0
var _cine_target: float = 0.0
var _cine_lines: float = 0.0
var _cine_focus := Vector2(640.0, 360.0)
var _vignette: GradientTexture2D = null
var _line_seed: int = 0
var _line_clock: float = 0.0
## Impact frame (s left): a couple of frames of black with stark white
## focus lines the instant the knockout blow lands.
var _impact: float = 0.0
const IMPACT_TIME: float = 0.09
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
## Which signal the button emits right now (&"start" / &"rematch" / &"restart").
var _button_mode: StringName = &""
## Secondary button under the main one: CHANGE STYLE.
var _button2: Button = null
## TRAINING, beside START MATCH.
var _button3: Button = null
var _train_panel: PanelContainer = null
var _train_info: RichTextLabel = null
var _move_panel: PanelContainer = null
var _move_info: RichTextLabel = null
var _train_buttons: VBoxContainer = null
# Style selection panel: card row (scrolls for big rosters), details, confirm.
var _select_panel: PanelContainer = null
var _cards: HBoxContainer = null
var _details: RichTextLabel = null
var _confirm: Button = null
var _selected_id: StringName = &""


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.size = Vector2(SCREEN_W, 720.0)
	add_child(_canvas)
	_canvas.draw.connect(_on_canvas_draw)
	_button = _make_button()
	add_child(_button)
	_button2 = _make_button()
	_button2.size = Vector2(240.0, 44.0)
	_button2.position = Vector2((SCREEN_W - _button2.size.x) * 0.5, 642.0)
	_button2.add_theme_font_size_override("font_size", 20)
	_button2.text = "CHANGE STYLE"
	_button2.pressed.disconnect(_on_button_pressed)
	_button2.pressed.connect(func() -> void:
		_button2.visible = false
		_button3.visible = false
		change_style_pressed.emit())
	add_child(_button2)
	_button3 = _make_button()
	_button3.size = Vector2(200.0, 52.0)
	_button3.position = Vector2(SCREEN_W * 0.5 + 180.0, 570.0)
	_button3.add_theme_font_size_override("font_size", 22)
	_button3.text = "TRAINING"
	_button3.pressed.disconnect(_on_button_pressed)
	_button3.pressed.connect(func() -> void:
		show_button(&"")
		training_pressed.emit())
	add_child(_button3)
	_build_style_panel()
	_build_training_panels()


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
		if _select_panel.visible:
			style_confirmed.emit()
		else:
			press_button()


## Shows the centred button as START MATCH, REMATCH or RESTART MATCH (mode &""
## hides it). START and REMATCH also offer CHANGE STYLE underneath.
func show_button(mode: StringName) -> void:
	_button_mode = mode
	_button.visible = mode != &""
	_button.disabled = mode == &""
	_button2.visible = mode == &"start" or mode == &"rematch"
	_button3.visible = mode == &"start"
	if mode == &"start":
		_button.text = "START MATCH"
	elif mode == &"rematch":
		_button.text = "REMATCH"
	elif mode == &"restart":
		_button.text = "RESTART MATCH"


func is_training_button_visible() -> bool:
	return _button3.visible


func press_training() -> void:
	if _button3.visible:
		_button3.pressed.emit()


# --- Training -------------------------------------------------------------------

const TRAINING_BUTTONS: Array = [
	[&"dummy", "DUMMY MODE  [1]"], [&"dummy_style", "DUMMY STYLE  [2]"], [&"speed", "SPEED  [3]"],
	[&"focus", "FOCUS  [4]"], [&"next_finisher", "NEXT FINISHER  [5]"], [&"play_finisher", "PLAY FINISHER  [6]"],
	[&"pause", "PAUSE  [P]"], [&"step", "STEP FRAME  [.]"], [&"hitboxes", "HITBOXES  [F1]"],
	[&"reset", "RESET  [R]"], [&"panels", "HIDE PANELS  [H]"], [&"exit", "EXIT  [Esc]"],
]


func _panel_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.04, 0.04, 0.8)
	box.border_color = Color(0.95, 0.76, 0.3, 0.6)
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	return box


func _text_label(size: Vector2) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", 14)
	label.add_theme_font_size_override("bold_font_size", 14)
	label.add_theme_color_override("default_color", COLOR_TEXT)
	return label


func _build_training_panels() -> void:
	_train_panel = PanelContainer.new()
	_train_panel.add_theme_stylebox_override("panel", _panel_box())
	_train_panel.position = Vector2(12.0, 132.0)
	_train_info = _text_label(Vector2(560.0, 0.0))
	_train_panel.add_child(_train_info)
	_train_panel.visible = false
	add_child(_train_panel)

	_move_panel = PanelContainer.new()
	_move_panel.add_theme_stylebox_override("panel", _panel_box())
	_move_panel.position = Vector2(12.0, 298.0)
	_move_info = _text_label(Vector2(250.0, 0.0))
	_move_info.add_theme_font_size_override("normal_font_size", 13)
	_move_panel.add_child(_move_info)
	_move_panel.visible = false
	add_child(_move_panel)

	_train_buttons = VBoxContainer.new()
	_train_buttons.position = Vector2(SCREEN_W - 212.0, 132.0)
	_train_buttons.add_theme_constant_override("separation", 3)
	for entry in TRAINING_BUTTONS:
		var b := Button.new()
		b.text = entry[1]
		b.custom_minimum_size = Vector2(200.0, 28.0)
		b.focus_mode = Control.FOCUS_NONE  # Space must stay jump
		b.add_theme_font_size_override("font_size", 13)
		for state in ["normal", "hover", "pressed"]:
			var box := _panel_box()
			box.content_margin_top = 2.0
			box.content_margin_bottom = 2.0
			if state != "normal":
				box.bg_color = Color(0.42, 0.13, 0.11, 0.95)
			b.add_theme_stylebox_override(state, box)
		b.add_theme_color_override("font_color", COLOR_TEXT)
		var action: StringName = entry[0]
		b.pressed.connect(func() -> void: training_action.emit(action))
		_train_buttons.add_child(b)
	_train_buttons.visible = false
	add_child(_train_buttons)


func show_training(on: bool) -> void:
	# The panels list the keys; the match hint line would only repeat them.
	_show_hints = not on
	_train_panel.visible = on
	_move_panel.visible = on
	_train_buttons.visible = on


func toggle_training_panels() -> void:
	var on := not _train_panel.visible
	_train_panel.visible = on
	_move_panel.visible = on
	# The buttons stay so the panels can be brought back with the mouse.
	(_train_buttons.get_child(10) as Button).text = "HIDE PANELS  [H]" if on else "SHOW PANELS  [H]"


func is_training_visible() -> bool:
	return _train_buttons.visible


func set_training_info(text: String) -> void:
	if _train_info.text != text:
		_train_info.text = text


func set_move_list(text: String) -> void:
	_move_info.text = text


func is_change_style_visible() -> bool:
	return _button2.visible


func press_change_style() -> void:
	if _button2.visible:
		_button2.pressed.emit()


# --- Style selection --------------------------------------------------------

func _build_style_panel() -> void:
	_select_panel = PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.04, 0.04, 0.9)
	bg.border_color = Color(0.95, 0.76, 0.3, 0.8)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(8)
	bg.set_content_margin_all(14)
	_select_panel.add_theme_stylebox_override("panel", bg)
	# Right half of the screen: the player previews the style on the left.
	_select_panel.position = Vector2(600.0, 72.0)
	_select_panel.size = Vector2(640.0, 616.0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_select_panel.add_child(box)
	var title := Label.new()
	title.text = "CHOOSE YOUR MARTIAL ART"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 62.0)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 8)
	scroll.add_child(_cards)
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.fit_content = false
	_details.scroll_active = true
	_details.custom_minimum_size = Vector2(0.0, 420.0)
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details.add_theme_font_size_override("normal_font_size", 15)
	_details.add_theme_font_size_override("bold_font_size", 15)
	box.add_child(_details)
	_confirm = _make_button()
	_confirm.visible = true
	_confirm.custom_minimum_size = Vector2(0.0, 48.0)
	_confirm.add_theme_font_size_override("font_size", 22)
	_confirm.pressed.disconnect(_on_button_pressed)
	_confirm.pressed.connect(func() -> void: style_confirmed.emit())
	box.add_child(_confirm)
	_select_panel.visible = false
	add_child(_select_panel)


## Shows the roster with `selected_id` highlighted and its details.
func show_style_select(styles: Array[MartialArtStyle], selected_id: StringName) -> void:
	_selected_id = selected_id
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	var chosen: MartialArtStyle = null
	for st in styles:
		var card := _make_button()
		card.visible = true
		card.custom_minimum_size = Vector2(118.0, 54.0)
		card.add_theme_font_size_override("font_size", 15)
		card.text = "%s\n%s" % [st.display_name.to_upper(), _stars(st.difficulty)]
		if st.id == selected_id:
			chosen = st
			var hi := StyleBoxFlat.new()
			hi.bg_color = Color(0.42, 0.13, 0.11, 0.95)
			hi.border_color = Color(1.0, 0.85, 0.4)
			hi.set_border_width_all(3)
			hi.set_corner_radius_all(6)
			card.add_theme_stylebox_override("normal", hi)
		card.pressed.disconnect(_on_button_pressed)
		var sid := st.id
		card.pressed.connect(func() -> void: style_chosen.emit(sid))
		_cards.add_child(card)
	if chosen != null:
		_details.text = _style_details(chosen)
		_confirm.text = "CONFIRM %s" % chosen.display_name.to_upper()
	_select_panel.visible = true


func hide_style_select() -> void:
	_select_panel.visible = false


func is_style_select_visible() -> bool:
	return _select_panel.visible


func get_selected_style_id() -> StringName:
	return _selected_id


static func _stars(n: int) -> String:
	return "★".repeat(n) + "☆".repeat(5 - n)


static func _style_details(st: MartialArtStyle) -> String:
	var t := "[b][font_size=22]%s[/font_size][/b]   [color=#b9a98f]%s · difficulty %s[/color]\n" % [
		st.display_name.to_upper(), String(st.category).to_upper(), _stars(st.difficulty)]
	t += "%s\n\n" % st.description
	for s in st.strengths:
		t += "[color=#8fd18f]+ %s[/color]\n" % s
	for w in st.weaknesses:
		t += "[color=#e08a7a]- %s[/color]\n" % w
	# Two columns so the whole moveset fits without scrolling.
	t += "\n[b]MOVES[/b]\n[table=4]"
	for row in st.move_list():
		t += "[cell][color=#f2c14e]%s  [/color][/cell][cell]%s      [/cell]" % [row[0], row[1]]
	t += "[/table]\n"
	if st.signature != &"":
		t += "[b]SIGNATURE[/b] (F at full Focus)  [color=#f2c14e]%s[/color]\n" % CombatData.get_attack(CombatData.type_for_id(st.signature)).display_name
	if not st.finishers.is_empty():
		var names: Array = []
		for fid in st.finishers:
			names.append(FinisherDirector.DISPLAY_NAMES[FinisherDirector.kind_for_id(fid)])
		t += "[b]FINISHERS[/b]  %s\n" % "  ·  ".join(names)
	t += "\n[color=#b9a98f]Q next style · ENTER confirm[/color]"
	return t


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
	_button2.visible = false
	_button3.visible = false
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
func impact_frame() -> void:
	_impact = IMPACT_TIME


func set_cinematic(amount: float, lines: float, focus: Vector2) -> void:
	_cine_target = amount
	_cine_lines = lines
	_cine_focus = focus


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
	_cine = move_toward(_cine, _cine_target, real_delta * 2.5)
	_impact = maxf(_impact - real_delta, 0.0)
	_line_clock += real_delta
	if _line_clock > 0.05:
		_line_clock = 0.0
		_line_seed += 1  # focus lines flicker
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


## Dark edges pulling the eye to the middle of the frame.
func _draw_vignette(amount: float) -> void:
	if _vignette == null:
		var g := Gradient.new()
		g.set_color(0, Color(0.0, 0.0, 0.0, 0.0))
		g.set_color(1, Color(0.0, 0.0, 0.0, 1.0))
		g.add_point(0.55, Color(0.0, 0.0, 0.0, 0.0))
		g.add_point(0.8, Color(0.0, 0.0, 0.0, 0.45))
		_vignette = GradientTexture2D.new()
		_vignette.gradient = g
		_vignette.fill = GradientTexture2D.FILL_RADIAL
		_vignette.fill_from = Vector2(0.5, 0.5)
		_vignette.fill_to = Vector2(1.05, 0.5)
		_vignette.width = 256
		_vignette.height = 144
	_canvas.draw_texture_rect(_vignette, Rect2(0.0, 0.0, SCREEN_W, 720.0), false,
		Color(1.0, 1.0, 1.0, 0.85 * smoothstep(0.0, 1.0, amount)))


## Manga focus lines from the frame edges converging on the knockout blow.
func _draw_focus_lines(amount: float, width: float = 1.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _line_seed
	var centre := _cine_focus
	for i in 56:
		var a := rng.randf() * TAU
		var dir := Vector2.from_angle(a)
		var outer := centre + dir * 1500.0
		var inner := centre + dir * rng.randf_range(150.0, 260.0)
		var w := rng.randf_range(1.0, 4.5) * width
		var c := Color(1.0, 1.0, 1.0, rng.randf_range(0.25, 0.7) * amount)
		var side := Vector2(-dir.y, dir.x) * w
		_canvas.draw_colored_polygon(PackedVector2Array([outer + side, outer - side, inner]), c)


func _on_canvas_draw() -> void:
	if _player == null or _enemy == null:
		return
	if _cine > 0.0:
		_draw_vignette(_cine)
	if _cine_lines > 0.0:
		_draw_focus_lines(_cine_lines)
	if _impact > 0.0:
		# Impact frame: the world drops to black, the blow's centre burns white.
		_canvas.draw_rect(Rect2(0.0, 0.0, SCREEN_W, 720.0), Color(0.0, 0.0, 0.0, 0.82))
		_draw_focus_lines(1.0, 3.0)
		_canvas.draw_circle(_cine_focus, 70.0, Color(1.0, 1.0, 1.0, 0.9))
		_canvas.draw_circle(_cine_focus, 110.0, Color(1.0, 0.92, 0.75, 0.35))
	if _letterbox > 0.0:
		var h := LETTERBOX_HEIGHT * smoothstep(0.0, 1.0, _letterbox)
		_canvas.draw_rect(Rect2(0.0, 0.0, SCREEN_W, h), Color.BLACK)
		_canvas.draw_rect(Rect2(0.0, 720.0 - h, SCREEN_W, h), Color.BLACK)
	# A finisher is a clean cinematic shot: the gameplay HUD steps aside.
	if _cine < 0.05:
		_draw_gameplay_hud()
	_draw_overlays()


func _draw_gameplay_hud() -> void:
	_draw_bar(_player, BAR_MARGIN, false, _trail[0])
	_draw_bar(_enemy, SCREEN_W - BAR_MARGIN - BAR_WIDTH, true, _trail[1])
	_draw_posture(_player, BAR_MARGIN, _posture_shown[0])
	_draw_posture(_enemy, SCREEN_W - BAR_MARGIN - BAR_WIDTH, _posture_shown[1])
	_draw_focus(_player, BAR_MARGIN, false)
	_draw_focus(_enemy, SCREEN_W - BAR_MARGIN - BAR_WIDTH, true)
	_draw_popups()
	_draw_combo(_enemy, BAR_MARGIN, HORIZONTAL_ALIGNMENT_LEFT)
	_draw_combo(_player, SCREEN_W - BAR_MARGIN - BAR_WIDTH, HORIZONTAL_ALIGNMENT_RIGHT)
	if _show_hints:
		_canvas.draw_string(_font, Vector2(0.0, 706.0),
			"A/D move · 2×A/D dash · S+2×A/D roll · SPACE jump · J light · K heavy · L technique · W/S + J/K high/low · F signature · SHIFT block/parry · S+SHIFT low block · R rematch",
			HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W, 13, COLOR_DIM)


## Messages, banner, countdown, flash and the developer panel (always shown).
func _draw_overlays() -> void:
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
	_canvas.draw_string(_font, Vector2(x, BAR_Y + BAR_HEIGHT + 36.0), "%d / %d" % [f.health, f.max_health],
		hp_align, BAR_WIDTH, 14, COLOR_DIM)
	# Stance name on the opposite side of the HP readout.
	var stance_align := HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
	var style_label := f.style.display_name.to_upper() if f.style != null else Stances.stance_name(f.stance)
	_canvas.draw_string(_font, Vector2(x, BAR_Y + BAR_HEIGHT + 36.0), style_label,
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


## Focus: fills toward the outer end; full = pulsing, with the signature name
## and SIGNATURE READY - F for the player.
func _draw_focus(f: Fighter, x: float, mirrored: bool) -> void:
	var track := Rect2(x, FOCUS_Y, BAR_WIDTH, FOCUS_H)
	_canvas.draw_rect(track.grow(1.0), Color(0.0, 0.0, 0.0, 0.5))
	var ratio := clampf(f.focus / CombatData.FOCUS_MAX, 0.0, 1.0)
	if ratio <= 0.0:
		return
	var w := BAR_WIDTH * ratio
	var fill := Rect2(x + BAR_WIDTH - w if mirrored else x, FOCUS_Y, w, FOCUS_H)
	var full := ratio >= 1.0
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
	_canvas.draw_rect(fill, COLOR_FOCUS.lerp(COLOR_FOCUS_FULL, pulse) if full else COLOR_FOCUS)
	if full and f.style != null and f.style.signature != &"":
		var sig := CombatData.get_attack(CombatData.type_for_id(f.style.signature)).display_name.to_upper()
		var text := ("SIGNATURE READY - F   " + sig) if f == _player else sig + " READY"
		var align := HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
		_shadow_text(Vector2(x, BAR_Y + 84.0), text, 18, align, BAR_WIDTH, Color(1.0, 0.9, 0.5, 0.75 + 0.25 * pulse))


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
