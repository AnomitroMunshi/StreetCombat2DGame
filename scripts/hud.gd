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
## The AI difficulty button (pre-match): cycle to the next level.
signal difficulty_pressed
## A training panel button (same names as main.gd's training actions).
signal training_action(action: StringName)
## The on-screen pause button.
signal pause_pressed

const SCREEN_W: float = 1280.0
const BAR_WIDTH: float = 480.0
const BAR_HEIGHT: float = 20.0
const BAR_MARGIN: float = 48.0
const BAR_Y: float = 44.0
const COLOR_ROUND_WON := Color(1.0, 0.8, 0.25)
const TOP_SHADE_HEIGHT: float = 125.0
const TOP_SHADE_ALPHA: float = 0.5

const TRAIL_DRAIN_PER_SEC: float = 0.5
const LETTERBOX_HEIGHT: float = 62.0
const FLASH_DECAY_PER_SEC: float = 3.5

const COLOR_BAR_BG := Color(0.06, 0.05, 0.05, 1.0)  # opaque: nothing shows through
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
## Nine styles fit in three rows; wider cards keep full style names legible.
const STYLE_COLUMNS: int = 3
const STYLE_CARD_W: float = 192.0
## Baseline of the K.O. / result headline.
const HEADLINE_Y: float = 200.0
## Message lanes under each health bar (baselines): style + HP, signature
## readiness, the combo counter, then up to POPUP_SLOTS stacked callouts. Each
## kind of message has its own row, so nothing is ever drawn over another.
const LANE_X_Y: float = BAR_Y + 80.0
const LANE_READY_Y: float = BAR_Y + 104.0
const LANE_COMBO_Y: float = BAR_Y + 132.0
const LANE_POPUP_Y: float = BAR_Y + 160.0
const LANE_POPUP_STEP: float = 26.0
const POPUP_SLOTS: int = 3
const READY_SIZE: int = 18
const COMBO_SIZE: int = 26
const POPUP_SIZE: int = 22
## With the training panels open, the callout lanes move inward between the
## info panel (left) and the button column (right).
const TRAINING_LANE_W: float = 255.0
const TRAINING_LANE_GUTTER: float = 30.0
const TRAINING_LANE_LEFT: float = 520.0
## Focus bar: under the posture bar, filling from the inner end.
const FOCUS_Y: float = POSTURE_Y + POSTURE_H + 4.0
const FOCUS_H: float = 5.0
const COLOR_FOCUS := Color(0.95, 0.8, 0.35)
const COLOR_FOCUS_FULL := Color(1.0, 0.95, 0.65)

## Rounds won [player, rival] and rounds needed (0 = no pips, e.g. training).
var _round_wins: Array = [0, 0]
var _rounds_to_win: int = 0
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
var _pause_button: Button = null
var _settings_button: Button = null
var _settings_panel: PanelContainer = null
var _settings_sliders: Dictionary = {}
var _settings_fullscreen: CheckButton = null
## Speech bubbles: side (0 player, 1 rival) -> {"fighter", "text", "age"}.
var _speech: Dictionary = {}
var _speech_font: Font = null
const SPEECH_FONT_SIZE: int = 20
const SPEECH_POP_TIME: float = 0.12
## Fonts with Bengali glyphs, tried in order (installed system fonts: nothing
## is bundled or downloaded). Nirmala UI and Vrinda ship with Windows.
const SPEECH_FONT_NAMES: PackedStringArray = ["Nirmala UI", "Vrinda", "Shonar Bangla", "Noto Sans Bengali",
	"Noto Serif Bengali", "Lohit Bengali", "Kalpurush", "SolaimanLipi"]
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
## AI difficulty, the other side of START MATCH ("AI: NORMAL  [G]").
var _button4: Button = null
var _train_panel: PanelContainer = null
var _train_info: RichTextLabel = null
var _move_panel: PanelContainer = null
var _move_info: RichTextLabel = null
var _train_buttons: VBoxContainer = null
# Style selection panel: card row (scrolls for big rosters), details, confirm.
var _select_panel: PanelContainer = null
var _cards: GridContainer = null
var _details: RichTextLabel = null
var _confirm: Button = null
var _selected_id: StringName = &""


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_speech_font = make_speech_font()
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
	_button4 = _make_button()
	_button4.size = Vector2(200.0, 52.0)
	_button4.position = Vector2(SCREEN_W * 0.5 - 180.0 - _button4.size.x, 570.0)
	_button4.add_theme_font_size_override("font_size", 20)
	_button4.pressed.disconnect(_on_button_pressed)
	_button4.pressed.connect(func() -> void: difficulty_pressed.emit())
	add_child(_button4)
	set_difficulty(EnemyAI.selected_difficulty)
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
	_button4.visible = mode == &"start"
	show_settings_button(mode == &"start" or mode == &"rematch")
	if mode == &"start":
		_button.text = "START MATCH"
	elif mode == &"rematch":
		_button.text = "REMATCH"
	elif mode == &"restart":
		_button.text = "RESTART MATCH"


