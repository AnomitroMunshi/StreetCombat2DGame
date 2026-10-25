class_name EnemyAI
extends Node
## State-based opponent controller.
##
## Reads both fighters' public state and returns one CombatData.Intent per
## simulation tick, the same thing the keyboard produces for the player. It
## never changes combat state directly. A seeded RNG makes fights reproducible.
##
## Style-aware: with a martial-art style, combo plans and range come from the
## style (MartialArtStyle.ai_*), and every hard-coded choice (anti-air,
## punishes, jump-ins) picks only moves the style has. The Fighter rejects
## anything illegal anyway; this keeps the AI from wasting turns on it.
## Personality (aggression, block/parry/dodge chances) stays separate from
## style, so an aggressive and a defensive boxer share one moveset.

enum AIState { IDLE, APPROACH, SPACING, ATTACK, BLOCK, RETREAT, JUMP_IN }

const CLOSE_PLANS: Array = [
	[CombatData.AttackType.LIGHT],
	[CombatData.AttackType.LIGHT, CombatData.AttackType.LIGHT],
	[CombatData.AttackType.LIGHT, CombatData.AttackType.LIGHT, CombatData.AttackType.HEAVY],
	[CombatData.AttackType.LIGHT, CombatData.AttackType.KICK],
	[CombatData.AttackType.HEAVY],
	[CombatData.AttackType.LIGHT, CombatData.AttackType.HEAVY],
	[CombatData.AttackType.FRONT_KICK],
	[CombatData.AttackType.LIGHT, CombatData.AttackType.FRONT_KICK],
	[CombatData.AttackType.BACKHAND],
	[CombatData.AttackType.LIGHT, CombatData.AttackType.BACKHAND, CombatData.AttackType.HEAVY],
	[CombatData.AttackType.LIGHT, CombatData.AttackType.UPPERCUT],
	[CombatData.AttackType.SWEEP],
	[CombatData.AttackType.LIGHT, CombatData.AttackType.SWEEP],
	[CombatData.AttackType.HIGH_KICK],
	[CombatData.AttackType.LIGHT, CombatData.AttackType.HIGH_KICK],
]
## Fallback plans for a fighter without a style (tests).
const FAR_PLANS: Array = [
	[CombatData.AttackType.KICK],
	[CombatData.AttackType.HEAVY],
	[CombatData.AttackType.FRONT_KICK],
]

## Pressure fighter: advances steadily, attacks often, rarely backs off.
@export_range(0.0, 1.0) var aggression: float = 0.62
@export_range(0.0, 1.0) var block_chance: float = 0.5
## Ticks after the player's attack begins before the AI can react to it.
@export var reaction_frames: int = 6
@export var preferred_range: float = 95.0
## Chance to pick a jump-in when at mid range.
@export_range(0.0, 1.0) var jump_in_chance: float = 0.15
## Chance to backstep (dodge) a noticed attack instead of blocking it.
@export_range(0.0, 1.0) var dodge_chance: float = 0.12
## Chance to time a perfect parry instead of blocking (only against attacks
## slow enough to read: startup at least reaction_frames + 2).
@export_range(0.0, 1.0) var parry_chance: float = 0.15
## Per-tick chance to fire the signature when Focus is full and in range.
@export_range(0.0, 1.0) var signature_chance: float = 0.05
## Chance to punish a staggered (parried) or whiffing opponent.
@export_range(0.0, 1.0) var punish_chance: float = 0.8
## Chance to uppercut a player who is jumping in close.
@export_range(0.0, 1.0) var anti_air_chance: float = 0.4
@export var rng_seed: int = 20261024

var _me: Fighter = null
var _target: Fighter = null
var _state: AIState = AIState.IDLE
var _timer: int = 0
var _plan: Array = []
var _plan_index: int = 0
var _last_pressed_swing: int = -1
var _was_stunned: bool = false
var _jump_pressed: bool = false
var _kick_pressed: bool = false
var _anti_air_rolled: bool = false
var _dodge_now: bool = false
var _block_low: bool = false
## Target's state_frame at which to press block for a timed parry (-1 = none).
var _parry_at: int = -1
var _punish_checked_swing: int = -1
# Side changes (the player crossed over / rolled through): a human-like pause
# before the AI turns and acts on it. It never predicts the landing spot.
var _last_side: int = 0
var _side_wait: int = 0
var _rng := RandomNumberGenerator.new()


