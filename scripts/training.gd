class_name TrainingMode
extends Node
## Training ground: test any move against a dummy and read what it did.
##
## The dummy never gets knocked out (both fighters keep at least 1 HP) and both
## refill once the action has settled. The dummy stands, crouches, blocks
## everything (low-blocking low attacks), jumps, or fights back with the real
## AI. Speed, pause and single-frame stepping, unlimited Focus and a finisher
## tester are here too; main.gd owns the match and calls in.
##
## Readouts: the player's last move with its frame data, what it did (hit,
## blocked, parried, whiffed), the measured frame advantage once both fighters
## can act again (positive = the player recovers first), and combo hits and
## damage.
##
## Pause uses the scene tree's pause, so everything (fighters, effects,
## animation) freezes. This node and main.gd keep running; a frame step
## unpauses for exactly one physics frame (this node runs last and pauses again).

enum Dummy { STAND, CROUCH, BLOCK, JUMP, CPU }

const DUMMY_NAMES: Array[String] = ["STAND", "CROUCH", "BLOCK ALL", "JUMP", "FIGHT BACK"]
const SPEEDS: Array[float] = [1.0, 0.5, 0.25]
## Both fighters free this long: health, posture (and Focus) refill.
const REFILL_DELAY: int = 45
## The jumping dummy jumps again this often.
const JUMP_EVERY: int = 50

var dummy_mode: Dummy = Dummy.STAND
var speed_index: int = 0
var paused: bool = false
var infinite_focus: bool = true
var finisher_index: int = 0

var player: Fighter = null
var dummy: Fighter = null

var last_move: CombatData.Attack = null
var last_result: String = ""
var advantage_text: String = ""
var combo_hits: int = 0
var combo_damage: int = 0

var _stepping: bool = false
var _tick: int = 0
var _measuring: bool = false
var _player_free: int = -1
var _dummy_free: int = -1
var _measured_result: String = ""
var _idle_ticks: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# After everything else, so a frame step pauses again once the frame ran.
	process_physics_priority = 1000


func setup(p: Fighter, d: Fighter) -> void:
	player = p
	dummy = d
	for f: Fighter in [player, dummy]:
		f.min_health = 1


func speed() -> float:
	return SPEEDS[speed_index]


func cycle_dummy() -> void:
	dummy_mode = ((dummy_mode + 1) % Dummy.size()) as Dummy


func cycle_speed() -> void:
	speed_index = (speed_index + 1) % SPEEDS.size()


func toggle_pause() -> void:
	paused = not paused
	_stepping = false
	get_tree().paused = paused


## Advances exactly one physics frame while paused.
func step() -> void:
	if not paused:
		toggle_pause()
		return
	_stepping = true
	get_tree().paused = false


func unpause() -> void:
	paused = false
	_stepping = false
	get_tree().paused = false


func _physics_process(_delta: float) -> void:
	if _stepping:
		_stepping = false
		get_tree().paused = true


## The player's finishers: their style's own open-floor, wall and airborne
## ones, then the classic shared Wall Crush and Air Smash (when the style has
## its own instead).
func finisher_kinds() -> Array[FinisherDirector.Kind]:
	var kinds: Array[FinisherDirector.Kind] = []
	if player.style != null:
		for fid in player.style.finishers:
			kinds.append(FinisherDirector.kind_for_id(fid) as FinisherDirector.Kind)
	if kinds.is_empty():
		kinds.assign(FinisherDirector.OPEN_FLOOR_KINDS)
	for k: FinisherDirector.Kind in [FinisherDirector.wall_kind_for(player.style), FinisherDirector.air_kind_for(player.style),
			FinisherDirector.Kind.WALL_CRUSH, FinisherDirector.Kind.AIR_SMASH]:
		if not k in kinds:
			kinds.append(k)
	return kinds


func current_finisher() -> FinisherDirector.Kind:
	var kinds := finisher_kinds()
	return kinds[finisher_index % kinds.size()]


func cycle_finisher() -> void:
	finisher_index = (finisher_index + 1) % finisher_kinds().size()


## The dummy's controls for this tick (not used in FIGHT BACK).
func dummy_intent() -> CombatData.Intent:
	var it := CombatData.Intent.new()
	match dummy_mode:
		Dummy.CROUCH:
			it.crouch = true
		Dummy.BLOCK:
			# Hold the guard (no fresh press, so it never parries); low attacks
			# are blocked crouching.
			it.block = true
			var low := player.state == Fighter.State.ATTACK and player.current_attack != null and player.current_attack.low
			it.crouch = low
		Dummy.JUMP:
			it.jump = _tick % JUMP_EVERY == 0
	return it


func on_attack_started(attack: CombatData.Attack) -> void:
	last_move = attack
	last_result = "NO STRIKE" if attack.no_strike else "WHIFF"
	advantage_text = ""
	_measuring = false


