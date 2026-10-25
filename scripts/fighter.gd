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

enum State { IDLE, WALK, CROUCH, ATTACK, BLOCK, BLOCKSTUN, GUARD_RELEASE, HITSTUN, JUMP, LAND, DODGE, KNOCKDOWN, GETUP, FINISHER, FINISHED, KO, PARRY, STAGGER, BROKEN }
enum Phase { NONE, STARTUP, ACTIVE, RECOVERY }

## Hurtbox relative to the feet. Symmetric, so facing does not change it.
const HURTBOX: Rect2 = Rect2(-20.0, -172.0, 40.0, 172.0)
## Crouching (and low blocking): head-level strikes pass over this.
const HURTBOX_CROUCH: Rect2 = Rect2(-22.0, -128.0, 44.0, 128.0)
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
var facing: int = 1
var velocity_x: float = 0.0

# Vertical motion. jump_vx is the locked air drift, separate from knockback.
var airborne: bool = false
var velocity_y: float = 0.0
var jump_vx: float = 0.0
var air_attack_used: bool = false
# Knockdown / blowback bookkeeping.
var bounced: bool = false
var down_frames: int = 0
var tumble: bool = false
var wall_bounced: bool = false
var pending_rolls: int = 0
var rolling: bool = false
var roll_distance: float = 0.0
var roll_target: float = 0.0
var roll_speed: float = 0.0
var roll_dir: int = 1
var getup_frames: int = CombatData.GETUP_FRAMES
var getup_from_roll: bool = false
var settling: bool = false
var settle_x: float = 0.0
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
## Stance (presentation only; see Stances).
var stance: int = Stances.Kind.BLADED

# Presentation data: read by visuals/HUD, never used for combat decisions.
var hitstop_frames: int = 0
var flash_frames: int = 0
var walk_distance: float = 0.0
var received_combo: int = 0
var combo_display_frames: int = 0
## Increments on every clean hit taken; visuals use it to trigger hit impulses.
var hit_counter: int = 0
var last_hit_high: bool = true
## The last clean hit was at the legs (sweeps): the body falls feet-first.
var last_hit_low: bool = false
## The last clean hit was a heavy strike (10+ damage): a bigger reaction.
var last_hit_heavy: bool = false
## Scripted (finisher) presentation: named pose for the visual, optional turn-around.
var script_pose: StringName = &"guard"
var script_flip: bool = false
## Finisher spin about the vertical axis, in turns per tick (0 = not spinning).
var script_spin_rate: float = 0.0
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
	if intent.attack != CombatData.AttackType.NONE:
		buffered_attack = intent.attack
		buffer_frames = CombatData.INPUT_BUFFER_FRAMES
	if intent.jump:
		jump_buffer_frames = CombatData.JUMP_BUFFER_FRAMES
	if intent.dodge != 0:
		dodge_request = intent.dodge
		dodge_buffer_frames = CombatData.DODGE_BUFFER_FRAMES
	if intent.parry:
		parry_buffer_frames = CombatData.PARRY_BUFFER_FRAMES


## Drops any queued input. Used when the round ends.
func stop_combat() -> void:
	buffered_attack = CombatData.AttackType.NONE
	buffer_frames = 0
	jump_buffer_frames = 0
	dodge_buffer_frames = 0
	dodge_request = 0
	parry_buffer_frames = 0
	move_input = 0
	block_held = false
	crouch_held = false


# --- Simulation ---------------------------------------------------------------

func tick() -> void:
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
				else:
					_enter_state(State.IDLE)
		State.KNOCKDOWN:
			_tick_settle()
			if rolling:
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
			if rolling:
				_tick_roll()
	_apply_motion()
	_tick_buffers()
	_tick_posture()


func _tick_neutral() -> void:
	if _consume_buffered_attack(1):
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
		if state_frame >= CombatData.JUMP_SQUAT_FRAMES:
			airborne = true
			velocity_y = CombatData.JUMP_VELOCITY
			jump_vx = move_input * CombatData.AIR_SPEED
			jumped.emit(self)
		return
	if air_attack_used or buffered_attack == CombatData.AttackType.NONE:
		return
	var kick := buffered_attack in [CombatData.AttackType.KICK, CombatData.AttackType.FRONT_KICK,
		CombatData.AttackType.HIGH_KICK, CombatData.AttackType.SWEEP]
	buffered_attack = CombatData.AttackType.NONE
	buffer_frames = 0
	air_attack_used = true
	_start_attack(CombatData.AttackType.JUMP_KICK if kick else CombatData.AttackType.JUMP_PUNCH, 1, false)