func setup(me: Fighter, target: Fighter) -> void:
	_me = me
	_target = target
	_rng.seed = rng_seed
	if _me != null and _me.style != null:
		preferred_range = _me.style.ai_preferred_range
	# Forget everything from a previous setup (restart / unlock at FIGHT).
	_plan.clear()
	_plan_index = 0
	_last_side = 0
	_side_wait = 0
	_parry_at = -1
	_dodge_now = false
	_block_low = false
	_was_stunned = false
	_enter(AIState.IDLE, 40)


func get_state_name() -> String:
	var text: String = AIState.keys()[_state]
	if _state == AIState.ATTACK:
		text += " %d/%d" % [_plan_index, _plan.size()]
	return "%s t%d" % [text, _timer]


func compute_intent() -> CombatData.Intent:
	var intent := CombatData.Intent.new()
	if _me == null or _target == null:
		return intent
	if not _me.can_be_hit() and not (_me.state == Fighter.State.KNOCKDOWN or _me.state == Fighter.State.GETUP):
		return intent  # KO or in a finisher: no control
	if _target.state == Fighter.State.KO or _target.state == Fighter.State.FINISHED:
		return intent
	var dx := _target.position.x - _me.position.x
	var dist := absf(dx)
	var toward: int = 1 if dx > 0.0 else -1
	_timer -= 1

	if _me.state == Fighter.State.HITSTUN or _me.state == Fighter.State.BLOCKSTUN \
			or _me.state == Fighter.State.KNOCKDOWN or _me.state == Fighter.State.GETUP \
			or _me.state == Fighter.State.STAGGER or _me.state == Fighter.State.BROKEN:
		if not _was_stunned:
			_was_stunned = true
			_plan.clear()
		intent.block = _state == AIState.BLOCK
		return intent
	if _was_stunned:
		_was_stunned = false
		_after_stun()

	var side := toward
	if _last_side != 0 and side != _last_side:
		_side_wait = reaction_frames + _rng.randi_range(2, 6)
		_plan.clear()
	_last_side = side
	if _side_wait > 0:
		_side_wait -= 1
		intent.block = _state == AIState.BLOCK  # a raised guard stays up (facing the old way)
		return intent

	# Anti-air: one roll per player jump, as they come down within reach.
	if not _target.airborne:
		_anti_air_rolled = false
	elif not _anti_air_rolled and _target.velocity_y > 0.0 and dist < 100.0 and _me.can_act():
		_anti_air_rolled = true
		var aa := _first_legal([CombatData.AttackType.UPPERCUT, CombatData.AttackType.HIGH_KICK,
			CombatData.AttackType.FRONT_KICK, CombatData.AttackType.LIGHT])
		if _rng.randf() < anti_air_chance and aa != CombatData.AttackType.NONE:
			_enter(AIState.SPACING, 20)
			intent.attack = aa
			return intent

	# Signature: at full Focus, in range, sometimes (never a guaranteed hit: it
	# has a long startup the player can read, block, parry or dodge).
	if _me.focus >= CombatData.FOCUS_MAX and _me.style != null and _me.style.signature != &"" and _me.can_act():
		var sig := CombatData.get_attack(CombatData.type_for_id(_me.style.signature))
		var reach := sig.hitbox.end.x + sig.lunge * sig.startup
		if dist < reach and dist > 50.0 and _rng.randf() < signature_chance:
			intent.signature = true
			_enter(AIState.SPACING, 30)
			return intent

	# Punish: the opponent was parried (staggering) or guard-broken. A broken
	# guard is always punished; a stagger is one roll per parried swing.
	if _target.state == Fighter.State.BROKEN and _state != AIState.ATTACK and dist < 140.0 and _me.can_act():
		_plan = _style_plan(dist < 100.0, [CombatData.AttackType.LIGHT, CombatData.AttackType.LIGHT, CombatData.AttackType.HEAVY] if dist < 100.0 \
			else [CombatData.AttackType.FRONT_KICK])
		_plan_index = 0
		_last_pressed_swing = _me.swing_id
		_parry_at = -1
		_enter(AIState.ATTACK, 60)
	elif _target.state == Fighter.State.BROKEN and _state != AIState.ATTACK and _me.can_act():
		_enter(AIState.APPROACH, 30)
	if _target.state == Fighter.State.STAGGER and _punish_checked_swing != _target.swing_id \
			and dist < 130.0 and (_me.can_act() or _me.state == Fighter.State.PARRY):
		_punish_checked_swing = _target.swing_id
		if _rng.randf() < punish_chance:
			_plan = _style_plan(dist < 100.0, [CombatData.AttackType.LIGHT, CombatData.AttackType.HEAVY] if dist < 100.0 \
				else [CombatData.AttackType.KICK])
			_plan_index = 0
			_last_pressed_swing = _me.swing_id
			_parry_at = -1
			_enter(AIState.ATTACK, 60)

	# Timed parry in progress: press block (a fresh press) on the chosen tick.
	if _parry_at >= 0:
		if _target.state != Fighter.State.ATTACK or _target.get_phase() != Fighter.Phase.STARTUP:
			_parry_at = -1
		elif _target.state_frame >= _parry_at:
			_parry_at = -1
			_block_low = _target.current_attack != null and _target.current_attack.low
			_enter(AIState.BLOCK, _rng.randi_range(12, 20))
			intent.parry = true
		else:
			return intent  # waiting, guard down on purpose

	# Reactive defense: notice the player's attack a few ticks into its startup.
	if _state != AIState.ATTACK and _target.get_phase() == Fighter.Phase.STARTUP \
			and _target.state_frame == reaction_frames and dist < 150.0:
		var roll := _rng.randf()
		var startup := _target.current_attack.startup if _target.current_attack != null else 0
		if roll < parry_chance and startup >= reaction_frames + 2:
			_parry_at = startup - 2
			return intent
		roll = _rng.randf()
		# Guard nearly broken: prefer getting out of the way over blocking.
		var fragile := _me.posture > CombatData.POSTURE_MAX * 0.7
		if fragile and roll < 0.6:
			_dodge_now = true
			_enter(AIState.SPACING, _rng.randi_range(10, 20))
		elif roll < block_chance:
			# Sweeps must be blocked low.
			_block_low = _target.current_attack != null and _target.current_attack.low
			_enter(AIState.BLOCK, _rng.randi_range(18, 30))
		elif roll < block_chance + dodge_chance:
			_dodge_now = true
			_enter(AIState.SPACING, _rng.randi_range(10, 20))

	match _state:
		AIState.IDLE:
			if _timer <= 0:
				_think(dist)
		AIState.APPROACH:
			intent.move = toward
			if dist <= preferred_range or _timer <= 0:
				_think(dist)
		AIState.SPACING:
			# Pressure: close in steadily, only give ground when crowded.
			if dist < preferred_range - 25.0:
				intent.move = -toward
			elif dist > preferred_range + 10.0:
				intent.move = toward
			if _timer <= 0:
				_think(dist)
		AIState.RETREAT:
			intent.move = -toward
			if _timer <= 0:
				_think(dist)
		AIState.BLOCK:
			intent.block = true
			intent.crouch = _block_low
			if _timer <= 0:
				_block_low = false
				_think(dist)
		AIState.ATTACK:
			intent.attack = _next_attack()
			if _timer <= 0:
				_think(dist)
		AIState.JUMP_IN:
			intent.move = toward
			if not _jump_pressed:
				intent.jump = true
				_jump_pressed = true
			elif _me.airborne and not _kick_pressed and _me.velocity_y > -4.0:
				# Kick (or sometimes punch) from just before the peak so it is
				# still active on the way down.
				# A slot, so the style picks its own air attack (or none).
				intent.slot = &"kick" if _rng.randf() < 0.65 else &"light"
				_kick_pressed = true
			elif not _me.airborne and _me.state != Fighter.State.JUMP:
				_enter(AIState.IDLE, _rng.randi_range(2, 6))
			if _timer <= 0:
				_think(dist)
	if _dodge_now:
		_dodge_now = false
		intent.dodge = -toward  # backstep away from the attack
	return intent