func on_hit(result: CombatData.HitResult, attacker: Fighter, defender: Fighter, attack: CombatData.Attack) -> void:
	if attacker != player:
		return
	last_result = {
		CombatData.HitResult.HIT: "HIT", CombatData.HitResult.BLOCKED: "BLOCKED",
		CombatData.HitResult.PARRIED: "PARRIED", CombatData.HitResult.GUARD_BREAK: "GUARD BREAK",
		CombatData.HitResult.KO: "K.O.",
	}.get(result, "WHIFF")
	if result == CombatData.HitResult.HIT:
		if defender.received_combo <= 1:
			combo_damage = 0
		combo_hits = defender.received_combo
		combo_damage += attack.damage
	_measuring = true
	_measured_result = last_result
	_player_free = -1
	_dummy_free = -1


func after_tick() -> void:
	_tick += 1
	if _measuring:
		if _player_free < 0 and player.can_act():
			_player_free = _tick
		if _dummy_free < 0 and dummy.can_act():
			_dummy_free = _tick
		if _player_free >= 0 and _dummy_free >= 0:
			advantage_text = "%+d on %s" % [_dummy_free - _player_free, _measured_result.to_lower()]
			_measuring = false
	if player.can_act() and dummy.can_act():
		_idle_ticks += 1
	else:
		_idle_ticks = 0
	if _idle_ticks == REFILL_DELAY:
		for f: Fighter in [player, dummy]:
			f.health = 100
			f.posture = 0.0
	if infinite_focus and not player.in_signature:
		player.focus = CombatData.FOCUS_MAX


## The player's multi-strike technique `attack` is an internal strike of
## (null for ordinary moves).
func _sequence_of(attack: CombatData.Attack) -> CombatData.Attack:
	if player.style == null:
		return null
	var ids := player.style.moves()
	if attack.id in ids:
		return null  # an ordinary move of its own (a signature may reuse it)
	if player.style.signature != &"":
		ids.append(player.style.signature)
	for m in ids:
		var whole := CombatData.get_attack(CombatData.type_for_id(m))
		if attack.id in whole.sequence:
			return whole
	return null


func info_text() -> String:
	var lines := PackedStringArray()
	lines.append("[b]TRAINING[/b]  %s  vs  dummy %s" % [player.style.display_name if player.style else "-",
		dummy.style.display_name if dummy.style else "-"])
	lines.append("Dummy [color=#f2c14e]%s[/color]   Speed [color=#f2c14e]%d%%[/color]%s   Focus %s" % [
		DUMMY_NAMES[dummy_mode], roundi(speed() * 100.0), "   [color=#ff8a6a]PAUSED[/color]" if paused else "",
		"[color=#f2c14e]unlimited[/color]" if infinite_focus else "normal"])
	if player.style != null and player.style.input_map.has(&"x_move"):
		var x_name := player.style.move_name(player.style.input_map[&"x_move"])
		var status := "READY" if player.x_cooldown <= 0 else "%.1f s" % (float(player.x_cooldown) / CombatData.TICK_RATE)
		lines.append("X  [b]%s[/b]  [color=#f2c14e]%s[/color]  (10 s, no Focus)" % [x_name, status])
	var parent := _sequence_of(last_move) if last_move != null else null
	if parent != null:
		# A multi-strike technique reads as one move: every active window, the
		# gaps between them, the final recovery and each strike's damage.
		var subs: Array[CombatData.Attack] = []
		for m in parent.sequence:
			subs.append(CombatData.get_attack(CombatData.type_for_id(m)))
		var actives := PackedStringArray()
		var gaps := PackedStringArray()
		var damages := PackedStringArray()
		for i in subs.size():
			actives.append(str(subs[i].active))
			damages.append(str(subs[i].damage))
			if i > 0:
				gaps.append(str(CombatData.SEQUENCE_GAP + subs[i].startup))
		lines.append("Last move  [b]%s[/b] (%s)   startup %d  active %s  gap %s  recovery %d   damage %s" % [parent.display_name,
			last_move.display_name, subs[0].startup, "+".join(actives), "/".join(gaps), subs[-1].recovery, "+".join(damages)])
		lines.append("Result  [color=#f2c14e]%s[/color]   %s" % [last_result, advantage_text])
	elif last_move != null:
		lines.append("Last move  [b]%s[/b]   startup %d  active %d  recovery %d   damage %d" % [last_move.display_name,
			last_move.startup, last_move.active, last_move.recovery, last_move.damage])
		lines.append("Result  [color=#f2c14e]%s[/color]   %s" % [last_result, advantage_text])
	else:
		lines.append("Last move  -")
		lines.append("")
	lines.append("Combo  %d hits  %d damage" % [combo_hits, combo_damage])
	lines.append("Finisher  [color=#f2c14e]%s[/color]" % FinisherDirector.DISPLAY_NAMES[current_finisher()])
	return "\n".join(lines)
