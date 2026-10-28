class_name Fighter
extends Node2D
## Fixed-tick combat simulation for one fighter.
##
## The fighter never reads input or makes decisions. A controller (keyboard in
## main.gd, or EnemyAI) feeds it a CombatData.Intent with push_intent(), and
## main.gd advances it exactly once per simulation tick with tick().
## FighterVisual only reads this node's public state.
##
## Interrupt rules — the ONLY ways an attack can end before its recovery is over:
##   1. Being hit: the attack is discarded and the fighter enters HITSTUN or KO.
##   2. Chaining: during the first `cancel_window` ticks of recovery a buffered
##      attack starts the next combo step (up to CombatData.MAX_COMBO_CHAIN),
##      if the swing connected (hit or block) and the branch is listed in
##      CombatData.CHAINS. Whiffs always play out their full recovery.
##   3. Landing: an air attack ends when the fighter touches the floor (LAND).
## Walking, blocking, jumping and turning around are never allowed mid-attack.
##
## Jumping: JUMP covers both the short squat on the ground and the airborne arc.
## One air attack per jump: kick buttons -> JUMP_KICK, punch buttons -> JUMP_PUNCH.
## Every landing from a jump goes through LAND recovery.
##
## Knockdown: the KNOCKDOWN_COMBO_HITS-th consecutive hit launches the defender
## into KNOCKDOWN (fly back, bounce, lie down), then GETUP, then IDLE. KO uses the
## same fall and never gets up. Fighters cannot be hit in KNOCKDOWN/GETUP/KO.
##
## Blowback: knockdowns (and finisher KOs) launch the body; it may tumble in
## the air, bounce once off the wall and once off the floor, then roll backward
## `pending_rolls` times along the floor. A rolled knockdown gets up from a crouch.
##
## Parry: a fresh block press opens a short parry window (CombatData.PARRY_*).
## A hit inside it is deflected: the defender enters PARRY (a short deflect that
## any buffered attack cancels, the counter) and the attacker enters STAGGER.
## Unused attempts cost recovery and start a cooldown, so tapping Shift is not
## a free defence.
##
## Perfect dodge: an active hitbox passing through a fighter during the dodge's
## invulnerable frames ends the dodge early (sooner counter).
##
## Posture (CombatData.POSTURE_*): filled by blocking, being parried and
## counter hits; recovers when not pressured. Full posture breaks the guard
## (BROKEN: a guaranteed punish). Counter hits never break by themselves (they
## stop one point short); the next blocked or parried strike does. After a
## break, posture stays empty for a while so breaks cannot loop.
##
## Martial-art style (MartialArtStyle): when set, this fighter is the single
## gate for move legality. Player input arrives as slots and is resolved
## through the style; attacks from AI / tests are rejected when the style does
## not list them; air attacks and combo cancels go through the style too. A
## fighter with no style (bare unit tests) keeps the legacy, unrestricted moves.
##
## Finishers: a lethal hit puts the defender in FINISHED instead of KO. main.gd
## then hands both fighters to a FinisherDirector (attacker -> FINISHER), which
## drives poses/movement through the scripted_* API and ends with finish_ko().

signal knocked_out(fighter: Fighter)
signal jumped(fighter: Fighter)
signal landed(fighter: Fighter)
signal attack_started(fighter: Fighter, attack: CombatData.Attack)
signal wall_hit(fighter: Fighter)
signal rolled(fighter: Fighter)
signal dodged(fighter: Fighter)
## The fighter deflected an attack (defender side).
signal parried(fighter: Fighter, attacker: Fighter)
## An attack passed through the fighter's dodge i-frames.
signal perfect_evaded(fighter: Fighter)
## Posture filled up: the guard is broken.
signal posture_broken(fighter: Fighter)
## A stun move landed: dizzy after the hit reaction (presentation).
signal dizzied(fighter: Fighter)
## Shook off the dizziness (presentation).
signal dizzy_recovered(fighter: Fighter)
## The signature technique began (Focus was spent).
signal signature_started(fighter: Fighter, attack: CombatData.Attack)

enum State { IDLE, WALK, CROUCH, ATTACK, BLOCK, BLOCKSTUN, GUARD_RELEASE, HITSTUN, JUMP, LAND, DODGE, KNOCKDOWN, GETUP, FINISHER, FINISHED, KO, PARRY, STAGGER, BROKEN, EVADE_ROLL, DIZZY }
enum Phase { NONE, STARTUP, ACTIVE, RECOVERY }

## Hurtbox relative to the feet. Symmetric, so facing does not change it.
const HURTBOX: Rect2 = Rect2(-20.0, -172.0, 40.0, 172.0)
## Crouching (and low blocking): head-level strikes pass over this.
const HURTBOX_CROUCH: Rect2 = Rect2(-22.0, -128.0, 44.0, 128.0)
## Curled up in an evasive roll.
const HURTBOX_ROLL: Rect2 = Rect2(-26.0, -64.0, 52.0, 64.0)
## Bodies keep their centres at least 2 * PUSH_HALF_WIDTH apart, about the width
## of a silhouette, so fighters never stand inside each other.
const PUSH_HALF_WIDTH: float = 30.0
const KNOCKBACK_FRICTION: float = 0.84
const ARENA_MIN_X: float = 90.0
const ARENA_MAX_X: float = 1190.0
const HIT_FLASH_FRAMES: int = 6
const COMBO_DISPLAY_FRAMES: int = 70
const KO_KNOCKBACK_MULT: float = 1.3
## How far a lying body extends from its feet position (head side / feet side).
const LYING_HEAD_EXTENT: float = 105.0
const LYING_FEET_EXTENT: float = 95.0
const SETTLE_SPEED: float = 3.0

@export var fighter_name: String = "FIGHTER"
@export var max_health: int = 100
@export var walk_speed: float = 3.2
## Backing-off speed as a fraction of walk_speed (mobile fighters back off faster).
@export var back_walk_mult: float = 0.75
@export var body_color: Color = Color(0.93, 0.9, 0.84)
@export var accent_color: Color = Color(0.25, 0.55, 0.95)
## Active idle rhythm: tempo multiplier and phase offset (seconds), so two
## fighters in the same arena never bounce in sync. Presentation only.
@export var idle_tempo: float = 1.0
@export var idle_phase: float = 0.0
## Scales the active idle's bounce, heel lifts and weight shift (presentation).
@export var idle_amplitude: float = 1.0
## Silhouette outline colour, and whether it glows (rim light for dark fighters).
@export var outline_color: Color = Color(0.1, 0.12, 0.18)
@export var rim_glow: bool = false

var opponent: Fighter = null
## Floor height in world space. Set by main.gd; defaults to the start position.
var ground_y: float = 0.0

var state: State = State.IDLE
var state_frame: int = 0
var stun_frames: int = 0
var health: int = 100
## Health never drops below this from a hit (training keeps both at 1 HP min).
var min_health: int = 0
var facing: int = 1
var velocity_x: float = 0.0

# Vertical motion. jump_vx is the locked air drift, separate from knockback.
var airborne: bool = false
var velocity_y: float = 0.0
var jump_vx: float = 0.0
## In the air from a voluntary jump (its own arc, see CombatData.JUMP_*).
var jump_arc: bool = false
var air_attack_used: bool = false
# Knockdown / blowback bookkeeping.
var bounced: bool = false
var down_frames: int = 0
var tumble: bool = false
var wall_bounced: bool = false
var pending_rolls: int = 0
var rolling: bool = false
## Lying body sliding along the floor after landing (see CombatData.SKID_*).
var skidding: bool = false
var skid_speed: float = 0.0
var skid_dir: int = 1
var roll_distance: float = 0.0
var roll_target: float = 0.0
var roll_speed: float = 0.0
## Speed lost per tick so a knockdown roll stops exactly on its target.
var roll_decel: float = 0.0
var roll_dir: int = 1
var getup_frames: int = CombatData.GETUP_FRAMES
var getup_from_roll: bool = false
var settling: bool = false
var settle_x: float = 0.0
## This flight was driven downward into the floor (Air Smash, axe-kick
## spikes): only such landings smash the floorboards.
var spiked: bool = false
## Downward speed at the last floor contact (presentation: impact size).
var last_impact_speed: float = 0.0
# Deterministic per-fighter randomness (blowback chances).
var _rng := RandomNumberGenerator.new()

