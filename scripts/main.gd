extends Node2D
## Match orchestrator.
##
## Each fixed physics tick (60 Hz) it: reads keyboard input into an Intent,
## asks the AI for its Intent, advances both fighters, resolves pushboxes and
## hits (simultaneously, so trades are fair), then drives hitstop, feedback,
## KO and restart. A lethal hit starts a scripted finisher (FinisherDirector).
## Presentation (FxLayer effects, GameAudio sound, camera, HUD) never affects
## combat.
##
## Match flow (all tick-driven, no timers, so a restart cannot leave stale
## callbacks behind; restarting reloads the scene):
##   STYLE_SELECT choose a martial art (cards + details); the player previews
##                the style's guard and idle live. Confirm -> PRE_MATCH.
##   PRE_MATCH    START MATCH (or CHANGE STYLE). No control yet.
##   STANCE_PREP  both walk to their marks, salute / glare, raise their guard.
##   COUNTDOWN    3, 2, 1 (one second each). Input and AI stay locked.
##   FIGHTING     unlocked for both on the same tick ("FIGHT!").
##   FINISHER     a lethal hit plays a scripted finisher.
##   KO           "K.O." until every knocked-out body has come to rest.
##   RESULT       winner shown with REMATCH (same style; R too) and CHANGE STYLE.
## Styles are locked from START MATCH on: Q does nothing during a match, and the
## fighters only accept moves from their own style (Fighter is the gate).

enum RoundState { STYLE_SELECT, PRE_MATCH, STANCE_PREP, COUNTDOWN, FIGHTING, FINISHER, KO, RESULT }

const FLOOR_Y: float = 560.0
const PLAYER_START_X: float = 440.0
const ENEMY_START_X: float = 840.0
## Pre-match positions: the fighters walk from here to their start marks.
const PLAYER_PRE_X: float = 370.0
const ENEMY_PRE_X: float = 910.0
## STANCE_PREP timeline (ticks): walk in, gesture, raise the guard.
const PREP_GESTURE_TICK: int = 34
const PREP_GUARD_TICK: int = 66
const PREP_TICKS: int = 100
const COUNT_NUMBER_TICKS: int = 60
## Announcer words for the countdown numbers.
const COUNT_WORDS: Array[StringName] = [&"", &"one", &"two", &"three"]
const FIGHT_TEXT_TICKS: int = 45
## "K.O." is shown at least this long, and until the loser is at rest.
const KO_MIN_TICKS: int = 50
## Pre-fight camera: steady, centred and a little closer.
const PREFIGHT_ZOOM: float = 1.12
const PREFIGHT_FOCUS_Y: float = 440.0
const PREFIGHT_BGM_DUCK_DB: float = -10.0
## Camera / presentation.
const FINISHER_ZOOM: float = 1.3
## Cinematic finisher camera: pushes in from FIN_ZOOM_START to FIN_ZOOM_END
## through the build-up, slams to FIN_ZOOM_KO on the knockout blow for
## FIN_KO_HOLD ticks with a tilt, then follows the flying body out.
const FIN_ZOOM_START: float = 1.1
const FIN_ZOOM_END: float = 1.2
const FIN_ZOOM_KO: float = 1.3
const FIN_KO_HOLD: int = 16
const FIN_TILT: float = 0.06
const FIN_FOCUS_Y: float = -118.0
const FIN_CAMERA_RATE: float = 7.0
const CAMERA_FOLLOW_RATE: float = 4.0
const CAMERA_PUNCH_DECAY: float = 9.0
const SLOWMO_SCALE: float = 0.3
const SLOWMO_TICKS: int = 28
## Fight camera: frames both fighters, zoom = K / (gap + C) clamped to
## [1, FIGHT_ZOOM_MAX], so it closes in during exchanges and widens as they
## separate. The floor sits FIGHT_FLOOR_FRAME of the half-height below centre;
## a jump lifts the frame and widens it a little. Zoom 1.46 at a 300 px gap
## (fighters ~40% of the screen height), 1.0 only from a 900 px gap.
const FIGHT_ZOOM_K: float = 1900.0
const FIGHT_ZOOM_C: float = 1000.0
const FIGHT_ZOOM_MAX: float = 1.6
const FIGHT_ZOOM_RATE: float = 2.5
const FIGHT_FLOOR_FRAME: float = 0.56
const FIGHT_AIR_ZOOM_OUT: float = 0.0015
const FIGHT_AIR_LIFT: float = 0.45
## Directional camera kick on hits (px per point of damage, decay rate).
const CAMERA_KICK_PER_DAMAGE: float = 0.7
const CAMERA_KICK_DECAY: float = 12.0
## Short slow-motion beats on skill moments (ticks, time scale).
const SLOWMO_PARRY := Vector2(6.0, 0.4)
const SLOWMO_PERFECT_DODGE := Vector2(6.0, 0.45)
const SLOWMO_COUNTER := Vector2(4.0, 0.5)
const SLOWMO_GUARD_BREAK := Vector2(8.0, 0.35)
const SLOWMO_DIZZY := Vector2(6.0, 0.45)
## Dizzy birdsong repeats this often (ticks) while a fighter is stunned.
const DIZZY_CHIRP_TICKS: int = 40
const DIZZY_COLOR := Color(1.0, 0.86, 0.3)
## Speech bubbles (styles with MartialArtStyle.quotes): one bubble per fighter,
## shown SPEECH_TICKS (the victory line longer). A line only replaces a
## showing one of lower priority; after a bubble the fighter stays quiet for
## SPEECH_COOLDOWN ticks (except for priority >= SPEECH_URGENT). Each event
## fires once per game event (never per hit-detection frame).
const SPEECH_TICKS: int = 80
const SPEECH_VICTORY_TICKS: int = 200
const SPEECH_COOLDOWN: int = 45
const SPEECH_URGENT: int = 4
## The same everyday line (hurt, block, slap, miss) is not said again by the
## same fighter within this many ticks.
const SPEECH_LINE_COOLDOWN: int = 300
const SPEECH_PRIORITY: Dictionary = {"hurt": 1, "block": 1, "slap": 2, "miss_heavy": 2, "match_start": 3,
	"low_health": 4, "finisher": 5, "victory": 5, "knocked_out": 6}
## Moves whose whiff makes the fighter speak (big committal swings).
const SPEECH_MISS_MOVES: Array[StringName] = [&"hammer_fist", &"thrust_kick", &"flying_chest_kick", &"belly_bomb",
	&"jor_dhakka"]
const SPEECH_SLAPS: Array[StringName] = [&"light_slap", &"flying_slap"]
## Low-health line below this fraction of max health (once per match).
const SPEECH_LOW_HEALTH: float = 0.25
## Result shot: zoom range and camera centre height (floor ~150 px below centre).
const RESULT_ZOOM_MIN: float = 0.9
const RESULT_ZOOM_MAX: float = 1.1
const RESULT_FOCUS_Y: float = 400.0
const VIEW_MIN := Vector2(-200.0, -200.0)
const VIEW_MAX := Vector2(1480.0, 920.0)
const HIT_COLOR := Color(1.0, 0.9, 0.6)
const BLOCK_COLOR := Color(0.6, 0.8, 1.0)
const PARRY_COLOR := Color(0.75, 0.95, 1.0)
const KO_COLOR := Color(1.0, 0.55, 0.4)
const WOOD_COLOR := Color(0.5, 0.38, 0.27)
const STONE_COLOR := Color(0.42, 0.36, 0.3)
## Pillar wood (face and body), for chunks knocked off it.
const PILLAR_LIGHT := Color(0.42, 0.33, 0.25)
const PILLAR_DARK := Color(0.16, 0.12, 0.1)
## Raw splintered wood (inside the pillar / under the floorboards).
const RAW_WOOD := Color(0.62, 0.48, 0.33)
const FLOOR_WOOD := Color(0.52, 0.4, 0.28)
const WIND_COLOR := Color(0.95, 0.95, 1.0)

@onready var player: Fighter = $Player
@onready var enemy: Fighter = $Enemy
@onready var enemy_ai: EnemyAI = $EnemyAI
@onready var hud: Hud = $HUD
@onready var overlay: Node2D = $Overlay
@onready var camera: Camera2D = $Camera2D
@onready var fx: FxLayer = $Effects
@onready var audio: GameAudio = $Audio

var _round_state: RoundState = RoundState.STYLE_SELECT
## Ticks since the round state last changed.
var _state_tick: int = 0
var _tick: int = 0
var _hitstop: int = 0
var _result_text: String = ""
var _shake_frames: int = 0
var _shake_total: int = 1
var _shake_strength: float = 0.0
var _camera_punch: float = 0.0
var _camera_kick := Vector2.ZERO
var _shake_offset := Vector2.ZERO
var _debug_visible: bool = false
var _last_event: String = "-"
var _fx_rng := RandomNumberGenerator.new()
var _finisher_rng := RandomNumberGenerator.new()
var _arena_rng := RandomNumberGenerator.new()
var _finisher: FinisherDirector = null
## The finisher's event this tick ({} if none; tests read it).
var _last_finisher_event: Dictionary = {}
## Health each fighter starts every round with (Fighter's own default is the
## unit-test 100): sets the round length, ~30 s.
const MATCH_HEALTH: int = 200
## Rounds a fighter must win to take the match (best of 3). Each round ends in
## a finisher; the next starts with "ROUND 2" / "FINAL ROUND", then FIGHT.
## Tests that cover a single K.O. set this to 1.
var rounds_to_win: int = 2
## Rounds won [player, rival], and the round being fought (1-based).
var round_wins: Array[int] = [0, 0]
var round_number: int = 1
## The round's opening call ("ROUND 2") is showing instead of the 3-2-1.
var _round_call: bool = false
## The match is decided (the KO screen leads to the result, not a new round).
var _match_over: bool = false
## Ticks the round call shows before FIGHT.
const ROUND_CALL_TICKS: int = 80
var _follow_victim: bool = false
## Where the knockout blow landed (world), for the KO shot.
var _ko_focus := Vector2.INF
## The next camera update hard-cuts to the knockout shot (no easing).
var _ko_cut: bool = false
var _slowmo_ticks: int = 0
# Double-tap detection for dodges: tick of the last A / D tap.
var _last_tap := {-1: -1000, 1: -1000}
var _block_was_held: bool = false
# Speech: fighter -> {"event", "text", "prio", "ticks", "quiet"}; who already
# said the low-health line; each fighter's swing being watched for a whiff.
var _speech: Dictionary = {}
var _low_health_said: Dictionary = {}
var _watched_swing: Dictionary = {}
var _ko_said: Dictionary = {}
## The match is paused (P / Esc / the pause button).
var match_paused: bool = false
var _pause_message: Array = ["", ""]
# Finisher ambience: where the wall was last hit (dust keeps trickling from the
# cracks), whether the attacker was airborne last tick (takeoff dust), and the
# last x of each skidding body (floor scuff marks).
var _wall_dent := Vector2.INF
## Arena is selected once for a new match and retained between rounds.
var stage = null  # WestBengalStage or StyleStage; presentation interface below.
## Optional deterministic arena selection for capture/tests; empty means random.
var match_arena_override: StringName = &""
var _match_arena: StringName = &""
const DECALS_WOOD: String = "res://assets/art/decals/dojo_wood_v2"
const DECALS_STONE: String = "res://assets/art/decals/west_bengal_v1"
const STONE_LIGHT := Color(0.7, 0.66, 0.6)
const STONE_DARK := Color(0.42, 0.4, 0.37)
const PLASTER_LIGHT := Color(0.86, 0.8, 0.66)
const PLASTER_DARK := Color(0.55, 0.5, 0.42)
## Effects held back a few game ticks (hitstop does not count), so a knockout
## blow's own contact reads before what it sets off: [ticks left, Callable].
var _fx_queue: Array = []
## Ticks a final blow's wall impact follows the blow itself.
const FINAL_WALL_FX_DELAY: int = 4
var _fin_attacker_air: bool = false
var _skid_prev_x: Dictionary = {}
## Developer overlay: recent contact points {pos, age, gap} (gap = distance from
## the drawn fist / foot to the contact point at impact, -1 if unknown).
var _contacts: Array[Dictionary] = []
const CONTACT_SHOW_TICKS: int = 45
var _stance_rng := RandomNumberGenerator.new()
## Name of the finisher played this round ("" if none). Read by tests/HUD.
var last_finisher_name: String = ""
## Training ground (null in a normal match). See TrainingMode.
var training: TrainingMode = null


