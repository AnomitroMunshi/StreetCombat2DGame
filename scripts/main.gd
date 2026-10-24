extends Node2D
## Match orchestrator.
##
## Each fixed physics tick (60 Hz) it: reads keyboard input into an Intent,
## asks the AI for its Intent, advances both fighters, resolves pushboxes and
## hits (simultaneously, so trades are fair), then drives hitstop, feedback,
## KO and restart. A lethal hit starts a scripted finisher (FinisherDirector).
## Presentation (FxLayer effects, GameAudio sound, camera, HUD) never affects
## combat.

enum RoundState { FIGHTING, FINISHER, OVER }

const FLOOR_Y: float = 560.0
const PLAYER_START_X: float = 440.0
const ENEMY_START_X: float = 840.0
const INTRO_FRAMES: int = 50
const RESULT_DELAY_FRAMES: int = 50
## Pushboxes only collide when the fighters' feet are this close vertically,
## so a high enough jump can cross over the opponent.
const PUSH_VERTICAL_RANGE: float = 90.0
## Camera / presentation.
const FINISHER_ZOOM: float = 1.3
const CAMERA_FOLLOW_RATE: float = 4.0
const CAMERA_PUNCH_DECAY: float = 9.0
const SLOWMO_SCALE: float = 0.3
const SLOWMO_TICKS: int = 28
const VIEW_MIN := Vector2(-200.0, -200.0)
const VIEW_MAX := Vector2(1480.0, 920.0)
const HIT_COLOR := Color(1.0, 0.9, 0.6)
const BLOCK_COLOR := Color(0.6, 0.8, 1.0)
const KO_COLOR := Color(1.0, 0.55, 0.4)

@onready var player: Fighter = $Player
@onready var enemy: Fighter = $Enemy
@onready var enemy_ai: EnemyAI = $EnemyAI
@onready var hud: Hud = $HUD
@onready var overlay: Node2D = $Overlay
@onready var camera: Camera2D = $Camera2D
@onready var fx: FxLayer = $Effects
@onready var audio: GameAudio = $Audio

var _round_state: RoundState = RoundState.FIGHTING
var _tick: int = 0
var _hitstop: int = 0
var _over_frames: int = 0
var _result_text: String = ""
var _shake_frames: int = 0
var _shake_total: int = 1
var _shake_strength: float = 0.0
var _camera_punch: float = 0.0
var _debug_visible: bool = false
var _last_event: String = "-"
var _fx_rng := RandomNumberGenerator.new()
var _finisher_rng := RandomNumberGenerator.new()
var _finisher: FinisherDirector = null
var _follow_victim: bool = false
var _slowmo_ticks: int = 0
# Double-tap detection for dodges: tick of the last A / D tap.
var _last_tap := {-1: -1000, 1: -1000}
var _stance_rng := RandomNumberGenerator.new()
## Name of the finisher played this round ("" if none). Read by tests/HUD.
var last_finisher_name: String = ""


func _ready() -> void:
	_fx_rng.seed = 7
	# Which finisher plays is presentation, not combat: vary it every match.
	_finisher_rng.randomize()
	Engine.time_scale = 1.0
	# The camera is moved in _process, so it must not be physics-interpolated.
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	player.position = Vector2(PLAYER_START_X, FLOOR_Y)
	enemy.position = Vector2(ENEMY_START_X, FLOOR_Y)
	player.ground_y = FLOOR_Y
	enemy.ground_y = FLOOR_Y
	player.opponent = enemy
	enemy.opponent = player
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
	fx.decals_changed.connect(queue_redraw)
	# Stances: the player's choice persists across restarts; the AI always picks
	# a different one.
	_stance_rng.randomize()
	player.stance = Stances.player_choice
	enemy.stance = Stances.random_except(player.stance, _stance_rng)
	enemy_ai.setup(enemy, player)
	hud.setup(player, enemy)
	hud.set_message("FIGHT", "")
	overlay.draw.connect(_draw_overlay)


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()
		return
	if Input.is_action_just_pressed("toggle_debug"):
		_debug_visible = not _debug_visible
	if Input.is_action_just_pressed("cycle_stance"):
		_cycle_player_stance()

	_tick += 1
	if _tick == INTRO_FRAMES and _round_state == RoundState.FIGHTING:
		hud.set_message("", "")
	_update_shake()

	var fighting := _round_state == RoundState.FIGHTING
	# Player input is buffered even during hitstop so combos feel responsive.
	player.push_intent(_read_player_intent() if fighting else CombatData.Intent.new())

	if _hitstop > 0:
		_hitstop -= 1
	elif _round_state == RoundState.FINISHER:
		var event := _finisher.tick()
		player.tick()
		enemy.tick()
		_finisher_feedback(event)
		if _finisher.done:
			_end_round()
	else:
		enemy.push_intent(enemy_ai.compute_intent() if fighting else CombatData.Intent.new())
		player.tick()
		enemy.tick()
		_resolve_pushboxes()
		if _round_state == RoundState.FIGHTING:
			_resolve_hits()
		else:
			_tick_round_over()
	_tick_slowmo()
	_trail_rolling_dust()

	player.hitstop_frames = _hitstop
	enemy.hitstop_frames = _hitstop
	# Whoever is striking is drawn in front, so the strike reads at impact.
	for f: Fighter in [player, enemy]:
		f.z_index = 1 if f.state == Fighter.State.ATTACK or f.state == Fighter.State.FINISHER else 0
	_refresh_presentation()