## Shows the rival AI's difficulty on its button.
func set_difficulty(level: StringName) -> void:
	_button4.text = "AI: %s  [G]" % String(level).to_upper()


func get_difficulty_text() -> String:
	return _button4.text


func is_difficulty_button_visible() -> bool:
	return _button4.visible


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
	_train_info = _text_label(Vector2(470.0, 0.0))
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

	# Pause button, top centre between the health bars (matches only).
	_pause_button = Button.new()
	_pause_button.text = "II  PAUSE"
	_pause_button.custom_minimum_size = Vector2(96.0, 26.0)
	_pause_button.position = Vector2(SCREEN_W * 0.5 - 48.0, 8.0)
	_pause_button.focus_mode = Control.FOCUS_NONE  # Space must stay jump
	_pause_button.add_theme_font_size_override("font_size", 13)
	for state in ["normal", "hover", "pressed"]:
		var box := _panel_box()
		box.content_margin_top = 2.0
		box.content_margin_bottom = 2.0
		if state != "normal":
			box.bg_color = Color(0.42, 0.13, 0.11, 0.95)
		_pause_button.add_theme_stylebox_override(state, box)
	_pause_button.add_theme_color_override("font_color", COLOR_TEXT)
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	_pause_button.visible = false
	add_child(_pause_button)
	_build_settings()


# --- Settings -------------------------------------------------------------------