func _ready() -> void:
	# Saved settings (the audio node, a child, set up its buses before this).
	GameSettings.load_once()
	GameSettings.apply_audio()
	GameSettings.apply_display()
	GameSettings.apply_controls()
	_fx_rng.seed = 7
	# Which finisher plays is presentation, not combat: vary it every match.
	_finisher_rng.randomize()
	_arena_rng.randomize()
	set_game_speed(1.0)
	# The camera is moved in _process, so it must not be physics-interpolated.
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.ignore_rotation = false  # the finisher's knockout shot tilts
	player.position = Vector2(PLAYER_PRE_X, FLOOR_Y)
	enemy.position = Vector2(ENEMY_PRE_X, FLOOR_Y)
	player.ground_y = FLOOR_Y
	enemy.ground_y = FLOOR_Y
	player.opponent = enemy
	enemy.opponent = player
	for f: Fighter in [player, enemy]:
		f.max_health = MATCH_HEALTH
		f.health = MATCH_HEALTH
	player.face_opponent()
	enemy.face_opponent()
	# Positions were set directly: don't interpolate from the scene defaults.
	player.reset_physics_interpolation()
	enemy.reset_physics_interpolation()
	for f: Fighter in [player, enemy]:
		f.jumped.connect(_on_fighter_jumped)
		f.landed.connect(_on_fighter_landed)
		f.attack_started.connect(_on_attack_started)
		f.wall_hit.connect(_on_fighter_wall_hit)
		f.rolled.connect(_on_fighter_rolled)
		f.dodged.connect(_on_fighter_dodged)
		f.perfect_evaded.connect(_on_fighter_perfect_evaded)
		f.posture_broken.connect(_on_fighter_posture_broken)
		f.dizzied.connect(_on_fighter_dizzied)
		f.dizzy_recovered.connect(_on_fighter_dizzy_recovered)
		f.signature_started.connect(_on_signature_started)
		f.parried.connect(_on_fighter_parried)
	fx.decals_changed.connect(queue_redraw)
	# Painted stage art is drawn scaled down: smooth it with mipmaps.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	fx.decal_set = _load_stage_decals(DECALS_WOOD)
	# Pause: this node and the HUD keep running (input, the pause screen); the
	# fighters and effects freeze with the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	for node: Node in [player, enemy, fx]:
		node.process_mode = Node.PROCESS_MODE_PAUSABLE
	hud.pause_pressed.connect(toggle_pause)
	fx.floor_y = FLOOR_Y
	# Martial arts: the player's choice persists across restarts; the rival
	# gets a different style.
	_stance_rng.randomize()
	player.set_style(StyleRegistry.player_style())
	enemy.set_style(StyleRegistry.random_except(player.style.id, _stance_rng))
	enemy_ai.difficulty = EnemyAI.selected_difficulty
	enemy_ai.setup(enemy, player)
	hud.setup(player, enemy)
	hud.difficulty_pressed.connect(cycle_difficulty)
	hud.start_pressed.connect(start_match)
	hud.restart_pressed.connect(restart_match)
	hud.change_style_pressed.connect(change_style)
	hud.style_chosen.connect(select_style)
	hud.style_confirmed.connect(confirm_style)
	hud.training_pressed.connect(start_training)
	hud.tutorial_pressed.connect(start_tutorial)
	hud.training_action.connect(training_action)
	overlay.draw.connect(_draw_overlay)
	_enter_pre_match()


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_debug"):
		_debug_visible = not _debug_visible
	if training != null and get_tree().paused:
		# Paused training: everything is frozen; keep the readouts live.
		_refresh_presentation()
		return
	if match_paused:
		# Paused match: nothing advances; R still restarts.
		if Input.is_action_just_pressed("restart"):
			toggle_pause()
			restart_match()
		return
	if Input.is_action_just_pressed("restart"):
		if training != null:
			training_action(&"reset")
		else:
			restart_match()
		return
	if Input.is_action_just_pressed("cycle_stance") and _round_state == RoundState.STYLE_SELECT:
		_cycle_style_choice()

	_tick += 1
	_state_tick += 1
	_update_shake()
	# May unlock the fight this tick, before either side reads its controls.
	_tick_match_flow()
	_tick_dizzy_audio()
	_tick_celebration()
	_tick_speech()

	var fighting := _round_state == RoundState.FIGHTING
	# Player input is buffered even during hitstop so combos feel responsive.
	player.push_intent(_read_player_intent() if fighting else _prefight_intent(player, PLAYER_START_X))

	if _hitstop > 0:
		_hitstop -= 1
	elif _round_state == RoundState.FINISHER:
		var event := _finisher.tick()
		_last_finisher_event = event
		player.tick()
		enemy.tick()
		# Shared cinematic speed: every finisher plays at its beats' speeds.
		set_game_speed(_finisher.playback_speed() * _base_time_scale())
		_finisher_feedback(event)
		_finisher_ambient()
		if _finisher.done:
			_end_round()
	else:
		if fighting and training != null and training.dummy_mode != TrainingMode.Dummy.CPU:
			enemy.push_intent(training.dummy_intent())
		else:
			enemy.push_intent(enemy_ai.compute_intent() if fighting else _prefight_intent(enemy, ENEMY_START_X))
		player.tick()
		enemy.tick()
		_resolve_pushboxes()
		if _round_state == RoundState.FIGHTING:
			_resolve_hits()
		elif _round_state == RoundState.KO:
			_tick_round_over()
	_tick_slowmo()
	_tick_fx_queue()
	if training != null and _round_state == RoundState.FIGHTING:
		training.after_tick()
	_trail_rolling_dust()
	for c in _contacts:
		c["age"] += 1
	while not _contacts.is_empty() and _contacts[0]["age"] > CONTACT_SHOW_TICKS:
		_contacts.pop_front()

	player.hitstop_frames = _hitstop
	enemy.hitstop_frames = _hitstop
	# Whoever is striking is drawn in front, so the strike reads at impact.
	for f: Fighter in [player, enemy]:
		f.z_index = 1 if f.state == Fighter.State.ATTACK or f.state == Fighter.State.FINISHER else 0
	_refresh_presentation()


# --- Training ground --------------------------------------------------------------

## TRAINING (or T) from the pre-match screen: the fight starts at once against
## a dummy that never goes down. See TrainingMode for what it offers.
func start_training() -> void:
	if _round_state == RoundState.STYLE_SELECT:
		confirm_style()
	if _round_state != RoundState.PRE_MATCH or training != null:
		return
	training = TrainingMode.new()
	training.name = "Training"
	add_child(training)
	training.setup(player, enemy)
	_apply_stage()  # training is always the dojo
	# Keep reading input and drawing while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.show_button(&"")
	hud.show_training(true)
	hud.set_move_list(_move_list_text())
	start_match(true)
	hud.set_countdown("TRAINING")


## TUTORIAL (or U) from the pre-match screen: the training ground with the
## beginner tutorial on top (Tutorial); the developer panels stay hidden.
func start_tutorial() -> void:
	start_training()
	if training == null:
		return
	training.infinite_focus = false
	training.tutorial = Tutorial.new(player, enemy)
	hud.show_training(false)
	hud.set_countdown("TUTORIAL")


func _move_list_text() -> String:
	var lines := PackedStringArray(["[b]%s MOVES[/b]" % player.style.display_name.to_upper()])
	for row in player.style.move_list():
		lines.append("[color=#f2c14e]%s[/color]  %s" % [row[0], row[1]])
	if player.style.id == &"capoeira":
		lines.append("%s/%s + %s: rolling crossover jump. %s/%s/%s stun; %s knocks down." % [GameSettings.key_label(&"move_left"),
			GameSettings.key_label(&"move_right"), GameSettings.key_label(&"jump"), MartialArtStyle.slot_key(&"technique"), MartialArtStyle.slot_key(&"heavy"),
			MartialArtStyle.slot_key(&"up_heavy"), MartialArtStyle.slot_key(&"down_heavy")])
	elif player.style.id == &"jeet_kune_do":
		lines.append("%s: jab-cross. %s: hammerfist. %s stuns on hit and breaks guard on block." % [
			MartialArtStyle.slot_key(&"light"), MartialArtStyle.slot_key(&"heavy"), MartialArtStyle.slot_key(&"up_heavy")])
	if player.style.input_map.has(&"x_move"):
		var x_attack := CombatData.get_attack(player.style.resolve(&"x_move", false))
		lines.append("X: %d s cooldown, no Focus. Block, parry or evade." % (x_attack.x_cooldown_frames / CombatData.TICK_RATE))
	if player.style.signature != &"":
		lines.append("[color=#f2c14e]F[/color]  %s (full Focus)" % CombatData.get_attack(
			CombatData.type_for_id(player.style.signature)).display_name)
	return "\n".join(lines)


func training_action(action: StringName) -> void:
	if training == null:
		return
	var fighting := _round_state == RoundState.FIGHTING and _finisher == null
	match action:
		&"dummy":
			training.cycle_dummy()
			enemy.stop_combat()
			enemy_ai.setup(enemy, player)
		&"dummy_style":
			var styles := StyleRegistry.all()
			var i := styles.find(enemy.style)
			enemy.set_style(styles[(i + 1) % styles.size()])
			enemy_ai.setup(enemy, player)
		&"speed":
			training.cycle_speed()
			if _slowmo_ticks <= 0:
				set_game_speed(training.speed())
		&"focus":
			training.infinite_focus = not training.infinite_focus
		&"next_finisher":
			training.cycle_finisher()
		&"play_finisher":
			if fighting and not get_tree().paused:
				_training_finisher(training.current_finisher())
		&"pause":
			training.toggle_pause()
		&"step":
			training.step()
		&"hitboxes":
			_debug_visible = not _debug_visible
		&"reset":
			if not get_tree().paused:
				_reset_training()
		&"panels":
			hud.toggle_training_panels()
		&"exit":
			_exit_training()
		&"lesson_skip":
			if training.tutorial != null:
				training.tutorial.skip()
		&"lesson_replay":
			if training.tutorial != null and not get_tree().paused:
				_reset_training()
				training.tutorial.restart()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if training == null:
		if key.physical_keycode == KEY_T and _round_state == RoundState.PRE_MATCH:
			start_training()
		elif key.physical_keycode == KEY_G and _round_state == RoundState.PRE_MATCH:
			cycle_difficulty()
		elif key.physical_keycode == KEY_U and _round_state == RoundState.PRE_MATCH:
			start_tutorial()
		elif key.physical_keycode == KEY_O and hud.is_settings_button_visible():
			hud.toggle_settings()
			get_viewport().set_input_as_handled()
		elif key.physical_keycode in [KEY_P, KEY_ESCAPE] and (match_paused or can_pause()):
			toggle_pause()
			get_viewport().set_input_as_handled()
		return
	var action: StringName = {
		KEY_1: &"dummy", KEY_2: &"dummy_style", KEY_3: &"speed", KEY_4: &"focus", KEY_5: &"next_finisher",
		KEY_6: &"play_finisher", KEY_P: &"pause", KEY_PERIOD: &"step", KEY_H: &"panels", KEY_ESCAPE: &"exit",
		KEY_N: &"lesson_skip", KEY_U: &"lesson_replay",
	}.get(key.physical_keycode, &"")
	if action != &"":
		training_action(action)
		get_viewport().set_input_as_handled()