var current_attack: CombatData.Attack = null
var combo_step: int = 0
var swing_id: int = 0
var swing_has_hit: bool = false

# Latest controller intent plus buffered presses.
var move_input: int = 0
var block_held: bool = false
var crouch_held: bool = false
var buffered_attack: CombatData.AttackType = CombatData.AttackType.NONE
var buffer_frames: int = 0
var jump_buffer_frames: int = 0
var dodge_buffer_frames: int = 0
var dodge_request: int = 0
## Current dodge: world direction, and +1 (slip in) / -1 (backstep) relative to facing.
var dodge_world_dir: int = 0
var dodge_relative: int = -1
var dodge_perfect: bool = false
## Slip-past dodge: total distance to travel (0 = an ordinary dodge step).
var dodge_slip_dist: float = 0.0
# Evasive roll: distance for this roll and distance covered so far.
var evade_total: float = 0.0
var evade_travelled: float = 0.0
## Ticks left in which overlap after a jump landing / roll is resolved by
## moving only this fighter (see CombatData.CROSS_RESOLVE_*).
var crossing_grace: int = 0
# Parry bookkeeping (see CombatData.PARRY_*).
var parry_buffer_frames: int = 0
## Parry window of the current guard: hits while state_frame < this are parried
## (0 = this guard is not a parry attempt).
var parry_window: int = 0
var parry_cooldown: int = 0
## Last guard drop was a whiffed parry (presentation / debug).
var parry_whiffed: bool = false
# Posture.
var posture: float = 0.0
## Ticks since posture last went up (recovery starts after POSTURE_RECOVER_DELAY).
var posture_idle: int = 0
## While > 0, posture cannot fill (after a break).
var posture_lock: int = 0
## The last clean hit landed on a staggered or starting-up fighter.
var last_hit_counter: bool = false
## Stance (presentation only; see Stances). Set from the style.
var stance: int = Stances.Kind.BLADED
## The locked martial art for this match (null = unrestricted, tests only).
var style: MartialArtStyle = null
## Slot of the buffered press (for air conversion), &"" for direct attacks.
var buffered_slot: StringName = &""
## Slot that started the current attack (&"" for AI / direct attacks).
var attack_slot: StringName = &""
## Ticks since the last Space press that can still form a power chord
## (Space + J / K, CombatData.POWER_CHORD_WINDOW). Large = none open.
var space_age: int = 1000
## Dizzy ticks left (counting the shake-off); and ticks of stun immunity.
var dizzy_left: int = 0
var dizzy_immunity: int = 0
## Winner's celebration (presentation): the style id once it starts.
var celebration: StringName = &""
## Attacks refused because the style does not allow them (tests / debug).
var rejected_attacks: int = 0
## Focus meter (CombatData.FOCUS_*): full = the style's signature on F.
var focus: float = 0.0
var signature_buffer: int = 0
## Independent match resource; round reset deliberately preserves it.
var x_cooldown: int = 0
## The completed aerial move, retained only through its landing recovery.
var landing_attack_id: StringName = &""
var _block_focus_cd: int = 0
## Focus from taking hits inside the current FOCUS_HURT_WINDOW, and the ticks
## left in it.
var _hurt_focus: float = 0.0
var _hurt_focus_left: int = 0
## Strikes of the current signature (or other sequence move) still to come.
var _sequence: Array = []
## The current strike belongs to a signature technique (earns no Focus).
var in_signature: bool = false

# Presentation data: read by visuals/HUD, never used for combat decisions.
var hitstop_frames: int = 0
var flash_frames: int = 0
var walk_distance: float = 0.0
var received_combo: int = 0
## Why the last knockdown happened: combo, blowback (a heavy hit's chance) or
## move (a move that always knocks down). For tuning and tests.
var knockdown_cause: StringName = &""
var combo_display_frames: int = 0
## Increments on every clean hit taken; visuals use it to trigger hit impulses.
var hit_counter: int = 0
var last_hit_high: bool = true
## The last clean hit was at the legs (sweeps): the body falls feet-first.
var last_hit_low: bool = false
## The guard was up but at the wrong height for the last hit: &"low" (a low
## attack against a standing block) or &"overhead" (an overhead against a
## crouching block); &"" otherwise.
var last_hit_wrong_height: StringName = &""
## The last hit threw this fighter off balance (CombatData.Attack.off_balance).
var thrown_off_balance: bool = false
## The last clean hit was a heavy strike (10+ damage): a bigger reaction.
var last_hit_heavy: bool = false
## How the last clean hit travelled (CombatData.ImpactKind): picks the reaction.
var last_hit_kind: int = CombatData.ImpactKind.STRAIGHT
## Scripted (finisher) presentation: named pose for the visual, optional turn-around.
var script_pose: StringName = &"guard"
var script_flip: bool = false
## Finisher spin about the vertical axis, in turns per tick (0 = not spinning).
var script_spin_rate: float = 0.0
## Finisher: hold the current turn about the vertical axis (see FinisherDirector).
var script_spin_hold: bool = false
## Increments on every blocked hit; visuals use it to jolt the guard.
var block_counter: int = 0
## Pre-match presentation: a named pose shown instead of the stance guard while
## idle or walking (&"" = normal guard). Set by main.gd before the fight starts.
var prefight_pose: StringName = &""


func _ready() -> void:
	health = max_health
	ground_y = position.y
	_rng.seed = hash(fighter_name)


# --- Controller interface -----------------------------------------------------

func push_intent(intent: CombatData.Intent) -> void:
	move_input = intent.move
	block_held = intent.block
	crouch_held = intent.crouch
	if state == State.DIZZY:
		# Mashing shakes the stun off sooner (never skipping the shake-off).
		if intent.slot != &"" or intent.jump or intent.dodge != 0 or intent.parry or intent.attack != CombatData.AttackType.NONE:
			dizzy_left = maxi(dizzy_left - CombatData.DIZZY_MASH, mini(dizzy_left, CombatData.DIZZY_RECOVER_FRAMES))
	var slot := intent.slot
	var jump := intent.jump
	if jump:
		space_age = 0
	# Power chord, Space first (or together): a plain J / K inside the window.
	if slot in [&"light", &"heavy"] and space_age <= CombatData.POWER_CHORD_WINDOW and not airborne:
		var power := StringName("power_" + slot)
		if style != null and style.input_map.has(power):
			slot = power
			jump = false
			jump_buffer_frames = 0
			space_age = 1000  # one chord per Space press
	elif jump and _power_chord_after_attack():
		jump = false  # J / K first: the strike in startup became the power move
	if slot != &"":
		# Player press: resolved through the style (an unmapped slot does nothing).
		var resolved := style.resolve(slot, false) if style != null else CombatData.AttackType.NONE
		var air_ok := style != null and style.resolve(slot, true) != CombatData.AttackType.NONE
		if resolved != CombatData.AttackType.NONE or air_ok:
			buffered_attack = resolved if resolved != CombatData.AttackType.NONE else style.resolve(slot, true)
			buffered_slot = slot
			buffer_frames = CombatData.INPUT_BUFFER_FRAMES
	elif intent.attack != CombatData.AttackType.NONE:
		if CombatData.get_attack(intent.attack).x_strike or (style != null and not style.allows(intent.attack)):
			rejected_attacks += 1
		else:
			buffered_attack = intent.attack
			buffered_slot = &""
			buffer_frames = CombatData.INPUT_BUFFER_FRAMES
	if jump:
		jump_buffer_frames = CombatData.JUMP_BUFFER_FRAMES
	if intent.dodge != 0:
		dodge_request = intent.dodge
		dodge_buffer_frames = CombatData.DODGE_BUFFER_FRAMES
	if intent.parry:
		parry_buffer_frames = CombatData.PARRY_BUFFER_FRAMES
	if intent.signature:
		signature_buffer = CombatData.SIGNATURE_BUFFER_FRAMES


