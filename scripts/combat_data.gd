class_name CombatData
extends RefCounted
## Combat tuning tables and shared value types.
##
## Pure data: no scene or node dependencies. All durations are measured in
## fixed simulation ticks (TICK_RATE per second), never in render frames.

## JUMP_KICK / JUMP_PUNCH are never pressed directly: any kick or punch button
## while airborne becomes one of them.
## APPEND-ONLY: never reorder or remove values (saves and style data refer to
## moves by their permanent string "id", resolved through type_for_id()).
enum AttackType { NONE, LIGHT, HEAVY, KICK, FRONT_KICK, BACKHAND, UPPERCUT, JUMP_KICK, JUMP_PUNCH, SWEEP, HIGH_KICK, BACK_KICK,
	LEAD_HOOK, REAR_HOOK, BODY_HOOK, OVERHAND, SLIP_COUNTER,
	AXE_KICK, SPIN_HOOK_KICK, JUMP_ROUNDHOUSE, JUMP_SPIN_KICK }
enum HitResult { WHIFF, HIT, BLOCKED, KO, PARRIED, GUARD_BREAK }

const TICK_RATE: int = 60

## How long a pressed attack stays queued waiting for the fighter to be able to act.
const INPUT_BUFFER_FRAMES: int = 10
## Maximum attacks in one chain (start + two cancels).
const MAX_COMBO_CHAIN: int = 3
## The last hit of a full chain sends the opponent further and stuns longer.
const FINISHER_KNOCKBACK_MULT: float = 1.7
const FINISHER_HITSTUN_BONUS: int = 8
## Each hit beyond MAX_COMBO_CHAIN in one combo stuns this many ticks less, so juggles and
## restarted chains cannot loop forever.
const COMBO_HITSTUN_DECAY: int = 3
const MIN_COMBO_HITSTUN: int = 6
const BLOCK_KNOCKBACK_MULT: float = 0.6
## Raising the guard takes this long before hits are blocked; dropping it (or
## acting out of it) costs BLOCK_RELEASE_FRAMES of recovery.
const BLOCK_STARTUP_FRAMES: int = 2
const BLOCK_RELEASE_FRAMES: int = 6
const BLOCK_HITSTOP_FRAMES: int = 3
const KO_HITSTOP_FRAMES: int = 20

## Perfect parry. A fresh Shift press opens a parry window for the first
## PARRY_WINDOW_FRAMES ticks of the guard (including its startup). A hit that
## lands inside it is deflected: no damage, the attacker staggers and the
## defender can counter at once. Holding Shift after the window is a normal block.
## Anti-spam:
##   - after a parry attempt, no new window opens for PARRY_COOLDOWN_FRAMES
##     (pressing again just blocks, with the normal startup);
##   - letting go (or attacking) within PARRY_WHIFF_FRAMES of an unused
##     attempt costs PARRY_WHIFF_RECOVERY ticks instead of BLOCK_RELEASE_FRAMES.
const PARRY_WINDOW_FRAMES: int = 4
## A Shift press stays valid this long while the fighter can't raise the guard yet.
const PARRY_BUFFER_FRAMES: int = 4
const PARRY_COOLDOWN_FRAMES: int = 30
const PARRY_WHIFF_FRAMES: int = 14
const PARRY_WHIFF_RECOVERY: int = 14
const PARRY_HITSTOP_FRAMES: int = 9
## Attacker reels this long after being parried: enough for any counter to land.
const PARRY_STAGGER_FRAMES: int = 24
## Defender's deflect motion; any buffered attack cancels it (the counter).
const PARRY_DEFLECT_FRAMES: int = 8
const PARRY_PUSHBACK: float = 3.5