# --- Pause (matches; training has its own) -------------------------------------

func _update_pause_button() -> void:
	hud.show_pause_button(can_pause())


## A match can be paused from the countdown to the end of the K.O.
func can_pause() -> bool:
	return training == null and _round_state in [RoundState.STANCE_PREP, RoundState.COUNTDOWN, RoundState.FIGHTING,
		RoundState.FINISHER, RoundState.KO]


## P / Esc / the pause button: freezes the whole match (fighters, effects,
## timers, slow motion); the HUD keeps drawing the pause screen.
func toggle_pause() -> void:
	if not match_paused and not can_pause():
		return
	match_paused = not match_paused
	get_tree().paused = match_paused
	if match_paused:
		_pause_message = hud.get_message()
		hud.set_message("PAUSED", "P / ESC resume  ·  R restart")
		audio.duck_bgm(-12.0)
	else:
		hud.set_message(_pause_message[0], _pause_message[1])
		audio.duck_bgm(-14.0 if _round_state == RoundState.FINISHER else 0.0)
	hud.set_paused(match_paused)


## Plays a finisher on the dummy right away (Wall Crush at the wall, Air Smash
## in the air); training then puts both back on their marks.
func _training_finisher(kind: FinisherDirector.Kind) -> void:
	for f: Fighter in [player, enemy]:
		f.stop_combat()
		f.velocity_x = 0.0
	if kind in FinisherDirector.WALL_KINDS:
		enemy.position.x = Fighter.ARENA_MAX_X - 110.0
	else:
		enemy.position.x = clampf(enemy.position.x, Fighter.ARENA_MIN_X + 200.0, Fighter.ARENA_MAX_X - 200.0)
	player.position.x = enemy.position.x - 90.0
	for f: Fighter in [player, enemy]:
		f.face_opponent()
		f.reset_physics_interpolation()
	if kind in FinisherDirector.AIR_KINDS:
		enemy.scripted_launch(-6.0)
	enemy.health = 0
	_start_finisher(player, enemy, kind)


## Both fighters back on their marks, fresh, ready to go again.
func _reset_training() -> void:
	_fx_queue.clear()
	if stage != null:
		stage.reset_props()
	_finisher = null
	_follow_victim = false
	_ko_focus = Vector2.INF
	_hitstop = 0
	_slowmo_ticks = 0
	set_game_speed(_base_time_scale())
	hud.set_banner("", Color.WHITE)
	hud.set_letterbox(false)
	hud.set_message("", "")
	audio.duck_bgm(0.0)
	_reset_fighters(1)
	_set_round_state(RoundState.FIGHTING)
	enemy_ai.setup(enemy, player)
	for f: Fighter in [player, enemy]:
		say(f, "match_start")


## Both fighters up, full health, back on their start marks (focus is kept).
func _reset_fighters(min_hp: int) -> void:
	for f: Fighter in [player, enemy]:
		f.stop_combat()
		f.end_scripted()
		f.airborne = false
		f.rolling = false
		f.skidding = false
		f.settling = false
		f.celebration = &""
		f.dizzy_left = 0
		f.dizzy_immunity = 0
		f.spiked = false
		f.jump_vx = 0.0
		f.velocity_x = 0.0
		f.velocity_y = 0.0
		f.position.y = FLOOR_Y
		f.health = f.max_health
		f.posture = 0.0
		f.min_health = min_hp
		f.call("_enter_state", Fighter.State.IDLE)
	player.position.x = PLAYER_START_X
	enemy.position.x = ENEMY_START_X
	for f: Fighter in [player, enemy]:
		f.face_opponent()
		f.reset_physics_interpolation()


## Back to the pre-match screen with the same style (START, TRAINING, CHANGE STYLE).
func _exit_training() -> void:
	training.unpause()
	StyleRegistry.skip_selection = true
	set_game_speed(1.0)
	get_tree().reload_current_scene()


# --- Match flow -----------------------------------------------------------------

func _set_round_state(new_state: RoundState) -> void:
	call_deferred("_update_pause_button")
	_round_state = new_state
	_state_tick = 0
	# Music follows the PLAYER: the menu theme while choosing, then the chosen
	# style's own track for the match (the rival's style never changes it).
	if new_state == RoundState.STYLE_SELECT:
		audio.set_music(&"menu")
	elif player.style != null:
		audio.set_music(player.style.id)


func get_round_state_name() -> String:
	return RoundState.keys()[_round_state]


func _enter_pre_match() -> void:
	for f: Fighter in [player, enemy]:
		f.prefight_pose = &"relaxed"
	audio.duck_bgm(PREFIGHT_BGM_DUCK_DB)
	if StyleRegistry.skip_selection:
		# Rematch: same style, straight to START MATCH.
		StyleRegistry.skip_selection = false
		_show_ready()
		return
	_set_round_state(RoundState.STYLE_SELECT)
	_apply_stage()
	# Preview the style live: the player stands in its guard with its idle.
	player.prefight_pose = &""
	hud.set_message("", "")
	hud.show_style_select(StyleRegistry.all(), player.style.id)


## STYLE_SELECT: preview another style (cards, Q).
func select_style(style_id: StringName) -> void:
	if _round_state != RoundState.STYLE_SELECT:
		return  # locked once the match is set up
	var chosen := StyleRegistry.by_id(style_id)
	if chosen == null:
		return
	player.set_style(chosen)
	StyleRegistry.player_choice = chosen.id
	if enemy.style == null or enemy.style.id == chosen.id:
		enemy.set_style(StyleRegistry.random_except(chosen.id, _stance_rng))
	hud.show_style_select(StyleRegistry.all(), chosen.id)


func _cycle_style_choice() -> void:
	var styles := StyleRegistry.all()
	var i := styles.find(player.style)
	select_style(styles[(i + 1) % styles.size()].id)


## Confirm the previewed style -> PRE_MATCH.
func confirm_style() -> void:
	if _round_state != RoundState.STYLE_SELECT:
		return
	StyleRegistry.player_choice = player.style.id
	_show_ready()


## Home arena plus three shared streets. The rival never chooses the arena.
## A single draw at confirmation keeps scenery and damage stable across rounds.
func arena_choices() -> Array[StringName]:
	var home: StringName = player.style.id if player.style != null else &"karate"
	var choices: Array[StringName] = [home]
	choices.append_array(StyleStage.SHARED_STREETS)
	return choices

func _pick_match_arena() -> void:
	if _match_arena != &"": return
	var choices := arena_choices()
	_match_arena = match_arena_override if match_arena_override in choices else choices[_arena_rng.randi_range(0, choices.size() - 1)]

func _apply_stage() -> void:
	var practice := training != null or _round_state == RoundState.STYLE_SELECT or player.style == null
	if not practice: _pick_match_arena()
	var wanted: StringName = &"karate" if practice else _match_arena
	var same: bool = (stage is WestBengalStage and wanted == &"bangla_maar") or (stage is StyleStage and stage.style_id == wanted)
	if same: return  # Keep art, props and variant fixed throughout the match.
	if stage != null:
		remove_child(stage)
		stage.queue_free()
		stage = null
	if wanted == &"bangla_maar":
		stage = WestBengalStage.new()
		stage.setup(&"howrah" if _arena_rng.randf() < 0.5 else &"victoria", FLOOR_Y)
		fx.decal_set = FxLayer.load_decal_set(DECALS_STONE)
	else:
		stage = StyleStage.new()
		stage.setup(wanted, FLOOR_Y)
		fx.decal_set = _load_stage_decals(stage.decal_directory())
	stage.name = "Stage"
	stage.on_prop_broken = _on_prop_broken
	add_child(stage)
	move_child(stage, 0)  # under the fighters (later children draw on top)
	queue_redraw()


## Missing art during development uses procedural damage. Superseded asset
## versions are not retained as silent fallbacks; final checks require art.
func _load_stage_decals(folder: String) -> Dictionary:
	if not ResourceLoader.exists(folder + "/floor_impact_01.png"):
		return {}
	return FxLayer.load_decal_set(folder)


func get_stage_name() -> String:
	if stage is WestBengalStage: return "west_bengal_%s" % stage.variant
	return stage.get_stage_name() if stage is StyleStage else "dojo"


## A stage prop broke: its material flies, a crack of wood or clay.
func _on_prop_broken(p: Dictionary) -> void:
	var r: Rect2 = p["rect"]
	var col: Color = p.get("color", WestBengalStage.prop_color(p["id"]))
	fx.chunks(r.get_center(), 8, col, 6.0, 0.0, 0.9, 3.0, 7.0)
	fx.dust_cloud(Vector2(r.get_center().x, FLOOR_Y), 0.7, 35, 6)
	audio.play(&"guard_break" if p["id"] in [&"cups", &"pot"] else &"wall_hit", -8.0)
	queue_redraw()


func _show_ready() -> void:
	_set_round_state(RoundState.PRE_MATCH)
	_apply_stage()
	hud.hide_style_select()
	player.prefight_pose = &"relaxed"
	hud.set_message("%s  vs  %s" % [player.style.display_name.to_upper(), enemy.style.display_name.to_upper()],
		"ENTER or click to start")
	hud.show_button(&"start")


## AI button / G before the match: the rival's next difficulty (Easy, Normal,
## Hard, round again). Kept for rematches and later matches.
func cycle_difficulty() -> void:
	if _round_state != RoundState.PRE_MATCH:
		return
	var levels := EnemyAI.DIFFICULTIES
	EnemyAI.selected_difficulty = levels[(levels.find(EnemyAI.selected_difficulty) + 1) % levels.size()]
	enemy_ai.difficulty = EnemyAI.selected_difficulty
	hud.set_difficulty(EnemyAI.selected_difficulty)


## CHANGE STYLE (pre-match or after a match): back to the style screen.
func change_style() -> void:
	if _round_state == RoundState.PRE_MATCH:
		_set_round_state(RoundState.STYLE_SELECT)
		_match_arena = &""
		_apply_stage()
		hud.show_button(&"")
		hud.set_message("", "")
		player.prefight_pose = &""
		hud.show_style_select(StyleRegistry.all(), player.style.id)
	elif _round_state == RoundState.RESULT:
		StyleRegistry.skip_selection = false
		set_game_speed(1.0)
		get_tree().reload_current_scene()


## START MATCH. Only acts once, from PRE_MATCH (or STYLE_SELECT, which then
## confirms the previewed style). `skip_intro` jumps straight to the fight
## (tests). From here on the styles are locked.
func start_match(skip_intro: bool = false) -> void:
	if _round_state == RoundState.STYLE_SELECT:
		confirm_style()
	if _round_state != RoundState.PRE_MATCH:
		return
	hud.show_button(&"")
	hud.set_message("", "")
	if skip_intro:
		player.position.x = PLAYER_START_X
		enemy.position.x = ENEMY_START_X
		for f: Fighter in [player, enemy]:
			f.face_opponent()
			f.reset_physics_interpolation()
		_begin_fight()
		return
	_set_round_state(RoundState.STANCE_PREP)


## Restart / REMATCH: a fresh match with the same styles, straight to START
## MATCH. The scene reload resets health, posture, AI, effects, animation and
## any countdown in progress.
func restart_match() -> void:
	StyleRegistry.player_choice = player.style.id if player.style != null else StyleRegistry.player_choice
	StyleRegistry.skip_selection = true
	set_game_speed(1.0)
	get_tree().reload_current_scene()