func _tick_attack() -> void:
	var attack := current_attack
	var strike_end := attack.startup + attack.active
	if state_frame < strike_end:
		position.x += attack.lunge * facing
	elif combo_step < CombatData.MAX_COMBO_CHAIN and state_frame - strike_end < attack.cancel_window 			and swing_has_hit and CombatData.can_chain(attack.type, buffered_attack):
		# Chains need contact and a listed branch (CombatData.CHAINS).
		if _consume_buffered_attack(combo_step + 1):
			return
	if state_frame >= attack.total_frames():
		_end_attack()
		if airborne:
			_enter_state(State.JUMP)
		else:
			# Act on the same tick recovery ends so buffered presses never lose a frame.
			_tick_neutral()


func _apply_motion() -> void:
	position.x += velocity_x
	velocity_x *= KNOCKBACK_FRICTION
	if absf(velocity_x) < 0.05:
		velocity_x = 0.0
	if airborne:
		var controllable := state == State.JUMP or state == State.ATTACK
		if controllable and move_input != 0:
			jump_vx = move_toward(jump_vx, move_input * CombatData.AIR_SPEED, CombatData.AIR_CONTROL)
		if is_down():
			jump_vx *= CombatData.AIR_DRAG
		position.x += jump_vx
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


func _land() -> void:
	position.y = ground_y
	last_impact_speed = velocity_y
	landed.emit(self)
	if is_down():
		if not bounced:
			# Body slams the floor and bounces once; harder falls bounce higher.
			bounced = true
			velocity_y = minf(CombatData.KNOCKDOWN_BOUNCE_VELOCITY, -velocity_y * 0.4)
			jump_vx *= 0.65 if pending_rolls > 0 else 0.5
			return
		airborne = false
		velocity_y = 0.0
		tumble = false
		if pending_rolls > 0:
			rolling = true
			roll_distance = 0.0
			roll_target = pending_rolls * CombatData.ROLL_DISTANCE
			roll_dir = (1 if jump_vx > 0.0 else -1) if not is_zero_approx(jump_vx) else -facing
			roll_speed = maxf(absf(jump_vx), CombatData.ROLL_MIN_SPEED + 1.5)
			pending_rolls = 0
			rolled.emit(self)
		else:
			_settle_down()
		jump_vx = 0.0
		return
	airborne = false
	velocity_y = 0.0
	jump_vx = 0.0
	if state == State.JUMP or state == State.ATTACK:
		var lag := CombatData.LANDING_FRAMES_AFTER_AIR_ATTACK if air_attack_used else CombatData.LANDING_FRAMES
		current_attack = null
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
	if buffer_frames > 0 and state != State.DODGE:
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


func _consume_buffered_attack(step: int) -> bool:
	if buffered_attack == CombatData.AttackType.NONE:
		return false
	var type := buffered_attack
	buffered_attack = CombatData.AttackType.NONE
	buffer_frames = 0
	_start_attack(type, step, true)
	return true


func _consume_dodge() -> bool:
	if dodge_buffer_frames <= 0 or dodge_request == 0:
		return false
	dodge_buffer_frames = 0
	dodge_world_dir = dodge_request
	dodge_relative = 1 if dodge_world_dir == facing else -1
	dodge_request = 0
	dodge_perfect = false
	_enter_state(State.DODGE)
	dodged.emit(self)
	return true


func _tick_dodge() -> void:
	var f := state_frame
	if f >= CombatData.DODGE_INVULN_START and f < CombatData.DODGE_INVULN_START + CombatData.DODGE_MOVE_FRAMES:
		# Fast at first, easing out.
		var u := float(f - CombatData.DODGE_INVULN_START) / CombatData.DODGE_MOVE_FRAMES
		var speed := CombatData.DODGE_FORWARD_SPEED if dodge_relative > 0 else CombatData.DODGE_BACK_SPEED
		position.x += dodge_world_dir * speed * 2.0 * (1.0 - u)
	# A perfect dodge skips the recovery once the i-frames end.
	if f >= CombatData.DODGE_FRAMES or (dodge_perfect and f >= CombatData.DODGE_INVULN_END):
		_enter_state(State.IDLE)
		# Counter opportunity: an attack buffered during the dodge fires now.
		_tick_neutral()


## Crouching: no walking; attacks, jumps, dodges and blocks come straight out.
func _tick_crouch() -> void:
	face_opponent()
	if _consume_buffered_attack(1) or _consume_dodge() or _consume_jump():
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


## Called by main.gd when an active hitbox passes through this fighter's i-frames.
func perfect_evade() -> void:
	if state == State.DODGE and not dodge_perfect:
		dodge_perfect = true
		perfect_evaded.emit(self)


## True during the dodge's invulnerable window.
func is_evading() -> bool:
	return state == State.DODGE and state_frame >= CombatData.DODGE_INVULN_START \
		and state_frame < CombatData.DODGE_INVULN_END