## Posture (structure): a meter separate from health. It fills when you block
## (by each attack's own "posture" value, not its damage), when your attack is
## parried, and when you are hit while staggered or mid-startup (counter hit).
## Ordinary clean hits do not fill it: combos already have their own limits.
## It recovers after POSTURE_RECOVER_DELAY ticks without pressure (faster in
## neutral than while guarding). At POSTURE_MAX the guard breaks: BROKEN for
## POSTURE_BREAK_FRAMES (no blocking, no acting, a guaranteed punish). Any hit
## ends the break into normal hitstun. Afterwards posture is empty and cannot
## fill for POSTURE_LOCK_FRAMES, so breaks never loop.
const POSTURE_MAX: float = 100.0
const POSTURE_BLOCK_MULT: float = 1.0
const POSTURE_PARRIED_MULT: float = 1.5
const POSTURE_PARRIED_FLAT: float = 8.0
const POSTURE_COUNTER_MULT: float = 1.0
const POSTURE_RECOVER_DELAY: int = 90
const POSTURE_RECOVER_RATE: float = 0.4
const POSTURE_RECOVER_RATE_GUARD: float = 0.15
const POSTURE_BREAK_FRAMES: int = 54
const POSTURE_LOCK_FRAMES: int = 120
const GUARD_BREAK_HITSTOP_FRAMES: int = 12
## Counter hit (caught staggering or in an attack's startup): extra hitstun on
## top of the attack's own, plus extra hitstop for the feel of it.
const COUNTER_HITSTUN_BONUS: int = 6
const COUNTER_HITSTOP_BONUS: int = 2

## Jumping. Velocities in pixels per tick; gravity in pixels per tick².
## Falling uses stronger gravity than rising for a snappy, less floaty arc.
const JUMP_SQUAT_FRAMES: int = 2
const JUMP_VELOCITY: float = -15.0
const GRAVITY_RISE: float = 0.95
const GRAVITY_FALL: float = 1.35
const AIR_SPEED: float = 4.5
## Holding a direction in the air steers toward AIR_SPEED by this much per tick
## (either way, so jumps can be redirected). Releasing keeps the momentum.
const AIR_CONTROL: float = 0.3
const JUMP_BUFFER_FRAMES: int = 4

## Dodge / step (double-tap A or D): a backstep sway away from the opponent or a
## slip-in toward them. Invulnerable for a window in the middle; an attack
## buffered during the dodge fires the moment it ends (counter opportunity).
const DODGE_FRAMES: int = 16
const DODGE_INVULN_START: int = 2
const DODGE_INVULN_END: int = 11
const DODGE_MOVE_FRAMES: int = 10
const DODGE_BACK_SPEED: float = 8.5
const DODGE_FORWARD_SPEED: float = 7.0
const DODGE_BUFFER_FRAMES: int = 4
## Back kick: away + L from standing. Away must be pressed at most
## BACK_KICK_PRESS_WINDOW ticks before L, after at least BACK_KICK_STILL_TICKS
## without moving, so a retreating fighter's L stays a side kick.
const BACK_KICK_PRESS_WINDOW: int = 3
const BACK_KICK_STILL_TICKS: int = 6
## Slip past: a forward dodge (double-tap toward) started within
## SLIP_PAST_RANGE of a standing opponent slips through to their other side,
## landing SLIP_PAST_BEYOND px past their centre. Same frames and i-frames as
## the dodge; it passes through the pushbox only while it moves.
const SLIP_PAST_RANGE: float = 80.0
const SLIP_PAST_BEYOND: float = 64.0
## Evasive roll (hold S + double-tap A/D): a committed tuck roll, longer than
## the dodge step. A forward roll passes through the opponent's pushbox while
## travelling. Phases in ticks: startup (tuck), travel, recovery (rise).
## Invulnerable only for ROLL_INVULN_START <= frame < ROLL_INVULN_END.
const ROLL_STARTUP: int = 4
const ROLL_TRAVEL: int = 16
const ROLL_RECOVERY: int = 9
const ROLL_FORWARD_DIST: float = 170.0
const ROLL_BACK_DIST: float = 130.0
const ROLL_INVULN_START: int = 3
const ROLL_INVULN_END: int = 15
## Cross-ups: a fighter whose feet are this high above the other's passes over
## their pushbox. After a jump lands or a roll ends, overlap is resolved for
## CROSS_RESOLVE_TICKS by moving only that fighter toward the side its centre
## is on, at most CROSS_RESOLVE_STEP px per tick (smooth, no teleport).
const CROSSUP_CLEARANCE: float = 60.0
const CROSS_RESOLVE_STEP: float = 6.0
const CROSS_RESOLVE_TICKS: int = 10
## Facing only flips once the centres are this far apart (no flicker when
## one fighter is directly above the other).
const FACING_HYSTERESIS: float = 8.0
## Two taps of the same direction within this many ticks = dodge.
const DOUBLE_TAP_WINDOW: int = 12
const LANDING_FRAMES: int = 3
const LANDING_FRAMES_AFTER_AIR_ATTACK: int = 7
## Knockdown: the Nth consecutive hit of a combo knocks the opponent off their feet.
## They fly back, bounce once, lie down, then get up. Untouchable while down/rising.
const KNOCKDOWN_COMBO_HITS: int = 3
const KNOCKDOWN_LAUNCH_VELOCITY: float = -8.0
const KNOCKDOWN_DRIFT: float = 4.5
const KNOCKDOWN_BOUNCE_VELOCITY: float = -3.5
const KNOCKDOWN_LIE_FRAMES: int = 34
const GETUP_FRAMES: int = 26