func _tick_match_flow() -> void:
	match _round_state:
		RoundState.STANCE_PREP:
			# Walk in relaxed, gesture, then raise the stance guard.
			if _state_tick == PREP_GESTURE_TICK:
				player.prefight_pose = _intro_pose(player, &"salute")
				enemy.prefight_pose = _intro_pose(enemy, &"glare")
			elif _state_tick == PREP_GUARD_TICK:
				# Styles with their own ready pose hold it until they first act.
				for f: Fighter in [player, enemy]:
					f.prefight_pose = _intro_pose(f, &"")
			elif _state_tick >= PREP_TICKS:
				_set_round_state(RoundState.COUNTDOWN)
				_show_count(3)
		RoundState.COUNTDOWN:
			if _round_call:
				if _state_tick >= ROUND_CALL_TICKS:
					_round_call = false
					audio.announce(&"fight")
					_begin_fight()
			elif _state_tick % COUNT_NUMBER_TICKS == 0:
				var left := 3 - _state_tick / COUNT_NUMBER_TICKS
				if left > 0:
					_show_count(left)
				else:
					audio.announce(&"fight")  # the countdown's FIGHT (training starts silently)
					_begin_fight()
		RoundState.FIGHTING:
			if _state_tick == FIGHT_TEXT_TICKS:
				hud.set_countdown("")
			for f: Fighter in [player, enemy]:
				if f.prefight_pose != &"" and f.state != Fighter.State.IDLE:
					f.prefight_pose = &""


## The style's own pre-fight gesture, or the shared one.
static func _intro_pose(f: Fighter, fallback: StringName) -> StringName:
	# The acrobatic intro lands before the countdown unlocks combat.
	if f.style != null and f.style.id == &"capoeira" and fallback == &"":
		return &""
	return f.style.intro_pose if f.style != null and f.style.intro_pose != &"" else fallback


func _show_count(n: int) -> void:
	audio.announce(COUNT_WORDS[n])
	hud.set_countdown(str(n))
	audio.play(&"count_tick", 0.0, 0.0)


## Unlocks both fighters on the same tick: the player's controls and the AI
## both start reading this tick (the AI is re-seeded, so it gets no head start).
func _begin_fight() -> void:
	_set_round_state(RoundState.FIGHTING)
	for f: Fighter in [player, enemy]:
		f.prefight_pose = _intro_pose(f, &"")
		f.stop_combat()
		say(f, "match_start")
	enemy_ai.setup(enemy, player)
	hud.set_rounds(round_wins, rounds_to_win if training == null else 0)
	hud.set_countdown("FIGHT!")
	hud.flash(0.25)
	audio.play(&"fight_call", 0.0, 0.0)
	audio.duck_bgm(0.0)


## Before the fight: walk to the start mark (real walking, so the feet step),
## otherwise stand still. Never attacks, blocks or jumps.
func _prefight_intent(f: Fighter, mark_x: float) -> CombatData.Intent:
	var intent := CombatData.Intent.new()
	if _round_state != RoundState.STANCE_PREP:
		return intent
	var dx := mark_x - f.position.x
	if absf(dx) > f.walk_speed:
		intent.move = 1 if dx > 0.0 else -1
	elif not is_zero_approx(dx):
		f.position.x = mark_x
	return intent


func _read_player_intent() -> CombatData.Intent:
	var intent := CombatData.Intent.new()
	var axis := Input.get_axis("move_left", "move_right")
	intent.move = 0 if is_zero_approx(axis) else (1 if axis > 0.0 else -1)
	intent.block = Input.is_action_pressed("block")
	# A fresh Shift press is a parry attempt; holding it is a normal block. The
	# press is the held-state edge, so it always lands on the tick the guard rises.
	intent.parry = intent.block and not _block_was_held
	_block_was_held = intent.block
	# S: crouch (S + Shift = low block). S + J / S + K are read below.
	intent.crouch = Input.is_action_pressed("mod_down")
	intent.signature = Input.is_action_just_pressed("signature")
	intent.jump = Input.is_action_just_pressed("jump")
	# Double-tap A or D within the window = dash (dodge) in the tapped screen
	# direction. Only fresh presses count, so holding a key never repeats it,
	# and a dash uses up both taps (a third tap starts a new pair).
	for dir in [-1, 1]:
		if Input.is_action_just_pressed("move_left" if dir < 0 else "move_right"):
			if _tick - _last_tap[dir] <= CombatData.DOUBLE_TAP_WINDOW:
				intent.dodge = dir
				_last_tap[dir] = -1000
			else:
				_last_tap[dir] = _tick
	# Attack buttons produce a slot; the fighter's martial art decides the move
	# (and refuses anything its style does not have).
	intent.slot = attack_slot(Input.is_action_just_pressed("attack_light"),
		Input.is_action_just_pressed("attack_heavy"), Input.is_action_just_pressed("attack_technique"),
		Input.is_action_pressed("mod_up"), Input.is_action_pressed("mod_down"))
	if Input.is_action_just_pressed("x_move"):
		intent.slot = &"x_move"
	return intent


## The input slot for this tick's attack presses. W / S held at the moment J or
## K is pressed pick the variant (W wins if both are held); A / D never do.
## One press per tick: J, then K, then L.
static func attack_slot(j: bool, k: bool, l: bool, up: bool, down: bool) -> StringName:
	if j or k:
		var base := "light" if j else "heavy"
		if up:
			return StringName("up_" + base)
		if down:
			return StringName("down_" + base)
		return StringName(base)
	return &"technique" if l else &""


# --- Combat resolution --------------------------------------------------------

## Bodies keep 2 * PUSH_HALF_WIDTH apart. Exceptions, so movement can cross:
## - a fighter whose feet clear CROSSUP_CLEARANCE passes over the other;
## - a forward roll, or a close-range slip-past dodge, passes through while
##   it moves;
## - a crossing fighter (airborne, just landed, just rolled) is the only one
##   moved, toward the side its centre is on now, smoothly (CROSS_RESOLVE_STEP
##   px per tick): a jump that got past the opponent's centre completes the
##   cross-up, one that did not is eased back. Pinned at a wall, the other
##   fighter is moved instead. Walking fighters split the overlap as before,
##   so walking never passes through.
func _resolve_pushboxes() -> void:
	var min_dist := Fighter.PUSH_HALF_WIDTH * 2.0
	var dx := enemy.position.x - player.position.x
	if absf(dx) >= min_dist or absf(enemy.position.y - player.position.y) > CombatData.CROSSUP_CLEARANCE:
		return
	if player.is_down() or enemy.is_down():
		return
	if player.is_passing_through() or enemy.is_passing_through():
		return
	var p_cross := player.is_crossing()
	if p_cross != enemy.is_crossing():
		var mover := player if p_cross else enemy
		var other := enemy if p_cross else player
		var side := signf(mover.position.x - other.position.x)
		if side == 0.0:
			side = float(mover.dodge_world_dir if mover.state in [Fighter.State.EVADE_ROLL, Fighter.State.DODGE] else -mover.facing)
		var step := minf(min_dist - absf(mover.position.x - other.position.x), CombatData.CROSS_RESOLVE_STEP)
		var before := mover.position.x
		mover.position.x += side * step
		mover.clamp_to_arena()
		var short := step - absf(mover.position.x - before)
		if short > 0.01:
			other.position.x -= side * short
			other.clamp_to_arena()
		return
	var dir: float = signf(dx) if not is_zero_approx(dx) else float(player.facing)
	var overlap := min_dist - absf(dx)
	player.position.x -= dir * overlap * 0.5
	enemy.position.x += dir * overlap * 0.5
	player.clamp_to_arena()
	enemy.clamp_to_arena()
	# If one fighter is pinned against a wall, push the other one instead.
	dx = enemy.position.x - player.position.x
	if absf(dx) < min_dist:
		var rest := min_dist - absf(dx)
		if is_equal_approx(player.position.x, Fighter.ARENA_MIN_X) or is_equal_approx(player.position.x, Fighter.ARENA_MAX_X):
			enemy.position.x += dir * rest
			enemy.clamp_to_arena()
		else:
			player.position.x -= dir * rest
			player.clamp_to_arena()


func _resolve_hits() -> void:
	# Gather every connecting hit first, then apply them all, so neither
	# fighter gets priority on a simultaneous trade.
	var pending: Array[Dictionary] = []
	var fighters: Array[Fighter] = [player, enemy]
	for i in fighters.size():
		var attacker := fighters[i]
		var defender := fighters[1 - i]
		if not attacker.is_hitbox_active():
			continue
		var hitbox := attacker.get_hitbox_world()
		var hurtbox := defender.get_hurtbox_world()
		if not hitbox.intersects(hurtbox):
			continue
		if defender.is_evading():
			# The strike passed through the dodge's i-frames.
			defender.perfect_evade()
			continue
		if not defender.can_be_hit():
			continue
		pending.append({
			"attacker": attacker, "defender": defender,
			"attack": attacker.current_attack, "step": attacker.combo_step,
			"contact": hitbox.intersection(hurtbox).get_center(),
		})

	# Clash: two active strikes meeting in mid-air. Sparks and a sharp clap at
	# the meeting point; nothing else changes (hurtbox hits below still land).
	if Fighter.hitboxes_clash(player, enemy):
		var meet := player.get_hitbox_world().intersection(enemy.get_hitbox_world()).get_center()
		fx.clash(meet)
		audio.play(&"clash", 0.0, 0.05)
		_hitstop = maxi(_hitstop, 4)
		_shake(5, 2.5)

	var killing_attack: CombatData.Attack = null
	for hit: Dictionary in pending:
		var attacker: Fighter = hit["attacker"]
		var defender: Fighter = hit["defender"]
		var attack: CombatData.Attack = hit["attack"]
		var step: int = hit["step"]
		var result := defender.receive_hit(attack, attacker, step)
		# Focus: one award per hit event, only while fighting.
		match result:
			CombatData.HitResult.HIT:
				if not attacker.in_signature:
					attacker.add_focus(CombatData.focus_for_hit(attack, defender.last_hit_counter))
				defender.add_hurt_focus(CombatData.focus_for_hurt(attack.damage))
			CombatData.HitResult.BLOCKED:
				defender.add_block_focus()
		if result == CombatData.HitResult.KO:
			killing_attack = attack
		_speech_on_hit(result, attack, attacker, defender)
		attacker.confirm_hit(result)
		if training != null:
			training.on_hit(result, attacker, defender, attack)
		_hit_feedback(result, attack, step, hit["contact"], defender)
		_record_contact(attacker, hit["contact"])
		_last_event = "%s %s #%d -> %s %s" % [attacker.fighter_name, attack.display_name, step,
			defender.fighter_name, CombatData.HitResult.keys()[result]]

	var player_lost := player.state == Fighter.State.FINISHED
	var enemy_lost := enemy.state == Fighter.State.FINISHED
	if player_lost and enemy_lost:
		# Simultaneous lethal trade: no finisher, both simply drop.
		player.finish_ko(-player.facing, CombatData.KNOCKDOWN_LAUNCH_VELOCITY, CombatData.KNOCKDOWN_DRIFT)
		enemy.finish_ko(-enemy.facing, CombatData.KNOCKDOWN_LAUNCH_VELOCITY, CombatData.KNOCKDOWN_DRIFT)
		_end_round()
	elif player_lost or enemy_lost:
		var victim := player if player_lost else enemy
		var winner := enemy if player_lost else player
		_start_finisher(winner, victim, FinisherDirector.choose(winner, victim, killing_attack, _finisher_rng))


## Layered hit sound: a slap or thud by where it landed, with a bone crack
## on top of heavy blows.
func _hit_sound(tier: int, defender: Fighter, kind: int = CombatData.ImpactKind.STRAIGHT) -> void:
	var head := not defender.last_hit_low and defender.last_hit_high
	var vol: float = [0.0, -3.0, -1.0, 0.0][tier]
	if not head:
		audio.play(&"hit_body", vol)  # dull thud to the ribs / legs
	elif tier == 1:
		audio.play(&"hit_snap", vol)  # jab: short crisp snap
	else:
		match kind:
			CombatData.ImpactKind.HOOK:
				audio.play(&"hit_hook", vol)
			CombatData.ImpactKind.RISING:
				audio.play(&"hit_upper", vol)
			_:
				audio.play(&"hit_heavy", vol)  # cross / overhand: heavy thump
	if tier == 3:
		audio.play(&"hit_crack", -4.0, 0.08)