func _next_attack() -> CombatData.AttackType:
	if _plan_index >= _plan.size():
		if _me.state != Fighter.State.ATTACK:
			_enter(AIState.SPACING if _rng.randf() < 0.6 else AIState.RETREAT, _rng.randi_range(12, 30))
		return CombatData.AttackType.NONE
	# First press from neutral; follow-ups once the current swing leaves startup,
	# so they land in the input buffer and chain during the cancel window.
	var can_press := false
	if _plan_index == 0:
		can_press = _me.can_act() or _me.state == Fighter.State.PARRY
	elif _me.can_act():
		# The chain did not happen (whiffed, or not a listed branch): carry on
		# with the plan from neutral rather than stalling.
		can_press = true
	else:
		can_press = _me.state == Fighter.State.ATTACK and _me.swing_id != _last_pressed_swing \
				and _me.get_phase() != Fighter.Phase.STARTUP
	if not can_press:
		return CombatData.AttackType.NONE
	_last_pressed_swing = _me.swing_id
	var type: CombatData.AttackType = _plan[_plan_index]
	_plan_index += 1
	return type


func _think(dist: float) -> void:
	if not _me.can_act():
		_enter(AIState.IDLE, 3)
		return
	if not _target.can_be_hit():
		# Opponent is down or getting up: hang back instead of whiffing on them.
		_enter(AIState.SPACING, _rng.randi_range(10, 20))
		return
	var roll := _rng.randf()
	if dist > preferred_range + 40.0:
		if dist < 230.0 and roll < jump_in_chance:
			_jump_pressed = false
			_kick_pressed = false
			_enter(AIState.JUMP_IN, 70)
		elif roll < 0.75:
			_enter(AIState.APPROACH, _rng.randi_range(40, 90))
		else:
			_enter(AIState.SPACING, _rng.randi_range(20, 40))
		return
	if roll < aggression:
		_start_plan(dist)
	elif roll < aggression + 0.15:
		_enter(AIState.BLOCK, _rng.randi_range(20, 40))
	elif roll < aggression + 0.21:
		_enter(AIState.RETREAT, _rng.randi_range(8, 16))
	else:
		_enter(AIState.SPACING, _rng.randi_range(15, 35))