## Blowback physics: strong hits can launch the opponent into a tumbling flight,
## off the wall, and into backward rolls along the floor.
## One roll covers this much floor (2 * PI * tucked body radius).
const ROLL_DISTANCE: float = 200.0
const ROLL_MIN_SPEED: float = 3.5
const ROLL_FRICTION: float = 0.97
## Rolling ends in a crouch, so the get-up is quicker than from lying flat.
const GETUP_FRAMES_AFTER_ROLL: int = 16
## A flying body hitting the arena wall faster than this bounces off it.
const WALL_BOUNCE_MIN_SPEED: float = 4.0
const WALL_BOUNCE_VELOCITY: float = -6.0
const WALL_BOUNCE_DAMPING: float = 0.45
## A body that lands with sideways speed and no rolls left skids along the
## floor, slowing by SKID_FRICTION each tick (a dust trail follows it).
const SKID_MIN_SPEED: float = 2.5
const SKID_FRICTION: float = 0.9
## Bodies flying through the air slow down slightly each tick.
const AIR_DRAG: float = 0.992

## Getting hit in the air pops the fighter up at least this much.
const AIR_HIT_POP_VELOCITY: float = -3.5

## Attack definitions.
##   startup / active / recovery: phase lengths in ticks.
##   cancel_window: ticks at the start of recovery during which a buffered
##                  attack chains into the next combo step.
##   hitbox: rect relative to the fighter's feet while facing right.
##   knockback, lunge: pixels per tick (knockback decays with friction).
##   posture: posture damage dealt to a blocker (see POSTURE_*); it reflects how
##            hard the strike is to absorb, not its health damage.
##   id: permanent move id used by style data (MartialArtStyle) and saves.
##   slip (optional): ticks of startup during which head-height strikes whiff
##                    (the head is moved off the line: slip counters).
##   air (optional): airborne-only move. spin (optional): the body turns its
##                   back through the move (visual turn, like the back kick).
##   launch (optional): upward velocity given to a grounded opponent on hit.
##   knockdown (optional): a clean hit always knocks down (sweeps).
##   blowback_* (optional): chance that a clean hit sends the opponent flying
##     (vx, vy in px/tick) into a knockdown with `blowback_rolls` floor rolls.
##     The 3rd-hit combo knockdown also uses these values when present.
const ATTACK_TABLE: Dictionary = {
	AttackType.LIGHT: {
		"id": &"jab", "name": "Jab", "posture": 6.0,
		"startup": 5, "active": 3, "recovery": 11, "cancel_window": 9,
		"damage": 6, "hitstun": 16, "blockstun": 10,
		"knockback": 2.5, "lunge": 0.8, "hitstop": 4,
		"hitbox": Rect2(28.0, -150.0, 52.0, 26.0),
	},
	AttackType.HEAVY: {
		"id": &"cross", "name": "Cross", "posture": 14.0,
		"startup": 11, "active": 3, "recovery": 20, "cancel_window": 8,
		"damage": 13, "hitstun": 22, "blockstun": 14,
		"knockback": 6.0, "lunge": 2.0, "hitstop": 7,
		"blowback_chance": 0.15, "blowback_vx": 7.0, "blowback_vy": -6.0, "blowback_rolls": 0,
		"hitbox": Rect2(36.0, -154.0, 62.0, 30.0),
	},
	AttackType.KICK: {
		"id": &"side_kick", "name": "Side Kick", "posture": 14.0,
		"startup": 9, "active": 4, "recovery": 17, "cancel_window": 8,
		"damage": 10, "hitstun": 18, "blockstun": 12,
		"knockback": 6.5, "lunge": 0.6, "hitstop": 6,
		"blowback_chance": 0.3, "blowback_vx": 8.0, "blowback_vy": -7.0, "blowback_rolls": 1,
		"hitbox": Rect2(40.0, -126.0, 62.0, 30.0),
	},
	# Push kick: quick, low damage, big push. Keeps the opponent out; fairly safe on block.
	AttackType.FRONT_KICK: {
		"id": &"front_kick", "name": "Front Kick", "posture": 16.0,
		"startup": 7, "active": 3, "recovery": 15, "cancel_window": 6,
		"damage": 8, "hitstun": 17, "blockstun": 13,
		"knockback": 9.0, "lunge": 1.2, "hitstop": 5,
		"blowback_chance": 0.4, "blowback_vx": 9.0, "blowback_vy": -5.5, "blowback_rolls": 1,
		"hitbox": Rect2(34.0, -94.0, 60.0, 30.0),
	},
	# Lead-hand backfist: quick snap to the head, slightly longer reach than the jab.
	AttackType.BACKHAND: {
		"id": &"backhand", "name": "Backhand", "posture": 7.0,
		"startup": 6, "active": 2, "recovery": 12, "cancel_window": 8,
		"damage": 7, "hitstun": 16, "blockstun": 11,
		"knockback": 3.0, "lunge": 1.0, "hitstop": 4,
		"hitbox": Rect2(30.0, -162.0, 58.0, 28.0),
	},
	# Rear-hand rising punch: short reach, tall hitbox (anti-air), launches on hit.
	AttackType.UPPERCUT: {
		"id": &"uppercut", "name": "Uppercut", "posture": 12.0,
		"startup": 9, "active": 3, "recovery": 18, "cancel_window": 6,
		"damage": 12, "hitstun": 24, "blockstun": 14,
		"knockback": 2.0, "lunge": 2.0, "hitstop": 7, "launch": 8.0,
		"hitbox": Rect2(18.0, -200.0, 44.0, 80.0),
	},
	# Airborne only. Ends early on landing; never chains.
	AttackType.JUMP_KICK: {
		"id": &"jump_kick", "air": true, "name": "Jump Kick", "posture": 14.0,
		"startup": 4, "active": 8, "recovery": 12, "cancel_window": 0,
		"damage": 11, "hitstun": 20, "blockstun": 12,
		"knockback": 5.0, "lunge": 0.0, "hitstop": 6,
		"hitbox": Rect2(28.0, -82.0, 62.0, 36.0),
	},
	# Airborne only. Flying straight punch that carries forward momentum.
	AttackType.JUMP_PUNCH: {
		"id": &"jump_punch", "air": true, "name": "Jump Punch", "posture": 9.0,
		"startup": 3, "active": 6, "recovery": 10, "cancel_window": 0,
		"damage": 8, "hitstun": 18, "blockstun": 10,
		"knockback": 3.5, "lunge": 2.0, "hitstop": 5,
		"hitbox": Rect2(28.0, -150.0, 58.0, 72.0),
	},
	# Face-level kick (W + L): fast for a kick, high damage, unsafe on block.
	AttackType.HIGH_KICK: {
		"id": &"high_kick", "name": "High Kick", "posture": 16.0,
		"startup": 7, "active": 3, "recovery": 18, "cancel_window": 6,
		"damage": 12, "hitstun": 20, "blockstun": 14,
		"knockback": 5.5, "lunge": 0.8, "hitstop": 7,
		"blowback_chance": 0.2, "blowback_vx": 7.5, "blowback_vy": -7.5, "blowback_rolls": 1,
		"hitbox": Rect2(24.0, -182.0, 62.0, 40.0),
	},
	# Low rotational leg sweep (S + L): takes the legs out, always knocks down.
	AttackType.SWEEP: {
		"id": &"sweep", "name": "Sweep", "posture": 10.0,
		"startup": 10, "active": 3, "recovery": 19, "cancel_window": 0,
		"damage": 9, "hitstun": 24, "blockstun": 12,
		"knockback": 2.0, "lunge": 1.0, "hitstop": 6, "knockdown": true, "low": true,
		"blowback_vx": 2.5, "blowback_vy": -6.0,
		"hitbox": Rect2(30.0, -30.0, 82.0, 30.0),
	},
	# Spinning back kick (away + L from standing): turn the back, heel thrust.
	# Slow and very unsafe, but the strongest push in the game. Never chains.
	AttackType.BACK_KICK: {
		"id": &"back_kick", "name": "Back Kick", "posture": 18.0,
		"startup": 11, "active": 3, "recovery": 20, "cancel_window": 0,
		"damage": 13, "hitstun": 22, "blockstun": 15,
		"knockback": 8.0, "lunge": 0.8, "hitstop": 8,
		"blowback_chance": 0.35, "blowback_vx": 9.0, "blowback_vy": -6.0, "blowback_rolls": 1,
		"hitbox": Rect2(38.0, -128.0, 66.0, 36.0),
	},

	# --- Boxing -------------------------------------------------------------
	# Lead hook: short arc to the jaw from the lead hand. Fast, short reach.
	AttackType.LEAD_HOOK: {
		"id": &"lead_hook", "name": "Lead Hook", "posture": 10.0,
		"startup": 7, "active": 3, "recovery": 14, "cancel_window": 8,
		"damage": 9, "hitstun": 18, "blockstun": 12,
		"knockback": 4.5, "lunge": 1.0, "hitstop": 5,
		"hitbox": Rect2(20.0, -160.0, 52.0, 36.0),
	},
	# Rear hook: the power hook, hips and rear heel turning through.
	AttackType.REAR_HOOK: {
		"id": &"rear_hook", "name": "Rear Hook", "posture": 14.0,
		"startup": 10, "active": 3, "recovery": 19, "cancel_window": 7,
		"damage": 12, "hitstun": 21, "blockstun": 14,
		"knockback": 7.5, "lunge": 1.5, "hitstop": 8,
		"blowback_chance": 0.3, "blowback_vx": 8.0, "blowback_vy": -6.5, "blowback_rolls": 1,
		"hitbox": Rect2(20.0, -160.0, 56.0, 36.0),
	},
	# Body hook: dip and dig into the ribs. Heavy posture damage on a guard.
	AttackType.BODY_HOOK: {
		"id": &"body_hook", "name": "Body Hook", "posture": 16.0,
		"startup": 8, "active": 3, "recovery": 15, "cancel_window": 8,
		"damage": 10, "hitstun": 20, "blockstun": 12,
		"knockback": 5.5, "lunge": 1.2, "hitstop": 7,
		"hitbox": Rect2(22.0, -120.0, 52.0, 36.0),
	},
	# Overhand: looping rear hand over the top. Slow, big, an ender.
	AttackType.OVERHAND: {
		"id": &"overhand", "name": "Overhand", "posture": 18.0,
		"startup": 13, "active": 3, "recovery": 22, "cancel_window": 0,
		"damage": 15, "hitstun": 24, "blockstun": 16,
		"knockback": 9.0, "lunge": 2.2, "hitstop": 9,
		"blowback_chance": 0.45, "blowback_vx": 9.5, "blowback_vy": -7.0, "blowback_rolls": 1,
		"hitbox": Rect2(30.0, -170.0, 58.0, 40.0),
	},
	# Slip counter: the head slips off the line (head-height strikes whiff during
	# the first 8 ticks), then a straight rear hand.
	AttackType.SLIP_COUNTER: {
		"id": &"slip_counter", "name": "Slip Counter", "posture": 12.0,
		"startup": 10, "active": 3, "recovery": 16, "cancel_window": 6,
		"damage": 11, "hitstun": 22, "blockstun": 13,
		"knockback": 6.5, "lunge": 1.0, "hitstop": 8, "slip": 8,
		"blowback_chance": 0.2, "blowback_vx": 7.5, "blowback_vy": -6.0, "blowback_rolls": 0,
		"hitbox": Rect2(34.0, -156.0, 60.0, 30.0),
	},

	# --- Taekwondo ------------------------------------------------------------
	# Axe kick: the straight leg rises high and chops down onto the head/guard.
	AttackType.AXE_KICK: {
		"id": &"axe_kick", "name": "Axe Kick", "posture": 20.0,
		"startup": 12, "active": 3, "recovery": 20, "cancel_window": 0,
		"damage": 14, "hitstun": 22, "blockstun": 15,
		"knockback": 4.0, "lunge": 0.8, "hitstop": 8,
		"hitbox": Rect2(34.0, -178.0, 60.0, 66.0),
	},
	# Spinning hook kick: turn the back, the heel whips across at head height.
	AttackType.SPIN_HOOK_KICK: {
		"id": &"spin_hook_kick", "name": "Spinning Hook Kick", "posture": 16.0, "spin": true,
		"startup": 11, "active": 3, "recovery": 21, "cancel_window": 0,
		"damage": 14, "hitstun": 22, "blockstun": 15,
		"knockback": 7.0, "lunge": 1.0, "hitstop": 8,
		"blowback_chance": 0.3, "blowback_vx": 8.0, "blowback_vy": -7.0, "blowback_rolls": 1,
		"hitbox": Rect2(30.0, -186.0, 72.0, 42.0),
	},
	# Airborne only: a high roundhouse from a jump.
	AttackType.JUMP_ROUNDHOUSE: {
		"id": &"jump_roundhouse", "name": "Jump Roundhouse", "posture": 12.0, "air": true,
		"startup": 4, "active": 6, "recovery": 12, "cancel_window": 0,
		"damage": 12, "hitstun": 20, "blockstun": 12,
		"knockback": 5.5, "lunge": 0.0, "hitstop": 6,
		"hitbox": Rect2(26.0, -150.0, 66.0, 46.0),
	},
	# Airborne only: a spinning back-heel kick in the air.
	AttackType.JUMP_SPIN_KICK: {
		"id": &"jump_spin_kick", "name": "Jumping Spin Kick", "posture": 14.0, "air": true, "spin": true,
		"startup": 6, "active": 5, "recovery": 14, "cancel_window": 0,
		"damage": 14, "hitstun": 22, "blockstun": 14,
		"knockback": 7.0, "lunge": 0.0, "hitstop": 8,
		"hitbox": Rect2(22.0, -122.0, 74.0, 52.0),
	},
}