## A finisher blow's sound, by how it travelled and where it landed.
func _finisher_hit_sound(power: int, event: Dictionary) -> void:
	if not event.get("high", true):
		audio.play(&"hit_body", -1.0 if power >= 2 else -3.0)
		return
	match event.get("kind", CombatData.ImpactKind.STRAIGHT):
		CombatData.ImpactKind.HOOK:
			audio.play(&"hit_hook", -2.0)
		CombatData.ImpactKind.RISING:
			audio.play(&"hit_upper", -2.0)
		_:
			audio.play(&"hit_heavy" if power >= 2 else &"hit_snap", -2.0)


## Developer overlay bookkeeping: where a hit connected, and how far the drawn
## striking limb was from it (a large gap means the visual and hitbox disagree).
func _record_contact(attacker: Fighter, contact: Vector2) -> void:
	var limb: Vector2 = (attacker.get_node("Visual") as FighterVisual).get_strike_point()
	var gap := -1.0 if limb == Vector2.INF else limb.distance_to(contact)
	_contacts.append({"pos": contact, "age": 0, "gap": gap})
	if _contacts.size() > 6:
		_contacts.pop_front()


func _hit_feedback(result: CombatData.HitResult, attack: CombatData.Attack, step: int, contact: Vector2, defender: Fighter) -> void:
	var finisher := step >= CombatData.MAX_COMBO_CHAIN
	var heavy := attack.damage >= 10 or finisher
	match result:
		CombatData.HitResult.HIT:
			var striker := attacker_of(defender)
			var dir := CombatData.impact_dir(attack.type, striker.facing)
			var tier := 3 if finisher else maxi(CombatData.impact_tier(attack.damage), attack.impact_power)
			_hitstop = maxi(_hitstop, attack.hitstop + (3 if finisher else 0))
			# Light hits barely move the frame; heavy ones shake and kick it.
			_shake(attack.hitstop + 2, 0.8 + tier * tier * 0.9 + (3.0 if finisher else 0.0))
			_kick_camera(dir, attack.damage * CAMERA_KICK_PER_DAMAGE * (0.4 if tier == 1 else 1.0))
			var kind := CombatData.impact_kind(attack.type)
			fx.hit(contact, dir, tier, HIT_COLOR, kind, not defender.last_hit_high)
			_hit_sound(tier, defender, kind)
			_camera_punch += [0.0, 0.004, 0.012, 0.025][tier]
		CombatData.HitResult.GUARD_BREAK:
			# Blocked into a broken guard, or parried while out of posture.
			_hitstop = maxi(_hitstop, CombatData.GUARD_BREAK_HITSTOP_FRAMES)
			fx.guard_flash(contact, defender.facing)
		CombatData.HitResult.PARRIED:
			_hitstop = maxi(_hitstop, CombatData.PARRY_HITSTOP_FRAMES)
			_shake(6, 3.0)
			fx.parry_flash(contact, defender.facing)
			audio.play(&"parry", 0.0, 0.03)
			hud.flash(0.12)
			_camera_punch += 0.04
			_slowmo(SLOWMO_PARRY)
		CombatData.HitResult.BLOCKED:
			_hitstop = maxi(_hitstop, CombatData.BLOCK_HITSTOP_FRAMES)
			_shake(4, 1.5)
			fx.guard_flash(contact, defender.facing)
			fx.particles(contact, BLOCK_COLOR, 4, 2.5, 8)
			audio.play(&"block")
		CombatData.HitResult.KO:
			_hitstop = maxi(_hitstop, CombatData.KO_HITSTOP_FRAMES)
			_shake(24, 10.0)
			fx.impact(contact, 3, KO_COLOR)
			audio.play(&"hit_heavy", 2.0)
			hud.flash(0.5)
			_camera_punch += 0.05
	if (result == CombatData.HitResult.HIT or result == CombatData.HitResult.KO) and defender.last_hit_wrong_height != &"":
		# Blocked at the wrong height: say why the guard did not hold.
		hud.popup(attacker_of(defender), "LOW!" if defender.last_hit_wrong_height == &"low" else "OVERHEAD!",
			Color(1.0, 0.6, 0.3))
	if result == CombatData.HitResult.HIT and defender.thrown_off_balance:
		hud.popup(attacker_of(defender), "OFF BALANCE!", Color(1.0, 0.6, 0.3))
		_shake(10, 5.0)
	if result == CombatData.HitResult.HIT and defender.last_hit_counter:
		hud.popup(attacker_of(defender), "COUNTER", Color(1.0, 0.8, 0.35))
		fx.ring(contact, Color(1.0, 0.8, 0.35), 34.0, 10)
		fx.streaks(contact, Vector2(float(attacker_of(defender).facing), 0.0), 10, Color(1.0, 0.85, 0.45))
		audio.play(&"counter", 0.0, 0.04)
		_hitstop += CombatData.COUNTER_HITSTOP_BONUS
		_camera_punch += 0.03
		if attack.damage >= 10:
			_slowmo(SLOWMO_COUNTER)
	if result == CombatData.HitResult.HIT and defender.state == Fighter.State.KNOCKDOWN:
		_hitstop = maxi(_hitstop, attack.hitstop + 4)
		_shake(14, 7.0)
		fx.ring(contact, Color.WHITE, 40.0, 14)
		_camera_punch += 0.03
	if result != CombatData.HitResult.WHIFF:
		defender.face_opponent()


# --- Finisher -----------------------------------------------------------------

func _start_finisher(attacker: Fighter, victim: Fighter, kind: FinisherDirector.Kind) -> void:
	_set_round_state(RoundState.FINISHER)
	_ko_focus = Vector2.INF
	_follow_victim = false
	_finisher = FinisherDirector.new(kind, attacker, victim)
	last_finisher_name = _finisher.get_display_name()
	hud.set_message("", "")
	hud.set_banner("FINISHER  -  %s" % last_finisher_name, attacker.accent_color)
	hud.set_letterbox(true)
	hud.flash(0.35)
	audio.play(&"finisher_sting")
	audio.play(&"finisher_drums", -2.0, 0.0)
	say(attacker, "finisher")
	audio.duck_bgm(-14.0)


func _finisher_feedback(event: Dictionary) -> void:
	if event.is_empty():
		return
	var power: int = event["power"]
	var pos: Vector2 = event["pos"]
	var fdir := Vector2(float(event["dir"]), 0.0)
	if event["wall"]:
		var wall_at := Vector2(_wall_face_x(event["dir"]), pos.y)
		if event["final"]:
			# The knockout blow reads first; the body hits the wall just after.
			_fx_queue.append([FINAL_WALL_FX_DELAY, _wall_impact.bind(wall_at, power)])
		else:
			_wall_impact(wall_at, power)
		_wall_dent = Vector2(_wall_face_x(event["dir"]) + event["dir"] * 10.0, pos.y)
	if event.get("slam", false):
		# Driven back into the wall (no blow): the wall and the body take it.
		_hitstop = maxi(_hitstop, 2)
		_shake(8, 4.0)
		_kick_camera(fdir, 5.0)
		audio.play(&"body_fall", 0.0)
		return
	_finisher_kind_fx(pos, fdir, power, event["final"])
	var hit_dir := CombatData.dir_for_kind(event.get("kind", CombatData.ImpactKind.STRAIGHT), event["dir"])
	if event["final"] and event.get("style", &"") != &"":
		_styled_final(event, pos, hit_dir)
	elif event["final"]:
		_hitstop = maxi(_hitstop, 6)  # short: the slow motion carries the moment
		_shake(18, 7.0)
		_kick_camera(hit_dir, 14.0)
		fx.strike(pos, hit_dir, 3, true)
		if event.get("high", true):
			fx.blood(pos, hit_dir + Vector2(0.0, -0.35), 16, fx.BLOOD_DARK if event["wall"] else fx.BLOOD_COLOR)
		hud.flash(0.1)  # a beat of light, never a white-out over the blow
		audio.play(&"hit_heavy", 3.0)
		audio.play(&"ko_boom")
		_camera_punch += 0.12
		_follow_victim = true
		_ko_focus = pos
		_ko_cut = true
		hud.impact_frame()
	else:
		_hitstop = maxi(_hitstop, 1 + power)
		_shake(3 + power * 2, 1.5 + power * 1.5)
		fx.strike(pos, hit_dir, power)
		if power >= 2 and event.get("high", true):
			fx.blood(pos, hit_dir + Vector2(0.0, -0.3), 4, fx.BLOOD_DARK if event["wall"] else fx.BLOOD_COLOR)
		_kick_camera(hit_dir, 3.0 + power * 3.0)
		_finisher_hit_sound(power, event)
		_camera_punch += 0.015 * power


## Knockout blows that must stay visible (no flare or white-out over them):
## the Super Chor slap and the Paaye Lathi football punt.
func _styled_final(event: Dictionary, pos: Vector2, hit_dir: Vector2) -> void:
	_hitstop = maxi(_hitstop, 6)
	_camera_punch += 0.1
	_follow_victim = true
	_ko_focus = pos
	_ko_cut = true
	var dir := float(event["dir"])
	match event["style"]:
		&"slap":
			# The palm's swing smeared behind it, a sharp crack and a comic "thas!".
			var shoulder := _finisher.attacker.position + Vector2(dir * 6.0, -150.0)
			var toward := (pos - shoulder).angle()
			fx.swing_arc(shoulder, shoulder.distance_to(pos), toward - dir * 1.1, toward + dir * 0.1, Color.WHITE, 10)
			fx.strike(pos, hit_dir, 2)
			fx.comic(pos + Vector2(dir * 46.0, -62.0), "ঠাস!", Color(1.0, 0.82, 0.2))
			fx.sweat(pos, hit_dir, 10, 6.0)
			_shake(22, 9.0)
			audio.play(&"slap", 4.0, 0.0)
			audio.play(&"slap", -4.0, 0.15)
			audio.play(&"ko_boom", -6.0)
		&"punt":
			# Boot into the head on the floor: a spray of dust along the boards,
			# a hollow thud, a comic "dhum!", then the body scraping away.
			var floor_pos := Vector2(pos.x, FLOOR_Y)
			fx.strike(pos, hit_dir, 3)
			fx.dust_cloud(floor_pos, 1.6, 40, 9)
			fx.ground_ring(floor_pos, 70.0, 22)
			fx.streaks(pos, Vector2(dir, -0.15), 10, Color(0.85, 0.75, 0.6), 0.25, 90.0)
			fx.comic(pos + Vector2(dir * 50.0, -60.0), "ধুম!", Color(1.0, 0.55, 0.2))
			_shake(26, 10.0)
			audio.play(&"punt", 3.0, 0.0)
			audio.play(&"ko_boom", -3.0)
			audio.play(&"body_slide", -2.0, 0.0)
	hud.flash(0.08)


## Each finisher's own effects at the moment of each hit (after the finisher
## VFX reference sheet): warm impact flares on every contact, blue energy for
## the attacker's power, a huge flare and signature effect on the final blow.
func _finisher_kind_fx(pos: Vector2, dir: Vector2, power: int, final: bool) -> void:
	# Only the final blow flares; the build-up hits stay clean and readable
	# (the slap and the punt keep the blow itself in view instead).
	# The strike itself carries the light (fx.strike); here only what the blow
	# does to the room: air pushed off the floor under a launching blow.
	if final and _finisher.kind in [FinisherDirector.Kind.PALM_FLURRY, FinisherDirector.Kind.HUNDRED_PALMS]:
		fx.dust_cloud(Vector2(pos.x + dir.x * 50.0, FLOOR_Y), 1.3, 45, 8)


## Continuous finisher effects between hits: the attacker's blue speed lines,
## spin arcs, takeoff dust, the launched victim's flight trail.
var _fin_prev_pos := {}