## Space pressed just after a plain J / K: the press still queued, or the
## strike still in its startup within the chord window, becomes the style's
## power move (Space + J / K). Returns true when it did.
func _power_chord_after_attack() -> bool:
	if style == null or airborne:
		return false
	if buffered_slot in [&"light", &"heavy"] and buffer_frames >= CombatData.INPUT_BUFFER_FRAMES - CombatData.POWER_CHORD_WINDOW:
		var queued := StringName("power_" + buffered_slot)
		if style.input_map.has(queued):
			buffered_attack = style.resolve(queued, false)
			buffered_slot = queued
			space_age = 1000
			return true
	if state != State.ATTACK or combo_step != 1 or not attack_slot in [&"light", &"heavy"] or in_signature:
		return false
	if get_phase() != Phase.STARTUP or state_frame > CombatData.POWER_CHORD_WINDOW:
		return false
	var power := StringName("power_" + attack_slot)
	if not style.input_map.has(power):
		return false
	_start_attack(style.resolve(power, false), 1, true)
	attack_slot = power
	space_age = 1000
	return true


## Drops any queued input. Used when the round ends.
func stop_combat() -> void:
	buffered_attack = CombatData.AttackType.NONE
	buffer_frames = 0
	jump_buffer_frames = 0
	dodge_buffer_frames = 0
	dodge_request = 0
	parry_buffer_frames = 0
	signature_buffer = 0
	move_input = 0
	block_held = false
	crouch_held = false
	if state == State.DIZZY:
		dizzy_left = mini(dizzy_left, CombatData.DIZZY_RECOVER_FRAMES)


# --- Simulation ---------------------------------------------------------------

func tick() -> void:
	if x_cooldown > 0:
		x_cooldown -= 1
	if flash_frames > 0:
		flash_frames -= 1
	if combo_display_frames > 0:
		combo_display_frames -= 1
	state_frame += 1
	match state:
		State.IDLE, State.WALK:
			_tick_neutral()
		State.BLOCK:
			_tick_block()
		State.CROUCH:
			_tick_crouch()
		State.ATTACK:
			_tick_attack()
		State.DODGE:
			_tick_dodge()
		State.EVADE_ROLL:
			_tick_evade_roll()
		State.DIZZY:
			_tick_dizzy()
		State.JUMP:
			_tick_jump()
		State.PARRY:
			_tick_parry()
		State.HITSTUN, State.BLOCKSTUN, State.LAND, State.GUARD_RELEASE, State.STAGGER, State.BROKEN:
			if state_frame >= stun_frames:
				if airborne:
					# Stun ran out mid-air: drift down with no air attack left.
					air_attack_used = true
					_enter_state(State.JUMP)
				elif state == State.BLOCKSTUN and block_held:
					# Still holding the guard: it is already up (no new parry attempt).
					_enter_state(State.BLOCK)
					state_frame = CombatData.BLOCK_STARTUP_FRAMES
					parry_window = 0
				elif dizzy_left > 0 and (state == State.HITSTUN or state == State.LAND):
					# The hit reaction is over: the stun takes hold (or resumes).
					_enter_state(State.DIZZY)
				else:
					_enter_state(State.IDLE)
		State.KNOCKDOWN:
			_tick_settle()
			if skidding:
				_tick_skid()
			elif rolling:
				_tick_roll()
			elif not airborne:
				down_frames += 1
				if down_frames >= CombatData.KNOCKDOWN_LIE_FRAMES:
					_enter_getup(false)
		State.GETUP:
			if state_frame >= getup_frames:
				_enter_state(State.IDLE)
		State.KO:
			_tick_settle()
			if skidding:
				_tick_skid()
			elif rolling:
				_tick_roll()
	_apply_motion()
	_tick_buffers()
	_tick_posture()
	if crossing_grace > 0:
		crossing_grace -= 1


func _tick_neutral() -> void:
	if _try_signature() or _consume_buffered_attack(1):
		return
	face_opponent()
	if _consume_dodge():
		return
	if _consume_jump():
		return
	if block_held:
		_enter_block()
		return
	if crouch_held:
		_enter_state(State.CROUCH)
		return
	if move_input != 0:
		var speed := walk_speed
		if move_input != facing:
			speed *= back_walk_mult
		position.x += move_input * speed
		walk_distance += speed * move_input * facing
		if state != State.WALK:
			_enter_state(State.WALK)
	elif state != State.IDLE:
		_enter_state(State.IDLE)


## The guard takes BLOCK_STARTUP_FRAMES to come up. Letting go, or wanting to
## attack or jump, drops it through GUARD_RELEASE first (the buffered attack
## survives the release and fires right after).
## A raised guard does not turn around: an opponent who crosses over (jumps
## behind) hits the unguarded back until the guard is dropped and re-raised.
func _tick_block() -> void:
	if _try_signature():
		return
	var wants_out := not block_held or buffered_attack != CombatData.AttackType.NONE or jump_buffer_frames > 0
	if wants_out:
		# Dropping an unused parry attempt early is a whiffed parry: slower recovery.
		parry_whiffed = parry_window > 0 and state_frame < CombatData.PARRY_WHIFF_FRAMES
		_enter_state(State.GUARD_RELEASE)
		stun_frames = CombatData.PARRY_WHIFF_RECOVERY if parry_whiffed else CombatData.BLOCK_RELEASE_FRAMES
		parry_window = 0


## Raises the guard. A recent block press (and no cooldown) makes it a parry attempt.
func _enter_block() -> void:
	_enter_state(State.BLOCK)
	parry_window = 0
	if parry_buffer_frames > 0 and parry_cooldown == 0:
		parry_window = CombatData.PARRY_WINDOW_FRAMES
		parry_cooldown = CombatData.PARRY_COOLDOWN_FRAMES
	parry_buffer_frames = 0


## Deflect after a successful parry. Any buffered attack (the counter), dodge or
## jump cancels it immediately.
func _tick_parry() -> void:
	if _consume_buffered_attack(1) or _consume_dodge() or _consume_jump():
		return
	if state_frame >= CombatData.PARRY_DEFLECT_FRAMES:
		if block_held:
			_enter_state(State.BLOCK)
			state_frame = CombatData.BLOCK_STARTUP_FRAMES
			parry_window = 0
		else:
			_enter_state(State.IDLE)


## True while a hit would be parried.
func is_parry_active() -> bool:
	return state == State.BLOCK and state_frame < parry_window


func _tick_jump() -> void:
	if not airborne:
		# Space + J / K: the squat is the power move's anticipation, no jump.
		if buffered_slot in MartialArtStyle.POWER_SLOTS and buffered_attack != CombatData.AttackType.NONE:
			_consume_buffered_attack(1)
			return
		# A style with power moves keeps a fresh jump in its squat until the
		# chord window has passed (a chord never starts as a jump).
		var chord_wait := CombatData.POWER_CHORD_WINDOW if style != null and style.has_power() else 0
		if state_frame >= CombatData.JUMP_SQUAT_FRAMES and space_age >= chord_wait:
			airborne = true
			jump_arc = true
			velocity_y = CombatData.JUMP_LAUNCH
			jump_vx = move_input * _jump_speed(move_input)
			jumped.emit(self)
		return
	if air_attack_used or buffered_attack == CombatData.AttackType.NONE:
		return
	var air_move := _air_move_for(buffered_attack, buffered_slot)
	buffered_attack = CombatData.AttackType.NONE
	buffered_slot = &""
	buffer_frames = 0
	if air_move == CombatData.AttackType.NONE:
		return  # this style has no air attack for that button
	air_attack_used = true
	_start_attack(air_move, 1, false)