func _read_player_intent() -> CombatData.Intent:
	var intent := CombatData.Intent.new()
	var axis := Input.get_axis("move_left", "move_right")
	intent.move = 0 if is_zero_approx(axis) else (1 if axis > 0.0 else -1)
	intent.block = Input.is_action_pressed("block")
	# S: crouch (S + Shift = low block). S + L is read below as the sweep.
	intent.crouch = Input.is_action_pressed("mod_down")
	intent.jump = Input.is_action_just_pressed("jump")
	# Double-tap A or D within the window = dodge in that direction.
	for dir in [-1, 1]:
		if Input.is_action_just_pressed("move_left" if dir < 0 else "move_right"):
			if _tick - _last_tap[dir] <= CombatData.DOUBLE_TAP_WINDOW:
				intent.dodge = dir
				_last_tap[dir] = -1000
			else:
				_last_tap[dir] = _tick
	if Input.is_action_just_pressed("attack_light"):
		intent.attack = CombatData.AttackType.LIGHT
	elif Input.is_action_just_pressed("attack_heavy"):
		intent.attack = CombatData.AttackType.HEAVY
	elif Input.is_action_just_pressed("attack_kick"):
		# W + L = high kick, S + L = low sweep, L alone = side kick.
		if Input.is_action_pressed("mod_up"):
			intent.attack = CombatData.AttackType.HIGH_KICK
		elif Input.is_action_pressed("mod_down"):
			intent.attack = CombatData.AttackType.SWEEP
		else:
			intent.attack = CombatData.AttackType.KICK
	elif Input.is_action_just_pressed("attack_front_kick"):
		intent.attack = CombatData.AttackType.FRONT_KICK
	elif Input.is_action_just_pressed("attack_backhand"):
		intent.attack = CombatData.AttackType.BACKHAND
	elif Input.is_action_just_pressed("attack_uppercut"):
		intent.attack = CombatData.AttackType.UPPERCUT
	return intent


# --- Combat resolution --------------------------------------------------------

func _resolve_pushboxes() -> void:
	var min_dist := Fighter.PUSH_HALF_WIDTH * 2.0
	var dx := enemy.position.x - player.position.x
	if absf(dx) >= min_dist or absf(enemy.position.y - player.position.y) > PUSH_VERTICAL_RANGE:
		return
	if player.is_down() or enemy.is_down():
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
		if not attacker.is_hitbox_active() or not defender.can_be_hit():
			continue
		var hitbox := attacker.get_hitbox_world()
		var hurtbox := defender.get_hurtbox_world()
		if not hitbox.intersects(hurtbox):
			continue
		pending.append({
			"attacker": attacker, "defender": defender,
			"attack": attacker.current_attack, "step": attacker.combo_step,
			"contact": hitbox.intersection(hurtbox).get_center(),
		})

	var killing_attack: CombatData.Attack = null
	for hit: Dictionary in pending:
		var attacker: Fighter = hit["attacker"]
		var defender: Fighter = hit["defender"]
		var attack: CombatData.Attack = hit["attack"]
		var step: int = hit["step"]
		var result := defender.receive_hit(attack, attacker, step)
		if result == CombatData.HitResult.KO:
			killing_attack = attack
		attacker.confirm_hit(result)
		_hit_feedback(result, attack, step, hit["contact"], defender)
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