func _finisher_ambient() -> void:
	if _finisher == null:
		return
	var atk := _finisher.attacker
	var vic := _finisher.victim
	if _finisher.done:
		return
	match _finisher.kind:
		FinisherDirector.Kind.TORNADO_KICK, FinisherDirector.Kind.SPINNING_HEEL:
			# Dust kicked up on takeoff (the body's own motion trail shows the spin).
			if atk.airborne and not _fin_attacker_air:
				fx.ground_ring(Vector2(atk.position.x, FLOOR_Y), 80.0, 18)
				fx.dust_cloud(Vector2(atk.position.x, FLOOR_Y), 1.1, 40, 8)
		FinisherDirector.Kind.WALL_CRUSH, FinisherDirector.Kind.IRON_CORNER:
			# Grit keeps trickling out of the cracked pillar.
			if _wall_dent != Vector2.INF and _tick % 5 == 0:
				fx.debris(_wall_dent + Vector2(0.0, _fx_rng.randf_range(-12.0, 12.0)), 1, _wall_light(), 1.0, 0.0)
	_fin_attacker_air = atk.airborne


## Runs held-back effects once their game ticks have passed (not in hitstop).
func _tick_fx_queue() -> void:
	if _hitstop > 0 or _fx_queue.is_empty():
		return
	for item in _fx_queue.duplicate():
		item[0] -= 1
		if item[0] <= 0:
			_fx_queue.erase(item)
			(item[1] as Callable).call()


func _tick_slowmo() -> void:
	if _slowmo_ticks <= 0:
		return
	_slowmo_ticks -= 1
	if _slowmo_ticks == 0:
		set_game_speed(_base_time_scale())


## Game speed for slow motion. Engine.time_scale alone does not slow the
## simulation (it runs on fixed 60 Hz ticks), so the tick rate itself is
## scaled; time_scale is set too so delta-driven presentation follows.
## Physics interpolation keeps motion smooth between the slower ticks.
static func set_game_speed(speed: float) -> void:
	speed = clampf(speed, 0.1, 1.0)
	Engine.time_scale = speed
	Engine.physics_ticks_per_second = maxi(roundi(CombatData.TICK_RATE * speed), 6)


## Normal speed, or the training speed setting.
func _base_time_scale() -> float:
	return training.speed() if training != null else 1.0


func _end_round() -> void:
	if training != null:
		# Training never ends: a finished finisher puts both back on their marks.
		_reset_training()
		return
	_set_round_state(RoundState.KO)
	audio.announce(&"ko")  # once per round, double K.O. included
	set_game_speed(1.0)
	_slowmo_ticks = 0
	player.stop_combat()
	enemy.stop_combat()
	var player_down := player.state == Fighter.State.KO
	var enemy_down := enemy.state == Fighter.State.KO
	# The round goes to whoever is still standing (a double K.O. to both).
	if enemy_down:
		round_wins[0] += 1
	if player_down:
		round_wins[1] += 1
	hud.set_rounds(round_wins, rounds_to_win)
	_match_over = round_wins.max() >= rounds_to_win
	if round_wins[0] >= rounds_to_win and round_wins[1] >= rounds_to_win:
		_result_text = "DOUBLE K.O."
	elif round_wins[0] >= rounds_to_win:
		_result_text = "%s WINS" % player.fighter_name
	else:
		_result_text = "%s WINS" % enemy.fighter_name
	hud.set_countdown("")
	hud.set_message("K.O.", "")


## The result only appears once every knocked-out body has stopped moving
## (no flight, roll or slide left) and K.O. has been on screen for a moment.
func _tick_round_over() -> void:
	if _state_tick < KO_MIN_TICKS or not _bodies_at_rest():
		return
	if not _match_over:
		_next_round()
		return
	_set_round_state(RoundState.RESULT)
	hud.set_banner("", Color.WHITE)
	hud.set_letterbox(false)
	hud.set_message(_result_text, "ENTER, click or R to restart")
	hud.show_button(&"rematch")
	audio.play(&"victory", -2.0, 0.0)
	audio.duck_bgm(-6.0)


## Between rounds: both back up at full health on their marks (focus carries
## over), then "ROUND 2" / "FINAL ROUND" and FIGHT. The arena keeps its
## battle damage.
func _next_round() -> void:
	_fx_queue.clear()
	round_number += 1
	_finisher = null
	_follow_victim = false
	_ko_focus = Vector2.INF
	_hitstop = 0
	_slowmo_ticks = 0
	set_game_speed(1.0)
	hud.set_banner("", Color.WHITE)
	hud.set_letterbox(false)
	hud.set_message("", "")
	audio.duck_bgm(0.0)
	_reset_fighters(0)
	_low_health_said.clear()
	for f: Fighter in [player, enemy]:
		f.prefight_pose = _intro_pose(f, &"")
	var final_round := round_wins[0] == rounds_to_win - 1 and round_wins[1] == rounds_to_win - 1
	_round_call = true
	_set_round_state(RoundState.COUNTDOWN)
	hud.set_countdown("FINAL ROUND" if final_round else "ROUND %d" % round_number)
	audio.announce(&"final_round" if final_round else &"round_2")


func _bodies_at_rest() -> bool:
	for f: Fighter in [player, enemy]:
		if f.state == Fighter.State.KO and (f.airborne or f.rolling or f.skidding or f.settling):
			return false
	return true


# --- Fighter event feedback (presentation only) -------------------------------

func _on_attack_started(fighter: Fighter, attack: CombatData.Attack) -> void:
	audio.play(&"whoosh_heavy" if attack.damage >= 10 or attack.impact_power >= 2 else &"whoosh_light", -5.0, 0.1)
	if training != null and fighter == player:
		training.on_attack_started(attack)


## Debug log for cross-ups: which side the jump started on.
var _jump_side: Dictionary = {}


func _on_fighter_jumped(fighter: Fighter) -> void:
	_jump_side[fighter] = signf(fighter.position.x - fighter.opponent.position.x)
	fx.dust(Vector2(fighter.position.x, FLOOR_Y), 1.0)
	audio.play(&"jump", -8.0)


func _on_fighter_landed(fighter: Fighter) -> void:
	var floor_pos := Vector2(fighter.position.x, FLOOR_Y)
	if not fighter.is_down() and _jump_side.has(fighter):
		var now := signf(fighter.position.x - fighter.opponent.position.x)
		var gap := absf(fighter.position.x - fighter.opponent.position.x)
		_last_event = "%s jump: %s (gap %.0f px)" % [fighter.fighter_name,
			"crossed over" if now != _jump_side[fighter] else "same side", gap]
		_jump_side.erase(fighter)
	if not fighter.is_down():
		fx.dust(floor_pos, 1.0)
		audio.play(&"land", -6.0)
		return
	var speed := fighter.last_impact_speed
	fx.dust(floor_pos, 1.6 + speed * 0.06)
	fx.particles(floor_pos + Vector2(0.0, -6.0), Color(0.78, 0.68, 0.56), 6, 2.5 + speed * 0.2, 14)
	audio.play(&"body_fall", minf(-4.0 + speed * 0.4, 2.0))
	_shake(8, 3.0 + speed * 0.3)
	if stage != null:
		stage.impact(fighter.position.x, speed)
	if speed > 6.0:
		# Heavy landing: a dust burst and a few bits of floor kicked up.
		fx.dust_cloud(floor_pos, 1.0 + speed * 0.05, 50, 8)
		fx.chunks(floor_pos + Vector2(0.0, -4.0), 3, _floor_main(), 4.0 + speed * 0.2, 0.0, 1.0, 3.0, 6.0)
		if not fighter.spiked:
			fx.floor_scuff(floor_pos + Vector2(0.0, 14.0), speed)
	if speed > 12.0 and fighter.spiked:
		# Spiked into the floor: crater, radial cracks growing out of it,
		# splintered floorboards, a dust burst and a floor shockwave.
		# Just in front of the floor's back edge, so the hole lies on the boards.
		var centre := floor_pos + Vector2(0.0, 20.0)
		fx.floor_break(centre, 3)
		# Impact burst: light rays up out of the floor, big chunks of board
		# thrown high, splinters, a billowing dust cloud and a shockwave.
		fx.flare(centre + Vector2(0.0, -10.0), 2, fx.GLOW_WARM, -PI * 0.5)
		fx.chunks(centre + Vector2(0.0, -6.0), 14, _floor_main(), 12.0, 0.0, 0.85, 7.0, 15.0)
		fx.chunks(centre + Vector2(0.0, -6.0), 10, _floor_second(), 8.0, 0.0, 1.1, 4.0, 8.0)
		if _floor_is_wood():
			fx.splinters(centre + Vector2(0.0, -4.0), 16, FLOOR_WOOD, 11.0, 0.0, 0.9)  # wood splits; paving chips
		# Dust kept low and short so the body in the crater stays readable.
		fx.dust_cloud(floor_pos, 1.4, 45, 8)
		fx.ground_ring(floor_pos, 150.0, 24)
		fx.ground_ring(floor_pos, 90.0, 18)
		audio.play(&"ko_boom", -4.0)
		hud.flash(0.2)
		_shake(18, 9.0)
		_camera_punch += 0.05


func _on_fighter_wall_hit(fighter: Fighter) -> void:
	var dir := 1 if fighter.position.x > 640.0 else -1
	_wall_impact(Vector2(_wall_face_x(dir), fighter.position.y - 110.0), 2)


func _on_fighter_dodged(fighter: Fighter) -> void:
	audio.play(&"whoosh_light", -3.0, 0.12)
	fx.dust(Vector2(fighter.position.x, FLOOR_Y), 0.8)


func attacker_of(defender: Fighter) -> Fighter:
	return enemy if defender == player else player


func _on_fighter_parried(fighter: Fighter, _attacker: Fighter) -> void:
	hud.popup(fighter, "PARRY", PARRY_COLOR)
	if _round_state == RoundState.FIGHTING:
		fighter.add_focus(CombatData.FOCUS_PARRY)


## Signature started: its name over the bar, a grounded power cue (no magic).
func _on_signature_started(fighter: Fighter, attack: CombatData.Attack) -> void:
	hud.popup(fighter, attack.display_name.to_upper(), Color(1.0, 0.85, 0.4))
	audio.play(&"signature", 0.0, 0.02)
	fx.dust(Vector2(fighter.position.x, FLOOR_Y), 1.4)
	_shake(6, 2.5)


## Posture full: shattered guard, big stop, a short callout over the bar.
func _on_fighter_posture_broken(fighter: Fighter) -> void:
	var chest := fighter.position + Vector2(0.0, -120.0)
	fx.shatter(chest)
	audio.play(&"guard_break")
	_shake(14, 6.0)
	hud.flash(0.3)
	hud.popup(fighter, "GUARD BREAK", Color(1.0, 0.35, 0.25))
	_camera_punch += 0.06
	_slowmo(SLOWMO_GUARD_BREAK)


# --- Speech bubbles ----------------------------------------------------------

## `fighter` says its style's line for `event`, if it has one and the bubble
## rules allow it (see SPEECH_*). Returns true when a bubble was shown.
## Per fighter: event -> {"tick": last said, "index": last variant}.
var _speech_said: Dictionary = {}