## Volume sliders (master, music, effects) and fullscreen, from the pre-match
## screen, the result screen or the pause screen (button or O).
func _build_settings() -> void:
	_settings_button = Button.new()
	_settings_button.text = "SETTINGS  [O]"
	_settings_button.custom_minimum_size = Vector2(130.0, 26.0)
	_settings_button.position = Vector2(SCREEN_W - 142.0, 720.0 - 36.0)  # clear of the health bars
	_settings_button.focus_mode = Control.FOCUS_NONE  # Space must stay jump
	_settings_button.add_theme_font_size_override("font_size", 13)
	for state in ["normal", "hover", "pressed"]:
		var box := _panel_box()
		box.content_margin_top = 2.0
		box.content_margin_bottom = 2.0
		if state != "normal":
			box.bg_color = Color(0.42, 0.13, 0.11, 0.95)
		_settings_button.add_theme_stylebox_override(state, box)
	_settings_button.add_theme_color_override("font_color", COLOR_TEXT)
	_settings_button.pressed.connect(toggle_settings)
	_settings_button.visible = false
	add_child(_settings_button)

	_settings_panel = PanelContainer.new()
	var box := _panel_box()
	box.bg_color = Color(0.05, 0.04, 0.04, 0.94)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 14.0
	box.content_margin_bottom = 14.0
	_settings_panel.add_theme_stylebox_override("panel", box)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	_settings_panel.add_child(rows)
	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title)
	for entry in [["MASTER", "master_volume"], ["MUSIC", "music_volume"], ["EFFECTS", "sfx_volume"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name_label := Label.new()
		name_label.text = entry[0]
		name_label.custom_minimum_size = Vector2(90.0, 0.0)
		name_label.add_theme_color_override("font_color", COLOR_TEXT)
		row.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = 5.0
		slider.custom_minimum_size = Vector2(240.0, 24.0)
		slider.focus_mode = Control.FOCUS_NONE
		var value_label := Label.new()
		value_label.custom_minimum_size = Vector2(44.0, 0.0)
		value_label.add_theme_color_override("font_color", COLOR_DIM)
		var key: String = entry[1]
		slider.value_changed.connect(func(v: float) -> void:
			GameSettings.set_volume(key, v / 100.0)
			value_label.text = "%d%%" % int(v))
		row.add_child(slider)
		row.add_child(value_label)
		rows.add_child(row)
		_settings_sliders[key] = slider
	_settings_fullscreen = CheckButton.new()
	_settings_fullscreen.text = "FULLSCREEN"
	_settings_fullscreen.focus_mode = Control.FOCUS_NONE
	_settings_fullscreen.add_theme_color_override("font_color", COLOR_TEXT)
	_settings_fullscreen.toggled.connect(func(on: bool) -> void:
		GameSettings.fullscreen = on
		GameSettings.apply_display())
	rows.add_child(_settings_fullscreen)
	var close := Button.new()
	close.text = "CLOSE  [O]"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(toggle_settings)
	rows.add_child(close)
	_settings_panel.visible = false
	add_child(_settings_panel)


func show_settings_button(on: bool) -> void:
	_settings_button.visible = on
	if not on and _settings_panel.visible:
		toggle_settings()


func is_settings_button_visible() -> bool:
	return _settings_button.visible


func is_settings_open() -> bool:
	return _settings_panel.visible


## Opens the panel with the current values, or closes it and saves them.
func toggle_settings() -> void:
	if _settings_panel.visible:
		_settings_panel.visible = false
		GameSettings.save()
		return
	for key: String in _settings_sliders:
		_settings_sliders[key].value = GameSettings.get_volume(key) * 100.0
	_settings_fullscreen.set_pressed_no_signal(GameSettings.fullscreen)
	_settings_panel.visible = true
	_settings_panel.reset_size()
	_settings_panel.position = (Vector2(SCREEN_W, 720.0) - _settings_panel.size) * 0.5


## The slider for a setting ("master_volume", "music_volume", "sfx_volume").
func settings_slider(key: String) -> HSlider:
	return _settings_sliders.get(key)


func show_pause_button(on: bool) -> void:
	_pause_button.visible = on


func set_paused(on: bool) -> void:
	_pause_button.text = "▶  RESUME" if on else "II  PAUSE"
	show_settings_button(on)


func get_message() -> Array:
	return [_headline, _subline]


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
	# Every style visible at once: a grid of STYLE_COLUMNS cards per row.
	_cards = GridContainer.new()
	_cards.columns = STYLE_COLUMNS
	_cards.add_theme_constant_override("h_separation", 8)
	_cards.add_theme_constant_override("v_separation", 8)
	box.add_child(_cards)
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.fit_content = false
	_details.scroll_active = true
	_details.custom_minimum_size = Vector2(0.0, 250.0)
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
		card.custom_minimum_size = Vector2(STYLE_CARD_W, 54.0)
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
	if st.input_map.has(&"x_move"):
		var x_attack := CombatData.get_attack(st.resolve(&"x_move", false))
		t += "[color=#b9a98f]X: %d s cooldown, no Focus. Block, parry or evade.[/color]\n" % (x_attack.x_cooldown_frames / CombatData.TICK_RATE)
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
## A font for speech bubbles: a system font with Bengali script (complex
## shaping by the text server), falling back to the game font.
static func make_speech_font() -> Font:
	var sys := SystemFont.new()
	sys.font_names = SPEECH_FONT_NAMES
	sys.fallbacks = [ThemeDB.fallback_font]
	return sys


func show_speech(fighter: Fighter, text: String) -> void:
	_speech[0 if fighter == _player else 1] = {"fighter": fighter, "text": text, "age": 0.0}


func hide_speech(fighter: Fighter) -> void:
	_speech.erase(0 if fighter == _player else 1)


## A callout under that fighter's bar: takes the first free row; the same text
## already showing is refreshed instead of stacked; with every row taken the
## oldest callout gives way.
func popup(fighter: Fighter, text: String, color: Color) -> void:
	var side := 0 if fighter == _player else 1
	var used := {}
	var oldest := -1
	for i in _popups.size():
		var p: Dictionary = _popups[i]
		if p["side"] != side:
			continue
		if p["text"] == text:
			p["age"] = 0.0
			p["color"] = color
			return
		used[p["slot"]] = true
		if oldest < 0 or p["age"] > _popups[oldest]["age"]:
			oldest = i
	var slot := 0
	while used.has(slot):
		slot += 1
	if slot >= POPUP_SLOTS:
		slot = _popups[oldest]["slot"]
		_popups.remove_at(oldest)
	_popups.append({"text": text, "side": side, "age": 0.0, "color": color, "slot": slot})


## The x range of a side's callout lanes: under its bar, or inward while the
## training panels are open.
func _lane(side: int) -> Rect2:
	if is_training_visible():
		var x := TRAINING_LANE_LEFT if side == 0 else TRAINING_LANE_LEFT + TRAINING_LANE_W + TRAINING_LANE_GUTTER
		return Rect2(x, 0.0, TRAINING_LANE_W, 0.0)
	return Rect2(BAR_MARGIN if side == 0 else SCREEN_W - BAR_MARGIN - BAR_WIDTH, 0.0, BAR_WIDTH, 0.0)


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
		# Out of health (finisher / K.O.): the bar empties at once, so the
		# slowed-down finisher never reads as if health were left.
		if f.health <= 0:
			_trail[i] = 0.0
		else:
			_trail[i] = ratio if _trail[i] < ratio else move_toward(_trail[i], ratio, TRAIL_DRAIN_PER_SEC * delta)
		var pr := f.posture / CombatData.POSTURE_MAX
		_posture_shown[i] = lerpf(_posture_shown[i], pr, 1.0 - exp(-14.0 * real_delta))
	for side in _speech:
		_speech[side]["age"] += real_delta
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
		# Impact frame: the room dips dark for a beat around the knockout blow
		# (the blow's own light, fx.strike, carries the contact).
		var k := _impact / IMPACT_TIME
		_canvas.draw_rect(Rect2(0.0, 0.0, SCREEN_W, 720.0), Color(0.0, 0.0, 0.0, 0.45 * k))
	if _letterbox > 0.0:
		var h := LETTERBOX_HEIGHT * smoothstep(0.0, 1.0, _letterbox)
		_canvas.draw_rect(Rect2(0.0, 0.0, SCREEN_W, h), Color.BLACK)
		_canvas.draw_rect(Rect2(0.0, 720.0 - h, SCREEN_W, h), Color.BLACK)
	# A finisher is a clean cinematic shot: the gameplay HUD steps aside.
	if _cine < 0.05:
		_draw_gameplay_hud()
	_draw_overlays()


func _draw_gameplay_hud() -> void:
	# A soft dark fade behind the bars and labels, so they read over any stage
	# (a bright sunset sky included).
	var shade := Color(0.0, 0.0, 0.0, TOP_SHADE_ALPHA)
	_canvas.draw_polygon(PackedVector2Array([Vector2(0.0, 0.0), Vector2(SCREEN_W, 0.0),
		Vector2(SCREEN_W, TOP_SHADE_HEIGHT), Vector2(0.0, TOP_SHADE_HEIGHT)]),
		PackedColorArray([shade, shade, Color(shade, 0.0), Color(shade, 0.0)]))
	_draw_bar(_player, BAR_MARGIN, false, _trail[0])
	_draw_bar(_enemy, SCREEN_W - BAR_MARGIN - BAR_WIDTH, true, _trail[1])
	_draw_round_pips(0, BAR_MARGIN, false)
	_draw_round_pips(1, SCREEN_W - BAR_MARGIN - BAR_WIDTH, true)
	_draw_posture(_player, BAR_MARGIN, _posture_shown[0])
	_draw_posture(_enemy, SCREEN_W - BAR_MARGIN - BAR_WIDTH, _posture_shown[1])
	_draw_focus(_player, BAR_MARGIN, false)
	_draw_focus(_enemy, SCREEN_W - BAR_MARGIN - BAR_WIDTH, true)
	_draw_x_move(_player, BAR_MARGIN, false)
	_draw_x_move(_enemy, SCREEN_W - BAR_MARGIN - BAR_WIDTH, true)
	_draw_popups()
	_draw_combo(_enemy, BAR_MARGIN, HORIZONTAL_ALIGNMENT_LEFT)
	_draw_combo(_player, SCREEN_W - BAR_MARGIN - BAR_WIDTH, HORIZONTAL_ALIGNMENT_RIGHT)
	if _show_hints and _headline == "":
		_canvas.draw_string(_font, Vector2(0.0, 706.0),
			"A/D move · 2×A/D dash · SPACE jump · J light · K heavy · L technique · W/S + J/K high/low · SPACE + J/K power · F signature · X special · SHIFT block/parry · S+SHIFT low block · R rematch",
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
	# Upper third: clear of the bars above and the fighters' heads below.
	if _headline != "":
		_shadow_text(Vector2(0.0, HEADLINE_Y), _headline, 72, HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W, COLOR_TEXT)
	if _subline != "":
		_shadow_text(Vector2(0.0, HEADLINE_Y + 42.0), _subline, 24, HORIZONTAL_ALIGNMENT_CENTER, SCREEN_W, COLOR_DIM)
	if _count_text != "":
		_draw_countdown()
	_draw_speech()

	if _flash > 0.0:
		_canvas.draw_rect(Rect2(0.0, 0.0, SCREEN_W, 720.0), Color(1.0, 0.97, 0.9, _flash * 0.75))

	if _debug_visible and not _debug_lines.is_empty():
		var line_h := 17.0
		var panel := Rect2(12.0, 96.0, 470.0, line_h * _debug_lines.size() + 12.0)
		_canvas.draw_rect(panel, Color(0.0, 0.0, 0.0, 0.55))
		for i in _debug_lines.size():
			_canvas.draw_string(_font, Vector2(20.0, 114.0 + i * line_h), _debug_lines[i],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 1.0, 0.75))


## Rounds won, as pips beside each name ([player, rival]); rounds_to_win 0 hides them.
func set_rounds(wins: Array, rounds_to_win: int) -> void:
	_round_wins = wins.duplicate()
	_rounds_to_win = rounds_to_win
	_canvas.queue_redraw()


## One pip per round needed to win, filled gold for each round won, set just
## inside the colour swatch.
func _draw_round_pips(side: int, x: float, mirrored: bool) -> void:
	if _rounds_to_win <= 0:
		return
	for i in _rounds_to_win:
		var step := 20.0 + i * 18.0
		var cx := x + BAR_WIDTH - 12.0 - step if not mirrored else x + 12.0 + step
		var c := Vector2(cx, BAR_Y - 18.0)
		var won: bool = i < int(_round_wins[side])
		_canvas.draw_circle(c, 6.0, COLOR_ROUND_WON if won else Color(0.0, 0.0, 0.0, 0.55))
		_canvas.draw_arc(c, 6.0, 0.0, TAU, 20, Color(1.0, 1.0, 1.0, 0.6), 1.5, true)


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
	_canvas.draw_string_outline(_font, Vector2(x, BAR_Y + BAR_HEIGHT + 36.0), "%d / %d" % [f.health, f.max_health],
		hp_align, BAR_WIDTH, 14, 4, Color(0.0, 0.0, 0.0, 0.7))
	_canvas.draw_string(_font, Vector2(x, BAR_Y + BAR_HEIGHT + 36.0), "%d / %d" % [f.health, f.max_health],
		hp_align, BAR_WIDTH, 14, COLOR_DIM)
	# Stance name on the opposite side of the HP readout.
	var stance_align := HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
	var style_label := f.style.display_name.to_upper() if f.style != null else Stances.stance_name(f.stance)
	_canvas.draw_string_outline(_font, Vector2(x, BAR_Y + BAR_HEIGHT + 36.0), style_label,
		stance_align, BAR_WIDTH, 14, 4, Color(0.0, 0.0, 0.0, 0.7))
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
	# Only a fighter who can still use it is told it is ready, and never once
	# the round is over (K.O. / result).
	if full and f.style != null and f.style.signature != &"" and f.health > 0 and not f.is_down() and _headline == "":
		var sig := CombatData.get_attack(CombatData.type_for_id(f.style.signature)).display_name.to_upper()
		var text := ("SIGNATURE READY - F   " + sig) if f == _player else sig + " READY"
		var align := HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
		_shadow_text(Vector2(x, LANE_READY_Y), text, _fit_size(text, READY_SIZE, BAR_WIDTH), align, BAR_WIDTH,
			Color(1.0, 0.9, 0.5, 0.75 + 0.25 * pulse))


## Each fighter exposes remaining cooldown, measured in simulation ticks.
func _draw_x_move(f: Fighter, x: float, mirrored: bool) -> void:
	if f.style == null or not f.style.input_map.has(&"x_move"):
		return
	var name := f.style.move_name(f.style.input_map[&"x_move"])
	var ready := f.x_cooldown <= 0
	var text := "X READY  -  " + name if ready else "X  %.1f s  -  %s" % [float(f.x_cooldown) / CombatData.TICK_RATE, name]
	var color := COLOR_FOCUS_FULL if ready else COLOR_DIM
	var align := HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
	_shadow_text(Vector2(x, LANE_X_Y), text, _fit_size(text, READY_SIZE, BAR_WIDTH), align, BAR_WIDTH, color)


## Largest font size up to `size` at which `text` fits in `width`.
func _fit_size(text: String, size: int, width: float) -> int:
	while size > 11 and _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	return size


## Bubbles above the speakers' heads: kept on screen, and the second one moved
## up when the two would overlap. A tail points at the speaker.
func _draw_speech() -> void:
	var placed: Array[Rect2] = []
	for side in [0, 1]:
		if not _speech.has(side):
			continue
		var sp: Dictionary = _speech[side]
		var f: Fighter = sp["fighter"]
		if not is_instance_valid(f):
			continue
		var text: String = sp["text"]
		var head := _speech_anchor(f)
		var size := _speech_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SPEECH_FONT_SIZE)
		var w := size.x + 28.0
		var h := size.y + 16.0
		var rect := Rect2(head.x - w * 0.5, head.y - h - 16.0, w, h)
		rect.position.x = clampf(rect.position.x, 8.0, SCREEN_W - w - 8.0)
		rect.position.y = maxf(rect.position.y, 96.0)
		for other in placed:
			if rect.intersects(other.grow(6.0)):
				rect.position.y = other.position.y - h - 12.0
		# Never over the result headline / countdown in the middle of the screen.
		var middle := Rect2(0.0, HEADLINE_Y - 80.0, SCREEN_W, 130.0)
		if (_headline != "" or _count_text != "") and rect.intersects(middle):
			rect.position.y = middle.position.y - h - 8.0
		placed.append(rect)
		var pop := smoothstep(0.0, SPEECH_POP_TIME, sp["age"])
		var c := rect.get_center()
		var shown := Rect2(c - rect.size * 0.5 * (0.7 + 0.3 * pop), rect.size * (0.7 + 0.3 * pop))
		var tail_x := clampf(head.x, shown.position.x + 14.0, shown.end.x - 14.0)
		var tail := PackedVector2Array([Vector2(tail_x - 8.0, shown.end.y - 1.0), Vector2(tail_x + 8.0, shown.end.y - 1.0),
			Vector2(lerpf(tail_x, head.x, 0.5), shown.end.y + 13.0)])
		var box := StyleBoxFlat.new()
		box.bg_color = Color(1.0, 0.99, 0.95, pop)
		box.border_color = Color(0.1, 0.08, 0.08, pop)
		box.set_border_width_all(2)
		box.set_corner_radius_all(12)
		_canvas.draw_colored_polygon(tail, Color(0.1, 0.08, 0.08, pop))
		_canvas.draw_style_box(box, shown)
		var inner := PackedVector2Array([tail[0] + Vector2(2.5, -1.0), tail[1] + Vector2(-2.5, -1.0), tail[2] + Vector2(0.0, -4.0)])
		_canvas.draw_colored_polygon(inner, Color(1.0, 0.99, 0.95, pop))
		if pop > 0.6:
			_canvas.draw_string(_speech_font, Vector2(shown.position.x + 14.0, shown.position.y + 8.0 + size.y * 0.78), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, SPEECH_FONT_SIZE, Color(0.12, 0.08, 0.06, pop))


## Screen point just above the speaker's drawn head (follows jumps, falls,
## rolls and the knocked-out body), or above a standing head before the body
## has been drawn.
func _speech_anchor(f: Fighter) -> Vector2:
	var v := f.get_node_or_null("Visual") as FighterVisual
	var canvas := f.get_viewport().get_canvas_transform()
	if v != null and v._last_joints.size() > FighterVisual.J_HEAD:
		var head: Vector2 = v._last_joints[FighterVisual.J_HEAD] + (f.global_position - v._last_root)
		return canvas * (head - Vector2(0.0, FighterVisual.HEAD_R + 14.0))
	return canvas * (f.global_position + Vector2(0.0, -200.0))


func _draw_popups() -> void:
	for pop in _popups:
		var t: float = pop["age"] / POPUP_LIFE
		var lane := _lane(int(pop["side"]))
		var align := HORIZONTAL_ALIGNMENT_LEFT if pop["side"] == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		var c: Color = pop["color"]
		c.a = 1.0 - smoothstep(0.6, 1.0, t)
		# Pops in from a little lower and settles on its row (never into the next).
		var y: float = LANE_POPUP_Y + float(pop["slot"]) * LANE_POPUP_STEP + 6.0 * (1.0 - smoothstep(0.0, 0.12, t))
		var text: String = pop["text"]
		_shadow_text(Vector2(lane.position.x, y), text, _fit_size(text, POPUP_SIZE, lane.size.x), align, lane.size.x, c)


func _bar_rect(x: float, ratio: float, mirrored: bool) -> Rect2:
	var w := BAR_WIDTH * clampf(ratio, 0.0, 1.0)
	var left := x + BAR_WIDTH - w if mirrored else x
	return Rect2(left, BAR_Y, w, BAR_HEIGHT)


## Shows the combo the given fighter is *receiving*, under the attacker's bar.
func _draw_combo(victim: Fighter, x: float, align: HorizontalAlignment) -> void:
	if victim.received_combo < 2 or victim.combo_display_frames <= 0:
		return
	var alpha := clampf(victim.combo_display_frames / 20.0, 0.0, 1.0)
	var lane := _lane(0 if align == HORIZONTAL_ALIGNMENT_LEFT else 1)
	_shadow_text(Vector2(lane.position.x, LANE_COMBO_Y), "%d HITS" % victim.received_combo, COMBO_SIZE, align, lane.size.x,
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