func _hit_feedback(result: CombatData.HitResult, attack: CombatData.Attack, step: int, contact: Vector2, defender: Fighter) -> void:
	var finisher := step >= CombatData.MAX_COMBO_CHAIN
	var heavy := attack.damage >= 10 or finisher
	match result:
		CombatData.HitResult.HIT:
			_hitstop = maxi(_hitstop, attack.hitstop + (3 if finisher else 0))
			_shake(attack.hitstop + 2, 2.0 + attack.damage * 0.35 + (3.0 if finisher else 0.0))
			fx.impact(contact, 2 if heavy else 1, HIT_COLOR)
			audio.play(&"hit_heavy" if heavy else &"hit_light")
			_camera_punch += 0.02 if heavy else 0.008
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
	if result == CombatData.HitResult.HIT and defender.state == Fighter.State.KNOCKDOWN:
		_hitstop = maxi(_hitstop, attack.hitstop + 4)
		_shake(14, 7.0)
		fx.ring(contact, Color.WHITE, 40.0, 14)
		_camera_punch += 0.03
	if result != CombatData.HitResult.WHIFF:
		defender.face_opponent()


# --- Finisher -----------------------------------------------------------------

func _start_finisher(attacker: Fighter, victim: Fighter, kind: FinisherDirector.Kind) -> void:
	_round_state = RoundState.FINISHER
	_finisher = FinisherDirector.new(kind, attacker, victim)
	last_finisher_name = _finisher.get_display_name()
	hud.set_message("", "")
	hud.set_banner("FINISHER  -  %s" % last_finisher_name, attacker.accent_color)
	hud.set_letterbox(true)
	hud.flash(0.35)
	audio.play(&"finisher_sting")
	audio.duck_bgm(-14.0)


func _finisher_feedback(event: Dictionary) -> void:
	if event.is_empty():
		return
	var power: int = event["power"]
	var pos: Vector2 = event["pos"]
	if event["wall"]:
		_wall_impact(Vector2(_wall_face_x(event["dir"]), pos.y), power)
	if event["final"]:
		_hitstop = maxi(_hitstop, 12)
		_shake(30, 12.0)
		fx.impact(pos, 3, KO_COLOR)
		fx.ring(pos, Color.WHITE, 90.0, 26)
		hud.flash(1.0)
		audio.play(&"hit_heavy", 3.0)
		audio.play(&"ko_boom")
		_camera_punch += 0.12
		_follow_victim = true
		_slowmo_ticks = SLOWMO_TICKS
		Engine.time_scale = SLOWMO_SCALE
	else:
		_hitstop = maxi(_hitstop, 2 + power * 2)
		_shake(4 + power * 3, 2.0 + power * 2.0)
		fx.impact(pos, power, HIT_COLOR)
		audio.play(&"hit_heavy" if power >= 2 else &"hit_light")
		_camera_punch += 0.015 * power


func _tick_slowmo() -> void:
	if _slowmo_ticks <= 0:
		return
	_slowmo_ticks -= 1
	if _slowmo_ticks == 0:
		Engine.time_scale = 1.0


func _end_round() -> void:
	_round_state = RoundState.OVER
	Engine.time_scale = 1.0
	_slowmo_ticks = 0
	player.stop_combat()
	enemy.stop_combat()
	var player_down := player.state == Fighter.State.KO
	var enemy_down := enemy.state == Fighter.State.KO
	if player_down and enemy_down:
		_result_text = "DOUBLE K.O."
	elif enemy_down:
		_result_text = "%s WINS" % player.fighter_name
	else:
		_result_text = "%s WINS" % enemy.fighter_name
	hud.set_message("K.O.", "")


func _tick_round_over() -> void:
	_over_frames += 1
	if _over_frames == RESULT_DELAY_FRAMES:
		hud.set_banner("", Color.WHITE)
		hud.set_letterbox(false)
		hud.set_message(_result_text, "Press R to restart")
		audio.duck_bgm(-6.0)


# --- Fighter event feedback (presentation only) -------------------------------

func _on_attack_started(_fighter: Fighter, attack: CombatData.Attack) -> void:
	audio.play(&"whoosh_heavy" if attack.damage >= 10 else &"whoosh_light", -5.0, 0.1)


func _on_fighter_jumped(fighter: Fighter) -> void:
	fx.dust(Vector2(fighter.position.x, FLOOR_Y), 1.0)
	audio.play(&"jump", -8.0)