## Which air attack a press becomes. With a style: its air_map (by slot, or by
## whether the ground move was a kick); without: the legacy jump kick / punch.
func _air_move_for(ground: CombatData.AttackType, slot: StringName) -> CombatData.AttackType:
	if CombatData.get_attack(ground).x_move or CombatData.get_attack(ground).x_strike:
		return CombatData.AttackType.NONE
	if CombatData.get_attack(ground).air_only and (style == null or style.allows(ground)):
		return ground
	var kick := CombatData.attack_name(ground).contains("KICK") or ground == CombatData.AttackType.SWEEP
	if style != null:
		if slot != &"":
			return style.resolve(slot, true)
		return style.resolve(&"heavy" if kick else &"light", true)
	return CombatData.AttackType.JUMP_KICK if kick else CombatData.AttackType.JUMP_PUNCH


func _tick_attack() -> void:
	var attack := current_attack
	var strike_end := attack.startup + attack.active
	if attack.backstep > 0.0 and state_frame < attack.backstep_ticks and not airborne:
		position.x -= facing * attack.backstep / float(attack.backstep_ticks)  # run-up
	if attack.leap_vy != 0.0 and state_frame == attack.leap_at and not airborne:
		airborne = true
		air_attack_used = true
		velocity_y = attack.leap_vy
		jump_vx = facing * attack.leap_vx
		jumped.emit(self)
	if attack.rehit > 0 and state_frame > attack.startup and state_frame < strike_end \
			and (state_frame - attack.startup) % attack.rehit == 0:
		swing_has_hit = false  # multi-hit: the hitbox re-arms
	if not _sequence.is_empty() and state_frame >= strike_end + attack.sequence_gap:
		# Next strike of the sequence, whether the last one landed or not.
		_start_attack(_sequence.pop_front(), combo_step, false, true)
		return
	if state_frame < strike_end:
		# Signatures keep chasing through their own knockback (up to body contact).
		var in_range := not airborne and _in_strike_range(attack, in_signature)
		if attack.travel_start >= 0:
			if state_frame >= attack.travel_start and not airborne:
				var travel := attack.lunge
				if opponent != null and not opponent.is_crossing():
					var gap := (opponent.position.x - position.x) * facing
					if gap >= 0.0:
						travel = minf(travel, maxf(0.0, gap - PUSH_HALF_WIDTH * 2.0))
				position.x += travel * facing
		elif not in_range and not (attack.charge and swing_has_hit):
			position.x += attack.lunge * facing
		if attack.step > 0.0 and not airborne and state_frame < attack.startup and not in_range:
			var s := float(attack.startup)
			var k := smoothstep(CombatData.STEP_IN_START, 1.0, (state_frame + 1) / s) 				- smoothstep(CombatData.STEP_IN_START, 1.0, state_frame / s)
			position.x += attack.step * step_scale() * k * facing
	elif combo_step < CombatData.MAX_COMBO_CHAIN and state_frame - strike_end < attack.cancel_window 			and (swing_has_hit or attack.no_strike) and _can_chain(attack.type, buffered_attack):
		# Chains need contact (a weave / feint has nothing to land) and a listed
		# branch (CombatData.CHAINS / the style's chains).
		if _consume_buffered_attack(combo_step + 1):
			return
	if state_frame >= attack.total_frames():
		_end_attack()
		if airborne:
			_enter_state(State.JUMP)
		else:
			# Act on the same tick recovery ends so buffered presses never lose a frame.
			_tick_neutral()


## How far this fighter's strikes step in, relative to CombatData.STEP_IN.
func step_scale() -> float:
	return style.step_scale if style != null else 1.0


## The opponent is already within this strike's reach (or touching): stop
## closing in, so the punch or kick lands extended rather than jammed.
func _in_strike_range(attack: CombatData.Attack, contact_only: bool = false) -> bool:
	if opponent == null:
		return false
	var dx := (opponent.position.x - position.x) * facing
	var contact := PUSH_HALF_WIDTH * 2.0 + 6.0
	var reach := contact if contact_only else maxf(attack.hitbox.end.x + CombatData.STRIKE_RANGE_MARGIN, contact)
	return dx > 0.0 and dx <= reach


func _apply_motion() -> void:
	position.x += velocity_x
	velocity_x *= KNOCKBACK_FRICTION
	if absf(velocity_x) < 0.05:
		velocity_x = 0.0
	if airborne:
		var controllable := state == State.JUMP or state == State.ATTACK
		var arc := jump_arc and controllable
		if not arc:
			jump_arc = false  # hit out of the jump: the shared physics from here
		if controllable and move_input != 0:
			var target := move_input * (_jump_speed(move_input) if arc else CombatData.AIR_SPEED)
			var reversing := arc and jump_vx * move_input < 0.0
			jump_vx = move_toward(jump_vx, target, CombatData.JUMP_REVERSE_CONTROL if reversing else CombatData.AIR_CONTROL)
		elif arc:
			jump_vx *= CombatData.JUMP_RELEASE_DRAG
		if is_down():
			jump_vx *= CombatData.AIR_DRAG
		position.x += jump_vx
		if arc:
			if absf(velocity_y) < CombatData.JUMP_APEX_BAND:
				velocity_y += CombatData.JUMP_APEX_GRAVITY
			else:
				velocity_y += CombatData.JUMP_GRAVITY_RISE if velocity_y < 0.0 else CombatData.JUMP_GRAVITY_FALL
		else:
			velocity_y += CombatData.GRAVITY_RISE if velocity_y < 0.0 else CombatData.GRAVITY_FALL
		position.y += velocity_y
		if position.y >= ground_y:
			_land()
	var unclamped_x := position.x
	clamp_to_arena()
	# A body flying into the wall bounces off it (once per flight).
	if airborne and is_down() and not wall_bounced and not is_equal_approx(unclamped_x, position.x) \
			and absf(jump_vx) > CombatData.WALL_BOUNCE_MIN_SPEED:
		wall_bounced = true
		jump_vx = -jump_vx * CombatData.WALL_BOUNCE_DAMPING
		velocity_y = minf(velocity_y, CombatData.WALL_BOUNCE_VELOCITY)
		wall_hit.emit(self)


## Jump travel speed for a direction (screen -1 / 1): back jumps are shorter.
func _jump_speed(dir: int) -> float:
	return CombatData.JUMP_SPEED_FORWARD if dir * facing >= 0 else CombatData.JUMP_SPEED_BACK


func _land() -> void:
	position.y = ground_y
	jump_arc = false
	last_impact_speed = velocity_y
	landed.emit(self)
	if is_down():
		if not bounced and velocity_y >= CombatData.BOUNCE_MIN_IMPACT:
			# Body slams the floor and bounces once; harder falls bounce higher.
			# (A gentle drop just settles: no bounce injected into it.)
			bounced = true
			var rebound := -velocity_y * CombatData.BOUNCE_RESTITUTION
			if velocity_y >= CombatData.BOUNCE_HARD_IMPACT:
				rebound = minf(CombatData.KNOCKDOWN_BOUNCE_VELOCITY, rebound)
			velocity_y = rebound
			jump_vx *= 0.65 if pending_rolls > 0 else 0.5
			return
		bounced = true
		airborne = false
		velocity_y = 0.0
		tumble = false
		if pending_rolls > 0:
			rolling = true
			roll_distance = 0.0
			roll_target = pending_rolls * CombatData.ROLL_DISTANCE
			roll_dir = (1 if jump_vx > 0.0 else -1) if not is_zero_approx(jump_vx) else -facing
			roll_speed = maxf(absf(jump_vx), CombatData.ROLL_START_SPEED)
			# Even deceleration from the landing speed to rest on the target.
			roll_decel = (roll_speed * roll_speed - CombatData.ROLL_END_SPEED * CombatData.ROLL_END_SPEED) \
				/ (2.0 * roll_target)
			pending_rolls = 0
			rolled.emit(self)
		elif absf(jump_vx) > CombatData.SKID_MIN_SPEED:
			skidding = true
			skid_speed = absf(jump_vx)
			skid_dir = 1 if jump_vx > 0.0 else -1
		else:
			_settle_down()
		jump_vx = 0.0
		return
	airborne = false
	velocity_y = 0.0
	jump_vx = 0.0
	crossing_grace = CombatData.CROSS_RESOLVE_TICKS
	if state == State.JUMP or state == State.ATTACK:
		var lag := CombatData.LANDING_FRAMES_AFTER_AIR_ATTACK if air_attack_used else CombatData.LANDING_FRAMES
		if current_attack != null and current_attack.land_lag > 0:
			lag = current_attack.land_lag
		if current_attack != null and current_attack.hit_land_lag > 0 and swing_has_hit:
			lag = current_attack.hit_land_lag
		elif current_attack != null and current_attack.leap_vy != 0.0 and current_attack.land_lag <= 0:
			# A leaping move with no fixed landing lag: the landing runs out the
			# rest of its own frame data (startup + active + recovery).
			lag = maxi(lag, current_attack.total_frames() - state_frame)
		landing_attack_id = current_attack.id if current_attack != null else &""
		current_attack = null
		_clear_sequence()
		combo_step = 0
		_enter_state(State.LAND)
		stun_frames = lag
	air_attack_used = false