## Combo branches: which attacks each attack may cancel into during its
## cancel_window. A cancel also needs the swing to have connected (hit or
## blocked); a whiffed attack always plays out its full recovery. Anything not
## listed waits for the recovery to end and starts a fresh chain.
## Heavy enders never repeat themselves (no cross -> cross, kick -> kick).
const CHAINS: Dictionary = {
	AttackType.LIGHT: [AttackType.LIGHT, AttackType.HEAVY, AttackType.BACKHAND, AttackType.UPPERCUT,
		AttackType.KICK, AttackType.FRONT_KICK, AttackType.HIGH_KICK, AttackType.SWEEP],
	AttackType.BACKHAND: [AttackType.LIGHT, AttackType.HEAVY, AttackType.UPPERCUT, AttackType.KICK, AttackType.HIGH_KICK],
	AttackType.HEAVY: [AttackType.KICK, AttackType.FRONT_KICK, AttackType.HIGH_KICK, AttackType.UPPERCUT, AttackType.SWEEP],
	# Launcher: follow the body up with quick strikes or a high kick.
	AttackType.UPPERCUT: [AttackType.LIGHT, AttackType.BACKHAND, AttackType.HIGH_KICK],
	AttackType.KICK: [AttackType.LIGHT, AttackType.BACKHAND, AttackType.HEAVY],
	# Push kick, then chase with a kick.
	AttackType.FRONT_KICK: [AttackType.KICK, AttackType.HIGH_KICK],
	AttackType.HIGH_KICK: [AttackType.LIGHT, AttackType.HEAVY],
}