func _on_fighter_landed(fighter: Fighter) -> void:
	var floor_pos := Vector2(fighter.position.x, FLOOR_Y)
	if not fighter.is_down():
		fx.dust(floor_pos, 1.0)
		audio.play(&"land", -6.0)
		return
	var speed := fighter.last_impact_speed
	fx.dust(floor_pos, 1.6 + speed * 0.06)
	fx.particles(floor_pos + Vector2(0.0, -6.0), Color(0.78, 0.68, 0.56), 6, 2.5 + speed * 0.2, 14)
	audio.play(&"body_fall", minf(-4.0 + speed * 0.4, 2.0))
	_shake(8, 3.0 + speed * 0.3)
	if speed > 12.0:
		# Spiked into the floor: crater crack and a floor shockwave.
		fx.crack(floor_pos + Vector2(0.0, 6.0), 110.0, false)
		fx.ground_ring(floor_pos, 160.0, 24)
		audio.play(&"ko_boom", -4.0)
		hud.flash(0.4)
		_camera_punch += 0.05


func _on_fighter_wall_hit(fighter: Fighter) -> void:
	var dir := 1 if fighter.position.x > 640.0 else -1
	_wall_impact(Vector2(_wall_face_x(dir), fighter.position.y - 110.0), 2)


func _on_fighter_dodged(fighter: Fighter) -> void:
	audio.play(&"whoosh_light", -3.0, 0.12)
	fx.dust(Vector2(fighter.position.x, FLOOR_Y), 0.8)


## Q: next stance. The AI never shares the player's stance, so it moves off it.
func _cycle_player_stance() -> void:
	player.stance = (player.stance + 1) % Stances.count()
	Stances.player_choice = player.stance
	if enemy.stance == player.stance:
		enemy.stance = Stances.random_except(player.stance, _stance_rng)


func _on_fighter_rolled(_fighter: Fighter) -> void:
	audio.play(&"roll", -4.0)


func _wall_face_x(dir: int) -> float:
	return Fighter.ARENA_MAX_X + 20.0 if dir > 0 else Fighter.ARENA_MIN_X - 20.0


func _wall_impact(pos: Vector2, power: int) -> void:
	fx.crack(pos, 70.0 + power * 15.0, true)
	fx.ring(pos, Color.WHITE, 50.0 + power * 10.0, 16)
	fx.particles(pos, Color(0.55, 0.42, 0.3), 8 + power * 3, 4.0, 18)
	audio.play(&"wall_hit")
	_shake(12, 6.0 + power)
	hud.flash(0.25)
	_camera_punch += 0.03


func _trail_rolling_dust() -> void:
	if _tick % 4 != 0:
		return
	for f: Fighter in [player, enemy]:
		if f.rolling:
			fx.dust(Vector2(f.position.x, FLOOR_Y), 0.7)


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
		camera.offset = Vector2(_fx_rng.randf_range(-k, k), _fx_rng.randf_range(-k, k) * 0.6)
	else:
		camera.offset = Vector2.ZERO


func _process(delta: float) -> void:
	# Real (unscaled) time, so the camera stays smooth through slow motion.
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	var target_zoom := 1.0
	var target_pos := Vector2(640.0, 360.0)
	if _finisher != null:
		var attacker := _finisher.attacker
		var victim := _finisher.victim
		var mid := (attacker.position + victim.position) * 0.5
		target_zoom = FINISHER_ZOOM
		var focus := mid
		if _follow_victim:
			# Track the flying victim, widening the shot as they get thrown away.
			focus = mid.lerp(victim.position, 0.55)
			var spread := absf(attacker.position.x - victim.position.x)
			target_zoom = clampf(1050.0 / (spread + 650.0), 1.0, FINISHER_ZOOM)
		var half := Vector2(640.0, 360.0) / target_zoom
		focus += Vector2(0.0, -80.0)
		target_pos = Vector2(clampf(focus.x, VIEW_MIN.x + half.x, VIEW_MAX.x - half.x),
			clampf(focus.y, VIEW_MIN.y + half.y, VIEW_MAX.y - half.y))
	_camera_punch = maxf(_camera_punch - _camera_punch * CAMERA_PUNCH_DECAY * real_delta, 0.0)
	var k := 1.0 - exp(-CAMERA_FOLLOW_RATE * real_delta)
	camera.zoom = camera.zoom.lerp(Vector2.ONE * target_zoom, k) + Vector2.ONE * (_camera_punch * k)
	camera.position = camera.position.lerp(target_pos, k)