func say(fighter: Fighter, event: String) -> bool:
	if fighter.style == null or not fighter.style.quotes.has(event):
		return false
	var prio: int = SPEECH_PRIORITY.get(event, 1)
	var cur: Dictionary = _speech.get(fighter, {})
	if not cur.is_empty():
		if cur["ticks"] > 0 and cur["prio"] >= prio:
			return false  # an equally or more important line is showing
		if cur["ticks"] <= 0 and cur["quiet"] > 0 and prio < SPEECH_URGENT:
			return false  # still catching their breath after the last line
	var said: Dictionary = _speech_said.get(fighter, {})
	if prio < SPEECH_URGENT and said.has(event) and _tick - int(said[event]["tick"]) < SPEECH_LINE_COOLDOWN:
		return false  # said that a moment ago
	# A quote is one line or a list of variants (rotated, never twice running).
	var lines: Variant = fighter.style.quotes[event]
	var text: String = ""
	if lines is Array:
		var options: Array = lines
		var last: int = said[event]["index"] if said.has(event) else -1
		var index := (last + 1) % options.size()
		text = String(options[index])
		said[event] = {"tick": _tick, "index": index}
	else:
		text = String(lines)
		said[event] = {"tick": _tick, "index": 0}
	_speech_said[fighter] = said
	var ticks := SPEECH_VICTORY_TICKS if event == "victory" else SPEECH_TICKS
	_speech[fighter] = {"event": event, "text": text, "prio": prio, "ticks": ticks, "quiet": 0}
	hud.show_speech(fighter, text)
	return true


## The line `fighter` is saying now ("" if none).
func speech_text(fighter: Fighter) -> String:
	var cur: Dictionary = _speech.get(fighter, {})
	return cur["text"] if not cur.is_empty() and cur["ticks"] > 0 else ""


func _speech_on_hit(result: CombatData.HitResult, attack: CombatData.Attack, attacker: Fighter, defender: Fighter) -> void:
	match result:
		CombatData.HitResult.HIT:
			if attack.id in SPEECH_SLAPS:
				say(attacker, "slap")
			if defender.health <= defender.max_health * SPEECH_LOW_HEALTH and not _low_health_said.has(defender):
				_low_health_said[defender] = true
				say(defender, "low_health")
			else:
				say(defender, "hurt")
		CombatData.HitResult.BLOCKED:
			say(defender, "block")


## Bubble timers, whiffed big swings ("you got lucky!") and the knocked-out line.
func _tick_speech() -> void:
	for f: Fighter in [player, enemy]:
		if f.state == Fighter.State.KO and not _ko_said.has(f):
			_ko_said[f] = true
			say(f, "knocked_out")
		var cur: Dictionary = _speech.get(f, {})
		if not cur.is_empty():
			if cur["ticks"] > 0:
				cur["ticks"] -= 1
				if cur["ticks"] == 0:
					cur["quiet"] = SPEECH_COOLDOWN
					hud.hide_speech(f)
			elif cur["quiet"] > 0:
				cur["quiet"] -= 1
		var w: Dictionary = _watched_swing.get(f, {})
		var swinging := f.state == Fighter.State.ATTACK and f.current_attack != null
		if not w.is_empty() and (not swinging or f.swing_id != w["swing"]):
			if not w["hit"] and w["id"] in SPEECH_MISS_MOVES and _round_state == RoundState.FIGHTING:
				say(f, "miss_heavy")
			w = {}
		if swinging:
			if w.is_empty():
				w = {"swing": f.swing_id, "id": f.current_attack.id, "hit": false}
			w["hit"] = w["hit"] or f.swing_has_hit
		_watched_swing[f] = w


## A stun move landed: a bell ring and a dazed warble, a burst of stars at
## the head, a short slow-motion beat. The stars circling the head and the
## sway are drawn by FighterVisual while the fighter is DIZZY.
func _on_fighter_dizzied(fighter: Fighter) -> void:
	audio.play(&"dizzy", -2.0, 0.0)
	fx.hit(fighter.position + Vector2(0.0, -160.0), Vector2.UP, 2, DIZZY_COLOR, CombatData.ImpactKind.RISING, false)
	hud.popup(fighter, "DIZZY!", DIZZY_COLOR)
	_shake(8, 4.0)
	_camera_punch += 0.04
	_slowmo(SLOWMO_DIZZY)


func _on_fighter_dizzy_recovered(fighter: Fighter) -> void:
	audio.play(&"shake_off", -6.0, 0.08)


## Dazed birdsong while either fighter is stunned.
func _tick_dizzy_audio() -> void:
	for f: Fighter in [player, enemy]:
		if f.state == Fighter.State.DIZZY and f.dizzy_left > CombatData.DIZZY_RECOVER_FRAMES \
				and f.state_frame % DIZZY_CHIRP_TICKS == DIZZY_CHIRP_TICKS - 1:
			audio.play(&"dizzy_chirp", -9.0, 0.1)


## The winner celebrates in their style once they are back on their feet.
func _tick_celebration() -> void:
	if _round_state != RoundState.RESULT:
		return
	for f: Fighter in [player, enemy]:
		var won := f.state != Fighter.State.KO and (f == player and enemy.state == Fighter.State.KO \
			or f == enemy and player.state == Fighter.State.KO)
		if not won or f.celebration != &"" or f.style == null:
			continue
		if f.state in [Fighter.State.IDLE, Fighter.State.WALK, Fighter.State.LAND, Fighter.State.FINISHER, Fighter.State.ATTACK] \
				and not f.airborne:
			if f.state != Fighter.State.IDLE:
				f.call("_enter_state", Fighter.State.IDLE)
			f.face_opponent()
			f.celebration = f.style.id
			say(f, "victory")


func _on_fighter_perfect_evaded(fighter: Fighter) -> void:
	if _round_state == RoundState.FIGHTING:
		fighter.add_focus(CombatData.FOCUS_PERFECT_DODGE)
	audio.play(&"whoosh_heavy", -2.0, 0.05)
	fx.ring(fighter.position + Vector2(0.0, -100.0), PARRY_COLOR, 46.0, 14)
	_camera_punch += 0.03
	_slowmo(SLOWMO_PERFECT_DODGE)


func _on_fighter_rolled(_fighter: Fighter) -> void:
	audio.play(&"roll", -4.0)


func _wall_face_x(dir: int) -> float:
	return Fighter.ARENA_MAX_X + 20.0 if dir > 0 else Fighter.ARENA_MIN_X - 20.0


## The pillar on `side` (-1 left, +1 right), as drawn in _draw (on the
## street: the stall or the shopfront).
func _pillar_rect(side: int) -> Rect2:
	if stage != null:
		return stage.wall_rects(FLOOR_Y)[0 if side < 0 else 1]
	var edge := Fighter.ARENA_MIN_X - 20.0 if side < 0 else Fighter.ARENA_MAX_X + 20.0
	var outer := edge - 46.0 if side < 0 else edge
	return Rect2(outer, 96.0, 46.0, FLOOR_Y + 6.0 - 96.0)


## A body slammed into a pillar. Damage scales with `power`: a dent with
## cracks running along the pillar (the final palm of Wall Crush hits hardest),
## chunks of wood breaking off, dust, and the pillar shakes.
func _wall_impact(pos: Vector2, power: int) -> void:
	var side := -1 if pos.x < 640.0 else 1
	var pillar := _pillar_rect(side)
	var hit := Vector2(pos.x + side * 10.0, pos.y)
	if stage != null:
		stage.impact(pos.x, 6.0 + power * 3.0)
	fx.wall_crack(hit, power, pillar)
	fx.ring(hit, Color(1.0, 0.95, 0.85), 40.0 + power * 12.0, 14)
	fx.particles(hit, _wall_light(), 6 + power * 3, 4.0, 18)
	# Chunks of the pillar break off and fall: big pieces in the pillar's wood
	# colours, flung inward off the face.
	fx.chunks(hit, 2 + power * 3, _wall_light(), 3.0 + power * 1.4, -side * 0.9, 0.9, 4.0 + power, 8.0 + power * 2.0)
	fx.chunks(hit, 1 + power * 2, _wall_dark(), 2.0 + power, -side * 0.6, 0.8, 4.0, 9.0)
	if power >= 3:
		# Only the knockout impact flares; build-up hits against the wall
		# keep the bodies in front of it readable (cracks and chunks carry them).
		fx.flare(hit, 1, fx.GLOW_WARM)
	fx.dust_cloud(hit + Vector2(-side * 14.0, 10.0), 0.6 + power * 0.3, 45, 4 + power * 2)
	# Splinters of raw wood burst out of the dent, flung inward (more each hit).
	if stage == null or (stage is StyleStage and stage.wall_material() == &"wood"):
		fx.splinters(hit, 4 + power * 5, RAW_WOOD, 5.0 + power * 1.5, -side * 1.1, 0.9)
	fx.dust_cloud(pos + Vector2(-side * 10.0, 0.0), 0.5 + power * 0.25, 30)
	fx.jolt_wall(side, 2.0 + power * 2.0)
	audio.play(&"wall_hit")
	_shake(12, 6.0 + power)
	hud.flash(0.12)
	_camera_punch += 0.03



## Floor debris colours: boards in the dojo, paving on the street.
func _floor_main() -> Color:
	if stage is StyleStage: return stage.floor_main()
	return STONE_LIGHT if stage is WestBengalStage else FLOOR_WOOD


func _floor_second() -> Color:
	if stage is StyleStage: return stage.floor_second()
	return STONE_DARK if stage is WestBengalStage else WOOD_COLOR


func _wall_light() -> Color:
	if stage is StyleStage: return stage.wall_light()
	return PLASTER_LIGHT if stage is WestBengalStage else PILLAR_LIGHT


func _wall_dark() -> Color:
	if stage is StyleStage: return stage.wall_dark()
	return PLASTER_DARK if stage is WestBengalStage else PILLAR_DARK


func _floor_is_wood() -> bool:
	return stage == null or (stage is StyleStage and stage.floor_material() == &"wood")

func _trail_rolling_dust() -> void:
	if _tick % 4 != 0:
		return
	for f: Fighter in [player, enemy]:
		if f.rolling:
			# Dust where the ball meets the floor, thinning as the roll slows.
			if f.roll_speed > 2.5:
				fx.dust(Vector2(f.position.x, FLOOR_Y), 0.25 + f.roll_speed * 0.06)
		elif f.is_rolling_through():
			fx.dust(Vector2(f.position.x, FLOOR_Y), 0.7)
		elif f.skidding:
			# Body sliding along the floor: a dust trail that thins as it slows,
			# and scuff marks on the boards.
			fx.dust(Vector2(f.position.x, FLOOR_Y), 0.5 + f.skid_speed * 0.12)
			var prev: float = _skid_prev_x.get(f, f.position.x)
			fx.scuff(Vector2(prev, FLOOR_Y + 3.0), Vector2(f.position.x, FLOOR_Y + 3.0))
		_skid_prev_x[f] = f.position.x


# --- Camera -------------------------------------------------------------------

func _shake(frames: int, strength: float) -> void:
	if strength >= _shake_strength * (float(_shake_frames) / float(_shake_total)):
		_shake_frames = frames
		_shake_total = frames
		_shake_strength = strength


func _update_shake() -> void:
	if _shake_frames > 0:
		_shake_frames -= 1
		var k := _shake_strength * float(_shake_frames) / float(_shake_total)
		_shake_offset = Vector2(_fx_rng.randf_range(-k, k), _fx_rng.randf_range(-k, k) * 0.6)
	else:
		_shake_offset = Vector2.ZERO


## Knocks the camera along a hit's direction (it springs back in _process).
func _kick_camera(dir: Vector2, amount: float) -> void:
	_camera_kick += dir.normalized() * amount


## A short slow-motion beat (never shortens or weakens one already running).
func _slowmo(beat: Vector2) -> void:
	if _round_state != RoundState.FIGHTING:
		return
	if _slowmo_ticks > 0 and Engine.time_scale <= beat.y:
		_slowmo_ticks = maxi(_slowmo_ticks, int(beat.x))
		return
	_slowmo_ticks = int(beat.x)
	set_game_speed(beat.y)