func _consume_jump() -> bool:
	if jump_buffer_frames <= 0:
		return false
	jump_buffer_frames = 0
	air_attack_used = false
	_enter_state(State.JUMP)
	return true


func _start_attack(type: CombatData.AttackType, step: int, turn_to_opponent: bool) -> void:
	if turn_to_opponent:
		face_opponent()
	current_attack = CombatData.get_attack(type)
	combo_step = step
	swing_id += 1
	swing_has_hit = false
	_enter_state(State.ATTACK)
	attack_started.emit(self, current_attack)


func _tick_roll() -> void:
	var before := position.x
	position.x += roll_dir * roll_speed
	clamp_to_arena()
	var moved := absf(position.x - before)
	roll_distance += moved
	roll_speed = maxf(roll_speed * CombatData.ROLL_FRICTION, CombatData.ROLL_MIN_SPEED)
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
	_enter_state(State.IDLE)


func _enter_state(new_state: State) -> void:
	state = new_state
	state_frame = 0


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

	var facing_attacker := facing == -push_dir
	# Low attacks (sweeps) must be blocked (or parried) low: S + Shift.
	var right_height := not attack.low or crouch_held
	if is_parry_active() and facing_attacker and right_height:
		return _parry(attacker, push_dir, attack)
	var guarding := (state == State.BLOCK and state_frame >= CombatData.BLOCK_STARTUP_FRAMES) \
		or (state == State.BLOCKSTUN and block_held) or state == State.PARRY
	if not right_height:
		guarding = false
	if guarding and facing_attacker:
		block_counter += 1
		velocity_x = push_dir * knockback * CombatData.BLOCK_KNOCKBACK_MULT
		if add_posture(attack.posture * CombatData.POSTURE_BLOCK_MULT):
			_break_posture(push_dir)
			return CombatData.HitResult.GUARD_BREAK
		_enter_state(State.BLOCKSTUN)
		stun_frames = attack.blockstun
		return CombatData.HitResult.BLOCKED

	# Counter hit: caught reeling from a parry or in the startup of an attack.
	last_hit_counter = state == State.STAGGER or (state == State.ATTACK and get_phase() == Phase.STARTUP)
	if last_hit_counter:
		add_posture(attack.posture * CombatData.POSTURE_COUNTER_MULT, false)

	received_combo = received_combo + 1 if state == State.HITSTUN else 1
	combo_display_frames = COMBO_DISPLAY_FRAMES
	health = maxi(health - attack.damage, 0)
	flash_frames = HIT_FLASH_FRAMES
	hit_counter += 1
	var hit_y := attacker.position.y + attack.hitbox.get_center().y
	last_hit_high = hit_y < position.y - 125.0
	last_hit_low = hit_y > position.y - 45.0
	last_hit_heavy = attack.damage >= 10
	current_attack = null
	combo_step = 0
	velocity_x = push_dir * knockback
	if health == 0:
		# main.gd plays a finisher (or calls finish_ko directly on a double KO).
		_enter_state(State.FINISHED)
		velocity_x = 0.0
		jump_vx = 0.0
		if airborne:
			velocity_y = minf(velocity_y, 0.0)
		return CombatData.HitResult.KO
	var blown := attack.blowback_chance > 0.0 and _rng.randf() < attack.blowback_chance
	if received_combo >= CombatData.KNOCKDOWN_COMBO_HITS or blown or attack.knockdown:
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
	_enter_state(State.HITSTUN)
	var base_stun := attack.hitstun + (CombatData.FINISHER_HITSTUN_BONUS if finisher else 0)
	stun_frames = maxi(base_stun - CombatData.COMBO_HITSTUN_DECAY * maxi(received_combo - CombatData.MAX_COMBO_CHAIN, 0), CombatData.MIN_COMBO_HITSTUN)
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


func scripted_launch(vy: float) -> void:
	airborne = true
	bounced = false
	velocity_y = vy


func scripted_hit(high: bool) -> void:
	hit_counter += 1
	last_hit_high = high
	flash_frames = HIT_FLASH_FRAMES


## Ends the attacker's scripted sequence; back to a normal stance.
func end_scripted() -> void:
	script_flip = false
	script_spin_rate = 0.0
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
func confirm_hit(_result: CombatData.HitResult) -> void:
	swing_has_hit = true


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
	return get_phase() == Phase.ACTIVE and not swing_has_hit


func get_hitbox_world() -> Rect2:
	var box := current_attack.hitbox
	var local_x := box.position.x if facing == 1 else -box.position.x - box.size.x
	return Rect2(position + Vector2(local_x, box.position.y), box.size)


func get_hurtbox_world() -> Rect2:
	var box := HURTBOX_CROUCH if is_crouched() else HURTBOX
	return Rect2(position + box.position, box.size)


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
	if absf(dx) > 1.0:
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