func _tick_posture() -> void:
	if posture_lock > 0:
		posture_lock -= 1
	posture_idle += 1
	if posture <= 0.0 or posture_idle <= CombatData.POSTURE_RECOVER_DELAY:
		return
	var rate := 0.0
	match state:
		State.IDLE, State.WALK, State.CROUCH, State.JUMP, State.LAND, State.DODGE:
			rate = CombatData.POSTURE_RECOVER_RATE
		State.BLOCK, State.GUARD_RELEASE, State.PARRY:
			rate = CombatData.POSTURE_RECOVER_RATE_GUARD
	posture = maxf(posture - rate, 0.0)


## Adds posture damage. Returns true when the meter is full (the guard breaks),
## unless `can_break` is false, in which case it stops one point short.
func add_posture(amount: float, can_break: bool = true) -> bool:
	if posture_lock > 0 or amount <= 0.0:
		return false
	posture_idle = 0
	posture += amount
	if posture >= CombatData.POSTURE_MAX:
		if can_break:
			posture = CombatData.POSTURE_MAX
			return true
		posture = CombatData.POSTURE_MAX - 1.0
	return false


## Guard broken: defenceless for POSTURE_BREAK_FRAMES, then posture is empty and
## locked for POSTURE_LOCK_FRAMES.
func _break_posture(push_dir: int) -> void:
	_clear_sequence()
	current_attack = null
	combo_step = 0
	parry_window = 0
	_enter_state(State.BROKEN)
	stun_frames = CombatData.POSTURE_BREAK_FRAMES
	velocity_x = push_dir * 2.0
	posture = 0.0
	posture_lock = CombatData.POSTURE_BREAK_FRAMES + CombatData.POSTURE_LOCK_FRAMES
	if airborne:
		jump_vx = 0.0
	posture_broken.emit(self)


func is_posture_broken() -> bool:
	return state == State.BROKEN


func _tick_buffers() -> void:
	# A counter pressed during a dodge is held until the dodge ends.
	if buffer_frames > 0 and state != State.DODGE and state != State.EVADE_ROLL:
		buffer_frames -= 1
		if buffer_frames == 0:
			buffered_attack = CombatData.AttackType.NONE
	if jump_buffer_frames > 0:
		jump_buffer_frames -= 1
	if dodge_buffer_frames > 0:
		dodge_buffer_frames -= 1
	if parry_buffer_frames > 0:
		parry_buffer_frames -= 1
	if parry_cooldown > 0:
		parry_cooldown -= 1
	if signature_buffer > 0:
		signature_buffer -= 1
	if dizzy_immunity > 0:
		dizzy_immunity -= 1
	if space_age < 1000:
		space_age += 1
	if _block_focus_cd > 0:
		_block_focus_cd -= 1
	if _hurt_focus_left > 0:
		_hurt_focus_left -= 1
		if _hurt_focus_left == 0:
			_hurt_focus = 0.0


## F at full Focus from an actionable state: the style's signature starts and
## the whole meter is spent (no refund if it misses or is blocked). Without
## full Focus the press does nothing and costs nothing.
func _try_signature() -> bool:
	if signature_buffer <= 0:
		return false
	if focus < CombatData.FOCUS_MAX or style == null or style.signature == &"":
		signature_buffer = 0
		return false
	var type := CombatData.type_for_id(style.signature)
	if type == CombatData.AttackType.NONE:
		return false
	signature_buffer = 0
	focus = 0.0
	buffered_attack = CombatData.AttackType.NONE
	buffer_frames = 0
	_start_attack(type, 1, true)
	signature_started.emit(self, CombatData.get_attack(type))
	return true


func add_focus(amount: float) -> void:
	focus = clampf(focus + amount, 0.0, CombatData.FOCUS_MAX)


## Focus for taking a clean hit: capped at FOCUS_HURT_WINDOW_MAX per
## FOCUS_HURT_WINDOW ticks (the window opens with the first hit).
func add_hurt_focus(amount: float) -> void:
	if _hurt_focus_left <= 0:
		_hurt_focus_left = CombatData.FOCUS_HURT_WINDOW
		_hurt_focus = 0.0
	var paid := minf(amount, CombatData.FOCUS_HURT_WINDOW_MAX - _hurt_focus)
	if paid > 0.0:
		_hurt_focus += paid
		add_focus(paid)


## A blocked hit pays FOCUS_BLOCK at most once per FOCUS_BLOCK_COOLDOWN ticks.
func add_block_focus() -> void:
	if _block_focus_cd > 0:
		return
	_block_focus_cd = CombatData.FOCUS_BLOCK_COOLDOWN
	add_focus(CombatData.FOCUS_BLOCK)


func _can_chain(from: CombatData.AttackType, to: CombatData.AttackType) -> bool:
	return style.can_chain(from, to) if style != null else CombatData.can_chain(from, to)


## Locks a martial art onto this fighter (its stance comes with it).
func set_style(new_style: MartialArtStyle) -> void:
	style = new_style
	if style != null:
		stance = style.stance


func _consume_buffered_attack(step: int) -> bool:
	if buffered_attack == CombatData.AttackType.NONE:
		return false
	var type := buffered_attack
	var slot := buffered_slot
	buffered_attack = CombatData.AttackType.NONE
	buffered_slot = &""
	buffer_frames = 0
	if CombatData.get_attack(type).x_move and (x_cooldown > 0 or airborne or step != 1):
		return false
	if CombatData.get_attack(type).x_strike:
		return false
	if CombatData.get_attack(type).air_only:
		return false  # an air-only move pressed on the ground does nothing
	_start_attack(type, step, true)
	attack_slot = slot
	return true


func _consume_dodge() -> bool:
	if dodge_buffer_frames <= 0 or dodge_request == 0:
		return false
	dodge_buffer_frames = 0
	dodge_world_dir = dodge_request
	dodge_relative = 1 if dodge_world_dir == facing else -1
	dodge_request = 0
	dodge_perfect = false
	if crouch_held:
		# Low double-tap: a committed evasive roll instead of the step.
		evade_total = CombatData.ROLL_FORWARD_DIST if dodge_relative > 0 else CombatData.ROLL_BACK_DIST
		evade_travelled = 0.0
		_enter_state(State.EVADE_ROLL)
		dodged.emit(self)
		return true
	# Very close and dodging toward the opponent: slip past to their other side.
	dodge_slip_dist = 0.0
	if dodge_relative > 0 and opponent != null and not opponent.is_down() and not opponent.airborne:
		var gap := absf(opponent.position.x - position.x)
		if gap <= CombatData.SLIP_PAST_RANGE:
			dodge_slip_dist = gap + CombatData.SLIP_PAST_BEYOND
	_enter_state(State.DODGE)
	dodged.emit(self)
	return true


