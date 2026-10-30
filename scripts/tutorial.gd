class_name Tutorial
extends RefCounted
## Beginner learning path, run inside the training ground: one short,
## actionable step at a time, each finished by actually doing it (walk in, land
## a light and a heavy hit, block a punch, block a sweep low, land a chain, use
## the signature). N skips a step, U replays from the start, Esc leaves.
## Key names follow the player's bindings. TrainingMode calls in.

enum Step { MOVE, LIGHT, HEAVY, BLOCK, LOW_BLOCK, CHAIN, SIGNATURE, DONE }

## How close counts as "in reach" for the walk-in step (px between bodies).
const REACH: float = 150.0
## The attacking dummy (block steps) swings this often while in reach.
const SWING_EVERY: int = 75
## Blocks needed to clear each block step.
const BLOCKS_NEEDED: int = 2

var step: Step = Step.MOVE
var player: Fighter = null
var dummy: Fighter = null
## Progress inside the current step (blocks made so far).
var count: int = 0
## Ticks since the step started (paces the dummy's swings).
var _ticks: int = 0
## The dummy's style before the low-block step borrowed Kung Fu's sweep.
var _dummy_style: MartialArtStyle = null


func _init(p: Fighter, d: Fighter) -> void:
	player = p
	dummy = d


func restart() -> void:
	_set_step(Step.MOVE)


func skip() -> void:
	if step != Step.DONE:
		_set_step((step + 1) as Step)


func is_done() -> bool:
	return step == Step.DONE


func _set_step(next: Step) -> void:
	if step == Step.LOW_BLOCK and next != Step.LOW_BLOCK and _dummy_style != null:
		dummy.set_style(_dummy_style)
		_dummy_style = null
	step = next
	count = 0
	_ticks = 0
	dummy.stop_combat()
	if step == Step.LOW_BLOCK:
		# Kung Fu's S+K is a true low sweep: block it crouching.
		_dummy_style = dummy.style
		dummy.set_style(StyleRegistry.by_id(&"kung_fu"))
	if step == Step.SIGNATURE:
		player.focus = CombatData.FOCUS_MAX


func _key(action: StringName) -> String:
	return "[color=#f2c14e]%s[/color]" % GameSettings.key_label(action)


func _slot(slot: StringName) -> String:
	return "[color=#f2c14e]%s[/color]" % MartialArtStyle.slot_key(slot)


## Step title ("STEP 2 / 7  -  LAND A HIT") and the instruction under it.
func text() -> Array[String]:
	var total := Step.DONE
	var title := "STEP %d / %d  -  " % [step + 1, total]
	match step:
		Step.MOVE:
			return [title + "MOVE IN", "Walk toward the dummy with %s (%s walks back) until you are in reach." % [
				_key(&"move_right") if player.facing == 1 else _key(&"move_left"),
				_key(&"move_left") if player.facing == 1 else _key(&"move_right")]]
		Step.LIGHT:
			return [title + "LIGHT ATTACK", "Press %s for a quick light attack. Land one on the dummy." % _slot(&"light")]
		Step.HEAVY:
			return [title + "HEAVY ATTACK", "%s is slower but hits harder. Land a heavy attack." % _slot(&"heavy")]
		Step.BLOCK:
			return [title + "BLOCK", "The dummy punches now. Hold %s to block. Blocked: %d / %d" % [
				_key(&"block"), count, BLOCKS_NEEDED]]
		Step.LOW_BLOCK:
			return [title + "LOW BLOCK", "Sweeps hit low and go under a standing guard. Hold %s + %s to block low. Blocked: %d / %d" % [
				_key(&"mod_down"), _key(&"block"), count, BLOCKS_NEEDED]]
		Step.CHAIN:
			return [title + "CHAIN", "Attacks chain when pressed in rhythm: %s, %s, %s. Land a 3-hit combo." % [
				_slot(&"light"), _slot(&"light"), _slot(&"heavy")]]
		Step.SIGNATURE:
			return [title + "FOCUS", "Landing hits fills Focus (the bar under your health). It is full now: press %s for your signature move." % _key(&"signature")]
	return ["TUTORIAL COMPLETE", "Keep practising here, %s to replay the tutorial, or Esc to go back and START MATCH." % "[color=#f2c14e]U[/color]"]


## The dummy's controls in the block steps: walk into reach, then swing a
## punch (BLOCK) or a low sweep (LOW_BLOCK) every SWING_EVERY ticks.
## Returns null when the tutorial does not drive the dummy this step.
func dummy_intent() -> CombatData.Intent:
	if step != Step.BLOCK and step != Step.LOW_BLOCK:
		return null
	var it := CombatData.Intent.new()
	var gap := absf(player.position.x - dummy.position.x)
	if gap > 110.0:
		it.move = 1 if player.position.x > dummy.position.x else -1
	elif _ticks % SWING_EVERY == 0 and dummy.can_act() and dummy.style != null:
		it.attack = dummy.style.resolve(&"light" if step == Step.BLOCK else &"down_heavy", false)
	return it


func after_tick() -> void:
	_ticks += 1
	match step:
		Step.MOVE:
			if absf(player.position.x - dummy.position.x) <= REACH:
				_set_step(Step.LIGHT)
		Step.SIGNATURE:
			if player.in_signature:
				_set_step(Step.DONE)


func on_hit(result: CombatData.HitResult, attacker: Fighter, defender: Fighter, attack: CombatData.Attack) -> void:
	if attacker == player and result == CombatData.HitResult.HIT and player.style != null:
		match step:
			Step.LIGHT:
				if attack.type == player.style.resolve(&"light", false):
					_set_step(Step.HEAVY)
			Step.HEAVY:
				if attack.type == player.style.resolve(&"heavy", false):
					_set_step(Step.BLOCK)
			Step.CHAIN:
				if defender.received_combo >= 3:
					_set_step(Step.SIGNATURE)
	elif defender == player and result in [CombatData.HitResult.BLOCKED, CombatData.HitResult.PARRIED]:
		if step == Step.BLOCK or (step == Step.LOW_BLOCK and attack.low):
			count += 1
			if count >= BLOCKS_NEEDED:
				_set_step((step + 1) as Step)