static func can_chain(from: AttackType, to: AttackType) -> bool:
	return to in CHAINS.get(from, [])


class Attack extends RefCounted:
	var type: CombatData.AttackType = CombatData.AttackType.NONE
	var display_name: String = ""
	var startup: int = 0
	var active: int = 0
	var recovery: int = 0
	var cancel_window: int = 0
	var damage: int = 0
	var hitstun: int = 0
	var blockstun: int = 0
	var knockback: float = 0.0
	var lunge: float = 0.0
	var hitstop: int = 0
	var posture: float = 0.0
	var launch: float = 0.0
	var knockdown: bool = false
	## Low attacks can only be blocked crouching (low block).
	var low: bool = false
	var blowback_chance: float = 0.0
	var blowback_vx: float = 0.0
	var blowback_vy: float = 0.0
	var blowback_rolls: int = 0
	var hitbox: Rect2 = Rect2()
	## Permanent move id (style data, saves).
	var id: StringName = &""
	## Ticks of startup during which head-height strikes whiff (slip counters).
	var slip_frames: int = 0
	var air_only: bool = false
	## Visual: the body turns its back through the move.
	var spin: bool = false

	func total_frames() -> int:
		return startup + active + recovery


## What a controller (keyboard or AI) wants a fighter to do this tick.
class Intent extends RefCounted:
	var move: int = 0
	var block: bool = false
	var jump: bool = false
	## World direction of a requested dodge (-1 left, +1 right, 0 none).
	var dodge: int = 0
	## Crouch held (S): crouch, or low block together with block.
	var crouch: bool = false
	## Player input slot (light, heavy, kick, up_kick, ...): the fighter resolves
	## it through its martial-art style. AI and tests set `attack` directly.
	var slot: StringName = &""
	## Block was freshly pressed this tick: a parry attempt (see PARRY_*).
	var parry: bool = false
	var attack: CombatData.AttackType = CombatData.AttackType.NONE