func _tick_dodge() -> void:
	var f := state_frame
	if f >= CombatData.DODGE_INVULN_START and f < CombatData.DODGE_INVULN_START + CombatData.DODGE_MOVE_FRAMES:
		# Fast at first, easing out.
		var u := float(f - CombatData.DODGE_INVULN_START) / CombatData.DODGE_MOVE_FRAMES
		if dodge_slip_dist > 0.0:
			# Same fast-then-easing profile, scaled to reach the far side
			# (the weights (1 - u) sum to MOVE_FRAMES * 0.55 over the move).
			position.x += dodge_world_dir * dodge_slip_dist * (1.0 - u) / (CombatData.DODGE_MOVE_FRAMES * 0.55)
			clamp_to_arena()
		else:
			var speed := CombatData.DODGE_FORWARD_SPEED if dodge_relative > 0 else CombatData.DODGE_BACK_SPEED
			position.x += dodge_world_dir * speed * 2.0 * (1.0 - u)
	# A perfect dodge skips the recovery once the i-frames end.
	if f >= CombatData.DODGE_FRAMES or (dodge_perfect and f >= CombatData.DODGE_INVULN_END):
		if dodge_slip_dist > 0.0:
			crossing_grace = CombatData.CROSS_RESOLVE_TICKS
			dodge_slip_dist = 0.0
		_enter_state(State.IDLE)
		# Counter opportunity: an attack buffered during the dodge fires now.
		_tick_neutral()


## Crouching: no walking; attacks, jumps, dodges and blocks come straight out.
func _tick_crouch() -> void:
	face_opponent()
	if _try_signature() or _consume_buffered_attack(1) or _consume_dodge() or _consume_jump():
		return
	if block_held:
		_enter_block()
	elif not crouch_held:
		_enter_state(State.IDLE)


## Low profile: crouching, or blocking / recovering from a block while crouched.
func is_crouched() -> bool:
	if state == State.CROUCH:
		return true
	return crouch_held and (state == State.BLOCK or state == State.BLOCKSTUN or state == State.GUARD_RELEASE)


## Evasive roll: tuck (startup), roll along the floor with momentum (fast,
## easing out), then rise (recovery). Facing is locked throughout; an attack
## buffered during the roll fires as it ends.
func _tick_evade_roll() -> void:
	var f := state_frame
	var s := CombatData.ROLL_STARTUP
	var travel := CombatData.ROLL_TRAVEL
	if f > s and f <= s + travel:
		var u0 := float(f - 1 - s) / travel
		var u1 := float(f - s) / travel
		var d := evade_total * (_roll_ease(u1) - _roll_ease(u0))
		var before := position.x
		position.x += dodge_world_dir * d
		clamp_to_arena()
		evade_travelled += absf(position.x - before)
	if f >= s + travel + CombatData.ROLL_RECOVERY:
		crossing_grace = CombatData.CROSS_RESOLVE_TICKS
		_enter_state(State.IDLE)
		_tick_neutral()


static func _roll_ease(u: float) -> float:
	return 1.0 - (1.0 - u) * (1.0 - u)


## Rolling along the floor right now.
func is_rolling_through() -> bool:
	return state == State.EVADE_ROLL and state_frame <= CombatData.ROLL_STARTUP + CombatData.ROLL_TRAVEL


## Rolling through or slipping past: passes through the opponent's pushbox.
func is_passing_through() -> bool:
	if is_rolling_through():
		return true
	return state == State.DODGE and dodge_slip_dist > 0.0 \
		and state_frame < CombatData.DODGE_INVULN_START + CombatData.DODGE_MOVE_FRAMES


## Airborne, rolling through, or just landed / finished rolling: overlap with
## the opponent is resolved by moving this fighter only.
func is_crossing() -> bool:
	return (airborne and not is_down()) or crossing_grace > 0 or is_passing_through()


## Called by main.gd when an active hitbox passes through this fighter's i-frames.
func perfect_evade() -> void:
	if state == State.DODGE and not dodge_perfect:
		dodge_perfect = true
		perfect_evaded.emit(self)


## True during the dodge's invulnerable window.
func is_evading() -> bool:
	if state == State.EVADE_ROLL:
		return state_frame >= CombatData.ROLL_INVULN_START and state_frame < CombatData.ROLL_INVULN_END
	return state == State.DODGE and state_frame >= CombatData.DODGE_INVULN_START \
		and state_frame < CombatData.DODGE_INVULN_END


func _consume_jump() -> bool:
	if jump_buffer_frames <= 0:
		return false
	jump_buffer_frames = 0
	air_attack_used = false
	_enter_state(State.JUMP)
	return true


func _start_attack(type: CombatData.AttackType, step: int, turn_to_opponent: bool, sequence_continuation: bool = false) -> void:
	attack_slot = &""
	if turn_to_opponent:
		face_opponent()
	var chosen := CombatData.get_attack(type)
	if chosen.x_strike and not sequence_continuation:
		rejected_attacks += 1
		return
	if chosen.x_move:
		if x_cooldown > 0 or airborne:
			return
		x_cooldown = chosen.x_cooldown_frames
	if not chosen.sequence.is_empty():
		# A sequence: queue its strikes and start the first one.
		_sequence.clear()
		for m in chosen.sequence:
			_sequence.append(CombatData.type_for_id(m))
		in_signature = chosen.signature
		chosen = CombatData.get_attack(_sequence.pop_front())
	elif _sequence.is_empty():
		in_signature = chosen.signature
	current_attack = chosen
	combo_step = step
	swing_id += 1
	swing_has_hit = false
	_enter_state(State.ATTACK)
	attack_started.emit(self, current_attack)


func _tick_skid() -> void:
	var before := position.x
	position.x += skid_dir * skid_speed
	clamp_to_arena()
	skid_speed *= CombatData.SKID_FRICTION
	if skid_speed < 0.4 or absf(position.x - before) < 0.2:
		skidding = false
		_settle_down()


func _tick_roll() -> void:
	var before := position.x
	position.x += roll_dir * minf(roll_speed, roll_target - roll_distance)
	clamp_to_arena()
	var moved := absf(position.x - before)
	roll_distance += moved
	roll_speed = maxf(roll_speed - roll_decel, CombatData.ROLL_END_SPEED)
	if roll_distance >= roll_target or moved < 0.5:
		rolling = false
		if state == State.KNOCKDOWN:
			_enter_getup(true)
		else:
			_settle_down()


## A body coming to rest lies head-backward and is ~200 px long. If that would
## overlap a wall pillar, it slides away along the floor until it fits.
func _settle_down() -> void:
	if script_pose == &"slumped":
		return  # deliberately sitting against the wall
	var head_dir := -facing
	var wall_inset := 20.0  # pillar faces sit this far outside the arena bounds
	var left_need := LYING_HEAD_EXTENT if head_dir < 0 else LYING_FEET_EXTENT
	var right_need := LYING_HEAD_EXTENT if head_dir > 0 else LYING_FEET_EXTENT
	settle_x = clampf(position.x, ARENA_MIN_X - wall_inset + left_need, ARENA_MAX_X + wall_inset - right_need)
	settling = not is_equal_approx(settle_x, position.x)


func _tick_settle() -> void:
	if settling and not airborne and not rolling:
		position.x = move_toward(position.x, settle_x, SETTLE_SPEED)
		settling = not is_equal_approx(position.x, settle_x)


func _enter_getup(from_roll: bool) -> void:
	getup_from_roll = from_roll
	getup_frames = CombatData.GETUP_FRAMES_AFTER_ROLL if from_roll else CombatData.GETUP_FRAMES
	_enter_state(State.GETUP)


func _end_attack() -> void:
	current_attack = null
	combo_step = 0
	_clear_sequence()
	_enter_state(State.IDLE)


## Drops any remaining sequence strikes (interrupted or finished).
func _clear_sequence() -> void:
	_sequence.clear()
	in_signature = false


## True while more strikes of a sequence are still to come.
func is_mid_sequence() -> bool:
	return not _sequence.is_empty()