func _start_plan(dist: float) -> void:
	var far := dist > maxf(preferred_range + 10.0, 105.0)
	_plan = _style_plan(not far, (FAR_PLANS if far else CLOSE_PLANS)[_rng.randi_range(0, (FAR_PLANS if far else CLOSE_PLANS).size() - 1)])
	_plan_index = 0
	_last_pressed_swing = _me.swing_id
	_enter(AIState.ATTACK, 150)


## A random plan from the fighter's style (close or far), or `fallback` when
## the fighter has no style.
func _style_plan(close: bool, fallback: Array) -> Array:
	if _me.style == null:
		return fallback.duplicate()
	var pool := _me.style.plans(close)
	if pool.is_empty():
		pool = _me.style.plans(not close)
	return (pool[_rng.randi_range(0, pool.size() - 1)] as Array).duplicate() if not pool.is_empty() else []


## The first of `candidates` this fighter's style allows (NONE if none).
func _first_legal(candidates: Array) -> CombatData.AttackType:
	for c in candidates:
		if _me.style == null or _me.style.allows(c):
			return c
	return CombatData.AttackType.NONE


func _after_stun() -> void:
	var roll := _rng.randf()
	if roll < 0.35:
		_enter(AIState.BLOCK, _rng.randi_range(15, 25))
	elif roll < 0.55:
		_enter(AIState.RETREAT, _rng.randi_range(15, 25))
	else:
		_enter(AIState.IDLE, _rng.randi_range(4, 10))


func _enter(new_state: AIState, duration: int) -> void:
	_state = new_state
	_timer = duration