func _process(delta: float) -> void:
	# Real (unscaled) time, so the camera stays smooth through slow motion.
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	var target_zoom := 1.0
	var target_pos := Vector2(640.0, 360.0)
	var target_rot := 0.0
	if _round_state <= RoundState.COUNTDOWN:
		# Steady, centred pre-fight framing, a little closer for the silhouettes.
		target_zoom = PREFIGHT_ZOOM
		target_pos = Vector2((player.position.x + enemy.position.x) * 0.5, PREFIGHT_FOCUS_Y)
	elif _round_state == RoundState.RESULT:
		# The result shot: level, wide enough for both bodies, the floor low in
		# frame so the title sits above the winner and the buttons below.
		var spread := absf(player.position.x - enemy.position.x)
		target_zoom = clampf(1180.0 / (spread + 520.0), RESULT_ZOOM_MIN, RESULT_ZOOM_MAX)
		var half := Vector2(640.0, 360.0) / target_zoom
		var cx := (player.position.x + enemy.position.x) * 0.5
		target_pos = Vector2(clampf(cx, VIEW_MIN.x + half.x, VIEW_MAX.x - half.x), RESULT_FOCUS_Y)
	elif _finisher != null:
		var attacker := _finisher.attacker
		var victim := _finisher.victim
		var mid := (attacker.position + victim.position) * 0.5
		var since_ko := _finisher.ticks_since_ko()
		var focus := mid + Vector2(0.0, FIN_FOCUS_Y)
		target_zoom = lerpf(FIN_ZOOM_START, FIN_ZOOM_END, smoothstep(0.0, 1.0, _finisher.progress()))
		target_rot = 0.0
		if since_ko >= 0 and since_ko < FIN_KO_HOLD and _ko_focus != Vector2.INF:
			# The knockout shot: tight on the blow, tilted.
			focus = _ko_focus
			target_zoom = FIN_ZOOM_KO
			target_rot = FIN_TILT * float(_finisher.attacker.facing)
		elif _follow_victim:
			# Track the flying victim, widening the shot as they get thrown away.
			focus = mid.lerp(victim.position, 0.55) + Vector2(0.0, -80.0)
			var spread := absf(attacker.position.x - victim.position.x)
			target_zoom = clampf(1300.0 / (spread + 650.0), 1.0, 1.2)
		var half := Vector2(640.0, 360.0) / target_zoom
		target_pos = Vector2(clampf(focus.x, VIEW_MIN.x + half.x, VIEW_MAX.x - half.x),
			clampf(focus.y, VIEW_MIN.y + half.y, VIEW_MAX.y - half.y))
	else:
		var framed := _fight_framing()
		target_zoom = framed.z
		target_pos = Vector2(framed.x, framed.y)
	_camera_punch = maxf(_camera_punch - _camera_punch * CAMERA_PUNCH_DECAY * real_delta, 0.0)
	_camera_kick *= exp(-CAMERA_KICK_DECAY * real_delta)
	var k := 1.0 - exp(-CAMERA_FOLLOW_RATE * real_delta)
	var kz := k
	if _round_state >= RoundState.FIGHTING and _finisher == null:
		# Zoom eases slower than the pan, so exchanges do not pump the frame.
		kz = 1.0 - exp(-FIGHT_ZOOM_RATE * real_delta)
	elif _finisher != null:
		k = 1.0 - exp(-FIN_CAMERA_RATE * real_delta)
		kz = k
	camera.rotation = lerp_angle(camera.rotation, target_rot, k)
	_update_cinematic_overlay()
	if _ko_cut:
		# Cut, not a move: the knockout shot is on screen the same frame.
		_ko_cut = false
		k = 1.0
		kz = 1.0
	camera.zoom = camera.zoom.lerp(Vector2.ONE * target_zoom, kz) + Vector2.ONE * (_camera_punch * k)
	camera.position = camera.position.lerp(target_pos, k)
	camera.offset = _shake_offset + _camera_kick


## Finisher overlay: vignette while a finisher plays, focus lines converging
## on the knockout blow.
func _update_cinematic_overlay() -> void:
	var amount := 1.0 if _finisher != null and not _finisher.done else 0.0
	var lines := 0.0
	var focus := Vector2(640.0, 360.0)
	if _finisher != null and _ko_focus != Vector2.INF:
		var since := _finisher.ticks_since_ko()
		if since >= 0 and since < FIN_KO_HOLD + 6:
			focus = get_viewport().get_canvas_transform() * _ko_focus
	hud.set_cinematic(amount, lines, focus)


## Fight framing: (centre x, centre y, zoom) holding both fighters.
func _fight_framing() -> Vector3:
	var gap := absf(player.position.x - enemy.position.x)
	var air := maxf(maxf(player.ground_y - player.position.y, enemy.ground_y - enemy.position.y), 0.0)
	var zoom := clampf(FIGHT_ZOOM_K / (gap + FIGHT_ZOOM_C), 1.0, FIGHT_ZOOM_MAX)
	zoom = maxf(zoom - air * FIGHT_AIR_ZOOM_OUT, 1.0)
	var half := Vector2(640.0, 360.0) / zoom
	var focus := Vector2((player.position.x + enemy.position.x) * 0.5,
		FLOOR_Y - FIGHT_FLOOR_FRAME * half.y - air * FIGHT_AIR_LIFT)
	return Vector3(clampf(focus.x, VIEW_MIN.x + half.x, VIEW_MAX.x - half.x),
		clampf(focus.y, VIEW_MIN.y + half.y, VIEW_MAX.y - half.y), zoom)


func _refresh_presentation() -> void:
	overlay.queue_redraw()
	var lines := PackedStringArray()
	if _debug_visible:
		lines.append("tick %d   hitstop %d   round %s" % [_tick, _hitstop, RoundState.keys()[_round_state]])
		lines.append("%s  hp %d  %s" % [player.fighter_name, player.health, player.get_debug_label()])
		lines.append("%s  hp %d  %s" % [enemy.fighter_name, enemy.health, enemy.get_debug_label()])
		lines.append("posture  %s %d   %s %d" % [player.fighter_name, roundi(player.posture), enemy.fighter_name, roundi(enemy.posture)])
		lines.append("AI  %s" % enemy_ai.get_state_name())
		lines.append("last  %s" % _last_event)
		if not _contacts.is_empty() and _contacts[-1]["gap"] >= 0.0:
			lines.append("contact: drawn limb %.0f px from contact point" % _contacts[-1]["gap"])
		lines.append("overlay: green hurtbox · yellow pushbox · red hitbox · cyan + drawn limb · yellow o contact")
	hud.set_debug(_debug_visible and training == null, lines)
	if training != null:
		hud.set_training_info(training.info_text())
		if training.tutorial != null:
			var lesson := training.tutorial.text()
			hud.set_lesson(lesson[0], lesson[1])


# --- Drawing ------------------------------------------------------------------

func _draw() -> void:
	if stage != null and not (stage is StyleStage and stage.is_dojo()):
		# The Kolkata street: backdrop, walls, rickshaw and props.
		stage.draw_back(self, FLOOR_Y)
		fx.draw_decals(self)
		return
	# The dojo backdrop (wall, windows, corner props, floor): see DojoStage.
	DojoStage.draw(self, FLOOR_Y)

	# Hanging banner with an abstract emblem.
	draw_rect(Rect2(604.0, 114.0, 72.0, 190.0), Color(0.42, 0.13, 0.11))
	draw_colored_polygon(PackedVector2Array([Vector2(604, 304), Vector2(676, 304), Vector2(640, 324)]), Color(0.42, 0.13, 0.11))
	draw_arc(Vector2(640.0, 190.0), 22.0, 0.3, TAU - 0.3, 32, Color(0.85, 0.75, 0.6), 4.0, true)

	# Solid pillars mark the arena edges (the walls fighters get pinned against).
	for side in [-1.0, 1.0]:
		# A hard wall impact jolts the pillar for a moment (drawing only).
		var jolt: float = fx.wall_jolt[int(side)] * sin(_tick * 2.7)
		var edge := (Fighter.ARENA_MIN_X - 20.0 if side < 0.0 else Fighter.ARENA_MAX_X + 20.0) + jolt
		var outer := edge - 46.0 if side < 0.0 else edge
		var pillar := Rect2(outer, 96.0, 46.0, FLOOR_Y + 6.0 - 96.0)
		draw_rect(pillar, Color(0.13, 0.1, 0.085))
		draw_rect(Rect2(edge - 5.0 if side < 0.0 else edge, 96.0, 5.0, pillar.size.y), Color(0.36, 0.28, 0.21))
		draw_rect(Rect2(outer - 6.0, FLOOR_Y - 4.0, 58.0, 12.0), Color(0.09, 0.07, 0.06))

	# Battle damage (floor craters, wall cracks) sits under the fighters.
	fx.draw_decals(self)


func _draw_overlay() -> void:
	if not _debug_visible:
		return
	var font := ThemeDB.fallback_font
	for f: Fighter in [player, enemy]:
		var hurt := f.get_hurtbox_world()
		if f.is_parry_active():
			overlay.draw_rect(hurt, Color(0.4, 0.9, 1.0, 0.25))
			overlay.draw_rect(hurt, Color(0.4, 0.9, 1.0, 1.0), false, 2.5)
		elif f.can_be_hit():
			overlay.draw_rect(hurt, Color(0.3, 1.0, 0.4, 0.12))
			overlay.draw_rect(hurt, Color(0.3, 1.0, 0.4, 0.8), false, 1.5)
		else:
			overlay.draw_rect(hurt, Color(0.6, 0.6, 0.6, 0.35), false, 1.0)
		var push_y := f.position.y + 8.0
		# Pushbox: yellow when solid, grey while crossing (passing over / through).
		var push_col := Color(0.6, 0.6, 0.6, 0.7) if f.is_crossing() else Color(1.0, 0.9, 0.2, 0.9)
		overlay.draw_line(Vector2(f.position.x - Fighter.PUSH_HALF_WIDTH, push_y),
			Vector2(f.position.x + Fighter.PUSH_HALF_WIDTH, push_y), push_col, 3.0)
		if f.state == Fighter.State.ATTACK and f.current_attack != null:
			var hit_rect := f.get_hitbox_world()
			match f.get_phase():
				Fighter.Phase.STARTUP:
					overlay.draw_rect(hit_rect, Color(1.0, 0.6, 0.2, 0.6), false, 1.0)
				Fighter.Phase.ACTIVE:
					if f.swing_has_hit:
						overlay.draw_rect(hit_rect, Color(0.6, 0.6, 0.6, 0.8), false, 1.5)
					else:
						overlay.draw_rect(hit_rect, Color(1.0, 0.15, 0.15, 0.4))
						overlay.draw_rect(hit_rect, Color(1.0, 0.2, 0.2, 1.0), false, 2.0)
		# Player label sits higher so the two never overlap at close range.
		var label_y := 214.0 if f == player else 196.0
		var label_pos := Vector2(f.position.x - 120.0, f.position.y - label_y)
		overlay.draw_string(font, label_pos + Vector2(1.0, 1.0), f.get_debug_label(), HORIZONTAL_ALIGNMENT_CENTER, 240.0, 13, Color.BLACK)
		overlay.draw_string(font, label_pos, f.get_debug_label(), HORIZONTAL_ALIGNMENT_CENTER, 240.0, 13, Color(0.75, 1.0, 0.8))
		# Where the striking fist / foot is actually drawn.
		var limb: Vector2 = (f.get_node("Visual") as FighterVisual).get_strike_point()
		if f.state == Fighter.State.ATTACK and limb != Vector2.INF:
			var c := Color(0.3, 0.95, 1.0)
			overlay.draw_line(limb - Vector2(7, 0), limb + Vector2(7, 0), c, 2.0)
			overlay.draw_line(limb - Vector2(0, 7), limb + Vector2(0, 7), c, 2.0)
	# Recent contact points.
	for cp in _contacts:
		var a := 1.0 - float(cp["age"]) / CONTACT_SHOW_TICKS
		overlay.draw_arc(cp["pos"], 6.0, 0.0, TAU, 16, Color(1.0, 0.9, 0.2, a), 2.0)