func _enter_state(new_state: State) -> void:
	if new_state != State.LAND:
		landing_attack_id = &""
	state = new_state
	state_frame = 0
	if new_state in [State.KNOCKDOWN, State.KO, State.FINISHED, State.FINISHER]:
		dizzy_left = 0  # off their feet (or the round is decided): no stun


## Dizzy: wobbling, guard down, unable to act. Counts down (mashing speeds it
## up); the shake-off is the last DIZZY_RECOVER_FRAMES, then a fresh stun
## cannot land for a while.
func _tick_dizzy() -> void:
	dizzy_left -= 1
	if dizzy_left <= 0:
		dizzy_left = 0
		dizzy_immunity = CombatData.DIZZY_IMMUNITY_FRAMES
		dizzy_recovered.emit(self)
		_enter_state(State.IDLE)


## Dizzy right now (including the shake-off).
func is_dizzy() -> bool:
	return state == State.DIZZY


# --- Hit handling -------------------------------------------------------------

## Applies an incoming hit. `step` is the attacker's combo step for that swing.
func receive_hit(attack: CombatData.Attack, attacker: Fighter, step: int) -> CombatData.HitResult:
	if not can_be_hit():
		return CombatData.HitResult.WHIFF
	var push_dir: int = attacker.facing
	if not is_equal_approx(position.x, attacker.position.x):
		push_dir = 1 if position.x > attacker.position.x else -1
	var finisher := step >= CombatData.MAX_COMBO_CHAIN
	var knockback := attack.knockback * (CombatData.FINISHER_KNOCKBACK_MULT if finisher else 1.0)

	if state == State.ATTACK and current_attack != null and state_frame < current_attack.slip_frames:
		var slip_y := attacker.position.y + attack.hitbox.get_center().y
		if slip_y < position.y - 125.0:
			return CombatData.HitResult.WHIFF  # slipped: the head was off the line
		if current_attack.deflect and not attack.low:
			return CombatData.HitResult.WHIFF  # turned aside by the hands
	var facing_attacker := facing == -push_dir
	# Guard heights: low attacks (sweeps) must be blocked (or parried) low,
	# S + Shift; overheads (and anything thrown in the air) must be blocked
	# standing. Everything else is blocked at either height.
	var overhead := attack.overhead or attacker.airborne
	var right_height := (not attack.low or crouch_held) and not (overhead and crouch_held)
	last_hit_wrong_height = &""
	thrown_off_balance = false
	if is_parry_active() and facing_attacker and right_height:
		return _parry(attacker, push_dir, attack)
	var guarding := (state == State.BLOCK and state_frame >= CombatData.BLOCK_STARTUP_FRAMES) \
		or (state == State.BLOCKSTUN and block_held) or state == State.PARRY
	if not right_height:
		if guarding and facing_attacker:
			last_hit_wrong_height = &"low" if attack.low else &"overhead"
		guarding = false
	if guarding and facing_attacker:
		block_counter += 1
		velocity_x = push_dir * knockback * CombatData.BLOCK_KNOCKBACK_MULT
		# A guard breaker smashes straight through a raised guard (not through
		# a parry, and not again while the guard is still recovering from a break).
		var smashed := attack.guard_break and posture_lock <= 0
		if smashed or add_posture(attack.posture * CombatData.POSTURE_BLOCK_MULT):
			_break_posture(push_dir)
			return CombatData.HitResult.GUARD_BREAK
		_enter_state(State.BLOCKSTUN)
		stun_frames = attack.blockstun
		return CombatData.HitResult.BLOCKED

	# Counter hit: caught reeling from a parry or in the startup of an attack.
	last_hit_counter = state == State.STAGGER or (state == State.ATTACK and get_phase() == Phase.STARTUP)
	if last_hit_counter:
		add_posture(attack.posture * CombatData.POSTURE_COUNTER_MULT, false)

	received_combo = received_combo + 1 if state == State.HITSTUN or state == State.DIZZY else 1
	combo_display_frames = COMBO_DISPLAY_FRAMES
	health = maxi(health - attack.damage, min_health)
	flash_frames = HIT_FLASH_FRAMES
	hit_counter += 1
	var hit_y := attacker.position.y + attack.hitbox.get_center().y
	last_hit_high = hit_y < position.y - 125.0
	last_hit_low = attack.low or hit_y > position.y - 45.0
	last_hit_heavy = attack.damage >= 10
	last_hit_kind = CombatData.impact_kind(attack.type)
	current_attack = null
	combo_step = 0
	_clear_sequence()
	velocity_x = push_dir * knockback
	if health == 0:
		# main.gd plays a finisher (or calls finish_ko directly on a double KO).
		_enter_state(State.FINISHED)
		velocity_x = 0.0
		jump_vx = 0.0
		if airborne:
			velocity_y = minf(velocity_y, 0.0)
		return CombatData.HitResult.KO
	# A heavy hit's chance to blow the target away (under 100%) only applies to
	# a follow-up in a combo or a counter hit: a lone poke never knocks down.
	var earned := received_combo >= CombatData.BLOWBACK_MIN_COMBO or last_hit_counter
	var chance := attack.blowback_chance if attack.blowback_chance >= 1.0 		else attack.blowback_chance * CombatData.BLOWBACK_CHANCE_SCALE
	var blown := chance > 0.0 and (chance >= 1.0 or earned) and _rng.randf() < chance
	# Mid-sequence strikes never knock down: the whole sequence gets to land
	# (the final strike can).
	if attack.stun > 0 and dizzy_left <= 0 and dizzy_immunity <= 0:
		blown = false  # a stun move stuns rather than blowing the target away
	var mid_sequence := attacker.is_mid_sequence()
	if mid_sequence and not attack.knockdown:
		blown = false
	if (received_combo >= CombatData.KNOCKDOWN_COMBO_HITS and not mid_sequence) or blown or attack.knockdown:
		knockdown_cause = &"move" if attack.knockdown else (&"blowback" if blown else &"combo")
		_enter_state(State.KNOCKDOWN)
		if attack.blowback_vx > 0.0:
			blowback(push_dir, attack.blowback_vx, attack.blowback_vy, attack.blowback_rolls, attack.blowback_rolls > 0)
		else:
			_launch_down(push_dir)
		return CombatData.HitResult.HIT
	if airborne:
		jump_vx = 0.0
		velocity_y = minf(velocity_y, CombatData.AIR_HIT_POP_VELOCITY - attack.launch)
	elif attack.launch > 0.0:
		airborne = true
		jump_vx = 0.0
		velocity_y = -attack.launch
	if dizzy_left > 0:
		# Hit while dizzy: the reaction plays, then back to dizzy for what is left.
		dizzy_left = maxi(dizzy_left - CombatData.DIZZY_HIT_DRAIN, 0)
	elif attack.stun > 0 and dizzy_immunity <= 0:
		dizzy_left = attack.stun
		dizzied.emit(self)
	if attack.off_balance > 0 and not airborne and dizzy_left <= 0:
		# Knocked off balance: reeling (open to counter hits), the knockback kept.
		_enter_state(State.STAGGER)
		stun_frames = attack.off_balance
		thrown_off_balance = true
		return CombatData.HitResult.HIT
	_enter_state(State.HITSTUN)
	var base_stun := attack.hitstun + (CombatData.FINISHER_HITSTUN_BONUS if finisher else 0)
	stun_frames = maxi(base_stun - CombatData.COMBO_HITSTUN_DECAY * maxi(received_combo - CombatData.MAX_COMBO_CHAIN, 0), CombatData.MIN_COMBO_HITSTUN)
	if last_hit_counter:
		stun_frames += CombatData.COUNTER_HITSTUN_BONUS
	return CombatData.HitResult.HIT