static var _attack_cache: Dictionary = {}


static func get_attack(type: AttackType) -> Attack:
	if _attack_cache.has(type):
		return _attack_cache[type]
	var row: Dictionary = ATTACK_TABLE[type]
	var attack := Attack.new()
	attack.type = type
	attack.display_name = row["name"]
	attack.startup = row["startup"]
	attack.active = row["active"]
	attack.recovery = row["recovery"]
	attack.cancel_window = row["cancel_window"]
	attack.damage = row["damage"]
	attack.hitstun = row["hitstun"]
	attack.blockstun = row["blockstun"]
	attack.knockback = row["knockback"]
	attack.lunge = row["lunge"]
	attack.hitstop = row["hitstop"]
	attack.posture = row["posture"]
	attack.launch = row.get("launch", 0.0)
	attack.knockdown = row.get("knockdown", false)
	attack.low = row.get("low", false)
	attack.blowback_chance = row.get("blowback_chance", 0.0)
	attack.blowback_vx = row.get("blowback_vx", 0.0)
	attack.blowback_vy = row.get("blowback_vy", 0.0)
	attack.blowback_rolls = row.get("blowback_rolls", 0)
	attack.hitbox = row["hitbox"]
	attack.id = row["id"]
	attack.slip_frames = row.get("slip", 0)
	attack.air_only = row.get("air", false)
	attack.spin = row.get("spin", false)
	_attack_cache[type] = attack
	return attack


static var _id_lookup: Dictionary = {}


## Move by permanent id (NONE if unknown).
static func type_for_id(move_id: StringName) -> AttackType:
	if _id_lookup.is_empty():
		for t in ATTACK_TABLE:
			_id_lookup[ATTACK_TABLE[t]["id"]] = t
	return _id_lookup.get(move_id, AttackType.NONE)


static func id_for_type(type: AttackType) -> StringName:
	return ATTACK_TABLE[type]["id"] if ATTACK_TABLE.has(type) else &""


static func attack_name(type: AttackType) -> String:
	return AttackType.keys()[type]