func _refresh_presentation() -> void:
	overlay.queue_redraw()
	var lines := PackedStringArray()
	if _debug_visible:
		lines.append("tick %d   hitstop %d   round %s" % [_tick, _hitstop, RoundState.keys()[_round_state]])
		lines.append("%s  hp %d  %s" % [player.fighter_name, player.health, player.get_debug_label()])
		lines.append("%s  hp %d  %s" % [enemy.fighter_name, enemy.health, enemy.get_debug_label()])
		lines.append("AI  %s" % enemy_ai.get_state_name())
		lines.append("last  %s" % _last_event)
	hud.set_debug(_debug_visible, lines)


# --- Drawing ------------------------------------------------------------------

func _draw() -> void:
	# Minimal training hall. Drawn oversized so camera shake never shows edges.
	var wall := Color(0.17, 0.145, 0.13)
	draw_rect(Rect2(-200.0, -200.0, 1680.0, 1120.0), wall)
	draw_rect(Rect2(-200.0, 96.0, 1680.0, 18.0), Color(0.09, 0.075, 0.065))
	var x := -110.0
	while x < 1400.0:
		var panel := Rect2(x + 12.0, 128.0, 136.0, 280.0)
		draw_rect(panel, Color(0.33, 0.28, 0.23))
		draw_rect(panel.grow(-6.0), Color(0.42, 0.36, 0.29))
		for i in range(1, 3):
			var gx := panel.position.x + panel.size.x * i / 3.0
			draw_line(Vector2(gx, panel.position.y), Vector2(gx, panel.end.y), Color(0.25, 0.21, 0.17), 3.0)
		for j in range(1, 4):
			var gy := panel.position.y + panel.size.y * j / 4.0
			draw_line(Vector2(panel.position.x, gy), Vector2(panel.end.x, gy), Color(0.25, 0.21, 0.17), 3.0)
		draw_rect(Rect2(x, 114.0, 12.0, FLOOR_Y - 114.0), Color(0.1, 0.085, 0.075))
		x += 160.0
	draw_rect(Rect2(-200.0, 408.0, 1680.0, 14.0), Color(0.1, 0.085, 0.075))
	draw_rect(Rect2(-200.0, 422.0, 1680.0, FLOOR_Y - 422.0), Color(0.22, 0.185, 0.16))

	# Hanging banner with an abstract emblem.
	draw_rect(Rect2(604.0, 114.0, 72.0, 190.0), Color(0.42, 0.13, 0.11))
	draw_colored_polygon(PackedVector2Array([Vector2(604, 304), Vector2(676, 304), Vector2(640, 324)]), Color(0.42, 0.13, 0.11))
	draw_arc(Vector2(640.0, 190.0), 22.0, 0.3, TAU - 0.3, 32, Color(0.85, 0.75, 0.6), 4.0, true)

	# Wooden floor with a training mat.
	draw_rect(Rect2(-200.0, FLOOR_Y, 1680.0, 400.0), Color(0.3, 0.23, 0.17))
	draw_colored_polygon(PackedVector2Array([
		Vector2(150, FLOOR_Y), Vector2(1130, FLOOR_Y), Vector2(1230, 760), Vector2(50, 760)]),
		Color(0.38, 0.3, 0.22))
	var plank_y := FLOOR_Y + 12.0
	var gap := 12.0
	while plank_y < 760.0:
		draw_line(Vector2(-200.0, plank_y), Vector2(1480.0, plank_y), Color(0.0, 0.0, 0.0, 0.18), 2.0)
		gap *= 1.45
		plank_y += gap
	draw_line(Vector2(-200.0, FLOOR_Y), Vector2(1480.0, FLOOR_Y), Color(0.55, 0.43, 0.32), 3.0)

	# Solid pillars mark the arena edges (the walls fighters get pinned against).
	for side in [-1.0, 1.0]:
		var edge := Fighter.ARENA_MIN_X - 20.0 if side < 0.0 else Fighter.ARENA_MAX_X + 20.0
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
		if f.can_be_hit():
			overlay.draw_rect(hurt, Color(0.3, 1.0, 0.4, 0.12))
			overlay.draw_rect(hurt, Color(0.3, 1.0, 0.4, 0.8), false, 1.5)
		else:
			overlay.draw_rect(hurt, Color(0.6, 0.6, 0.6, 0.35), false, 1.0)
		var push_y := f.position.y + 8.0
		overlay.draw_line(Vector2(f.position.x - Fighter.PUSH_HALF_WIDTH, push_y),
			Vector2(f.position.x + Fighter.PUSH_HALF_WIDTH, push_y), Color(1.0, 0.9, 0.2, 0.9), 3.0)
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