func _parry(attacker: Fighter, push_dir: int, attack: CombatData.Attack) -> CombatData.HitResult:
	_enter_state(State.PARRY)
	parry_window = 0
	parry_cooldown = 0  # a successful parry can be chained into the next one
	block_counter += 1
	velocity_x = push_dir * 1.0
	parried.emit(self, attacker)
	var gain := attack.posture * CombatData.POSTURE_PARRIED_MULT + CombatData.POSTURE_PARRIED_FLAT
	if attacker.add_posture(gain):
		attacker._break_posture(-push_dir)
		return CombatData.HitResult.GUARD_BREAK
	attacker.stagger(-push_dir)
	return CombatData.HitResult.PARRIED


## Thrown off balance by a parry: the swing is lost and the fighter reels.
func stagger(push_dir: int) -> void:
	_clear_sequence()
	current_attack = null
	combo_step = 0
	_enter_state(State.STAGGER)
	stun_frames = CombatData.PARRY_STAGGER_FRAMES
	velocity_x = push_dir * CombatData.PARRY_PUSHBACK
	if airborne:
		jump_vx = 0.0
		velocity_y = minf(velocity_y, CombatData.AIR_HIT_POP_VELOCITY)


## Sends the fighter flying backward off their feet (knockdown or KO).
func _launch_down(push_dir: int) -> void:
	blowback(push_dir, CombatData.KNOCKDOWN_DRIFT, CombatData.KNOCKDOWN_LAUNCH_VELOCITY, 0, false)


## Launches a downed body: vx along push_dir, vy vertical (negative = up,
## positive = spiked down), then `rolls` floor rolls after the bounce.
func blowback(push_dir: int, vx: float, vy: float, rolls: int, spin: bool) -> void:
	spiked = vy > 0.0
	if vy > 0.0:
		velocity_y = vy
	else:
		velocity_y = minf(velocity_y if airborne else 0.0, vy)
	airborne = true
	bounced = false
	down_frames = 0
	velocity_x = 0.0
	jump_vx = push_dir * vx
	pending_rolls = rolls
	tumble = spin
	rolling = false
	skidding = false
	settling = false
	wall_bounced = false
	air_attack_used = true
	buffered_attack = CombatData.AttackType.NONE
	buffer_frames = 0
	jump_buffer_frames = 0


# --- Scripted (finisher) API: used only by FinisherDirector ---------------------

func begin_scripted(as_victim: bool) -> void:
	_enter_state(State.FINISHED if as_victim else State.FINISHER)
	current_attack = null
	combo_step = 0
	stop_combat()
	velocity_x = 0.0
	jump_vx = 0.0
	script_pose = &"hitstun" if as_victim else &"guard"
	script_flip = false
	script_spin_rate = 0.0
	script_spin_hold = false


func scripted_launch(vy: float) -> void:
	airborne = true
	bounced = false
	velocity_y = vy


func scripted_hit(high: bool, kind: int = CombatData.ImpactKind.STRAIGHT) -> void:
	hit_counter += 1
	last_hit_high = high
	last_hit_kind = kind
	flash_frames = HIT_FLASH_FRAMES


## Ends the attacker's scripted sequence; back to a normal stance.
func end_scripted() -> void:
	script_flip = false
	script_spin_rate = 0.0
	script_spin_hold = false
	_enter_state(State.IDLE)


## Final blow of a finisher: knocked out and sent flying (vy > 0 spikes downward).
func finish_ko(push_dir: int, vy: float, drift: float, rolls: int = 0, spin: bool = false) -> void:
	scripted_hit(true)
	_enter_state(State.KO)
	blowback(push_dir, drift, vy, rolls, spin)
	if vy < 0.0:
		velocity_y = vy  # finishers always launch with their full force
	knocked_out.emit(self)


## Called on the attacker once its current swing has connected (hit or block).
func confirm_hit(result: CombatData.HitResult) -> void:
	swing_has_hit = true
	if current_attack != null and current_attack.bounce and airborne and result != CombatData.HitResult.WHIFF:
		# Belly-first collision: rebound off the target and drop.
		jump_vx = -facing * 3.5
		velocity_y = minf(velocity_y, -6.5)


# --- Queries ------------------------------------------------------------------

func get_phase() -> Phase:
	if state != State.ATTACK or current_attack == null:
		return Phase.NONE
	if state_frame < current_attack.startup:
		return Phase.STARTUP
	if state_frame < current_attack.startup + current_attack.active:
		return Phase.ACTIVE
	return Phase.RECOVERY


func is_hitbox_active() -> bool:
	return get_phase() == Phase.ACTIVE and not swing_has_hit and not current_attack.no_strike


func get_hitbox_world() -> Rect2:
	var box := current_attack.hitbox
	var local_x := box.position.x if facing == 1 else -box.position.x - box.size.x
	return Rect2(position + Vector2(local_x, box.position.y), box.size)


func get_hurtbox_world() -> Rect2:
	var box := HURTBOX_CROUCH if is_crouched() else HURTBOX
	if state == State.EVADE_ROLL:
		box = HURTBOX_ROLL
	return Rect2(position + box.position, box.size)


## Two strikes collide: both fighters' active hitboxes overlap this tick.
## Presentation only (hits still resolve against hurtboxes, trades still trade).
static func hitboxes_clash(a: Fighter, b: Fighter) -> bool:
	return a.is_hitbox_active() and b.is_hitbox_active() and a.get_hitbox_world().intersects(b.get_hitbox_world())


func can_be_hit() -> bool:
	return state != State.KO and state != State.KNOCKDOWN and state != State.GETUP \
		and state != State.FINISHER and state != State.FINISHED and not is_evading()


## Off their feet: falling, lying, or knocked out.
func is_down() -> bool:
	return state == State.KNOCKDOWN or state == State.KO


func can_act() -> bool:
	return state == State.IDLE or state == State.WALK or state == State.BLOCK or state == State.CROUCH


func face_opponent() -> void:
	if opponent == null:
		return
	var dx := opponent.position.x - position.x
	if absf(dx) > CombatData.FACING_HYSTERESIS:
		facing = 1 if dx > 0.0 else -1


func clamp_to_arena() -> void:
	position.x = clampf(position.x, ARENA_MIN_X, ARENA_MAX_X)


func get_state_name() -> String:
	return State.keys()[state]


func get_debug_label() -> String:
	var text := "%s f%d" % [get_state_name(), state_frame]
	if state == State.ATTACK and current_attack != null:
		text = "%s #%d %s %d/%d" % [
			current_attack.display_name, combo_step, Phase.keys()[get_phase()],
			state_frame, current_attack.total_frames()]
	elif state == State.HITSTUN or state == State.BLOCKSTUN or state == State.LAND or state == State.GUARD_RELEASE \
			or state == State.STAGGER or state == State.BROKEN:
		text = "%s %d/%d%s" % [get_state_name(), state_frame, stun_frames,
			" (parry whiff)" if state == State.GUARD_RELEASE and parry_whiffed else ""]
	elif is_parry_active():
		text = "BLOCK f%d  PARRY %d" % [state_frame, parry_window - state_frame]
	elif state == State.KNOCKDOWN:
		if rolling:
			text = "KNOCKDOWN rolling %d/%d" % [roll_distance, roll_target]
		else:
			text = "KNOCKDOWN down %d/%d" % [down_frames, CombatData.KNOCKDOWN_LIE_FRAMES]
	elif state == State.GETUP:
		text = "GETUP %d/%d%s" % [state_frame, getup_frames, " (roll)" if getup_from_roll else ""]
	elif state == State.FINISHER or state == State.FINISHED:
		text = "%s %s" % [get_state_name(), script_pose]
	if airborne:
		text += "  air h%d" % roundi(ground_y - position.y)
	if buffered_attack != CombatData.AttackType.NONE:
		text += "  buf:%s(%d)" % [CombatData.attack_name(buffered_attack), buffer_frames]
	if parry_cooldown > 0:
		text += "  pcd %d" % parry_cooldown
	if posture > 0.0 or posture_lock > 0:
		text += "  pos %d%s" % [roundi(posture), " lock %d" % posture_lock if posture_lock > 0 else ""]
	return text
