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
	AXE_KICK, SPIN_HOOK_KICK, JUMP_ROUNDHOUSE, JUMP_SPIN_KICK,
	GAZELLE_HOOK, TORNADO_540,
	ELBOW, KNEE, LOW_ROUNDHOUSE, BODY_ROUNDHOUSE, FLYING_KNEE,
	REVERSE_PUNCH, KNIFE_HAND, RISING_PUNCH, SPIN_COUNTER_KICK, PERFECT_GYAKU,
	STRAIGHT_PALM, DOUBLE_PALM, LOW_SIDE_KICK, RISING_PALM, CHAIN_PALMS, DEFLECT_COUNTER, PALM_BARRAGE,
	BREAKER_COMBO,
	BOB_WEAVE, RISING_ELBOW, BODY_STRAIGHT, BODY_PUNCH, LOW_PALM, LEG_FEINT,
	POWER_UPPERCUT, SUPERMAN_PUNCH, JUMPING_ELBOW, FLYING_KNEE_FACE, JUMPING_REVERSE_PUNCH, FLYING_SIDE_KICK,
	LEAPING_PALM, FLYING_DOUBLE_PALM, JUMPING_BACKFIST, JUMPING_SPIN_HOOK, LEAPING_ROUNDHOUSE,
	LEAPING_SPIN_BACKFIST, FLYING_AXE_KICK,
	LIGHT_SLAP, THRUST_KICK, DOUBLE_PUSH, HEAD_ELBOW, HAMMER_FIST, STOMACH_SHOT, PARA_LEG_KICK,
	DOUBLE_KICK, DOUBLE_KICK_LOW, DOUBLE_KICK_MID,
	JOR_DHAKKA,
	FLYING_SLAP, FLYING_CHEST_KICK, BELLY_BOMB, STREET_PUNCH,
	DEMPSEY_ROLL, DEMPSEY_HOOK_LEFT, DEMPSEY_HOOK_RIGHT, RETREATING_JUMP_ELBOW,
	STEP_BACK_SPINNING_BACKFIST, BUTTERFLY_KICK, TRIPLE_KICK, TRIPLE_KICK_BODY_ONE,
	TRIPLE_KICK_BODY_TWO, TRIPLE_KICK_HEAD, BIG_FOOT, DROPKICK, SCORPION_KICK, THAI_ROUNDHOUSE }
enum HitResult { WHIFF, HIT, BLOCKED, KO, PARRIED, GUARD_BREAK }
## Step-in (px of root motion through the startup, front-loaded into its late
## part): strikes travel into range like real footwork instead of being thrown
## from a standing spot. Punches step and drag (the planted feet step front
## then rear); kicks skip in a little. Blocked by the opponent's body.
const STEP_IN: Dictionary = {
	&"jab": 18.0, &"cross": 14.0, &"backhand": 12.0, &"uppercut": 8.0,
	&"lead_hook": 10.0, &"rear_hook": 10.0, &"body_hook": 12.0, &"overhand": 22.0, &"slip_counter": 12.0,
	&"elbow": 8.0, &"knee": 12.0, &"reverse_punch": 26.0, &"knife_hand": 16.0, &"rising_punch": 8.0,
	&"perfect_gyaku": 32.0, &"straight_palm": 18.0, &"double_palm": 22.0, &"rising_palm": 8.0,
	&"chain_palms": 10.0, &"side_kick": 14.0, &"front_kick": 12.0, &"high_kick": 6.0,
	&"body_roundhouse": 8.0, &"low_roundhouse": 6.0, &"low_side_kick": 12.0, &"axe_kick": 8.0,
	&"rising_elbow": 8.0, &"body_straight": 14.0, &"body_punch": 20.0, &"low_palm": 14.0,
	&"light_slap": 14.0, &"street_punch": 14.0, &"thrust_kick": 10.0, &"double_push": 14.0, &"jor_dhakka": 14.0, &"head_elbow": 10.0, &"hammer_fist": 16.0,
	&"stomach_shot": 12.0, &"leg_kick": 8.0,
}
## A grounded strike stops travelling (step-in and lunge) once the opponent is
## within the move's own reach plus this margin, so the limb arrives extended
## instead of the bodies crowding together. Reach and hits are unchanged.
const STRIKE_RANGE_MARGIN: float = 14.0
## Step-in profile: no travel before this fraction of the startup.
const STEP_IN_START: float = 0.2
## How a strike travels into the target (presentation: impact direction, the
## victim's reaction). Body and leg hits are told apart by where they land.
enum ImpactKind { STRAIGHT, HOOK, RISING, DOWNWARD }

const TICK_RATE: int = 60
const X_COOLDOWN_FRAMES: int = 600

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
## Space + J / Space + K (power chord): the two presses may come in either
## order within this many ticks. For a style with power moves a fresh jump
## stays in its squat until the window has passed, so a chord never starts
## as a normal jump; J or K pressed first converts while still in startup.
const POWER_CHORD_WINDOW: int = 6
## Dizzy (stun): a clean hit from a move with `stun` leaves the opponent dizzy
## for that many ticks after its hit reaction (1-2 s). Dizzy fighters cannot
## act or guard; each hit taken while dizzy drains DIZZY_HIT_DRAIN ticks; the
## last DIZZY_RECOVER_FRAMES are the shake-off. A player can mash buttons to
## recover sooner (DIZZY_MASH per press, never below the shake-off). After
## recovering, no new stun for DIZZY_IMMUNITY_FRAMES.
const DIZZY_RECOVER_FRAMES: int = 22
const DIZZY_HIT_DRAIN: int = 18
const DIZZY_MASH: int = 3
const DIZZY_IMMUNITY_FRAMES: int = 180
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
## Focus (shared by every style): earned by fighting well, spent on the style's
## signature technique (F at FOCUS_MAX). It never decays during a match and is
## never earned during finishers or from signature hits. Blocking pays at most
## once per FOCUS_BLOCK_COOLDOWN ticks, so turtling cannot farm it.
## Taking a clean hit also fills it (FOCUS_HURT_PER_DAMAGE per point of
## damage taken): the fighter being beaten up builds toward a comeback, but at
## most FOCUS_HURT_WINDOW_MAX within any FOCUS_HURT_WINDOW ticks, so one long
## combo cannot hand over a whole meter. Tuned for ~one signature per fighter
## per round (rounds of ~30 s at MATCH_HEALTH, main.gd).
const FOCUS_MAX: float = 100.0
const FOCUS_HURT_PER_DAMAGE: float = 0.3
const FOCUS_HURT_WINDOW: int = 120
const FOCUS_HURT_WINDOW_MAX: float = 12.0
const FOCUS_LIGHT: float = 3.0
const FOCUS_HEAVY: float = 6.0
const FOCUS_KICK: float = 5.0
const FOCUS_COUNTER: float = 9.0
const FOCUS_PARRY: float = 14.0
const FOCUS_PERFECT_DODGE: float = 8.0
const FOCUS_BLOCK: float = 2.0
const FOCUS_BLOCK_COOLDOWN: int = 30
## F stays valid this long while the fighter cannot act yet.
const SIGNATURE_BUFFER_FRAMES: int = 8
## Sequence moves: the next strike starts this many ticks after the previous
## strike's active frames end.
const SEQUENCE_GAP: int = 3
## Two taps of the same direction (A A / D D) within this many ticks = dash.
const DOUBLE_TAP_WINDOW: int = 12
const LANDING_FRAMES: int = 3
const LANDING_FRAMES_AFTER_AIR_ATTACK: int = 7
## Knockdown: the Nth consecutive hit of a combo knocks the opponent off their feet.
## They fly back, bounce once, lie down, then get up. Untouchable while down/rising.
const KNOCKDOWN_COMBO_HITS: int = 4
## A heavy hit's random blowback (chance under 1) needs this many hits in the
## combo (or a counter hit); certain blowbacks (1.0) always apply.
const BLOWBACK_MIN_COMBO: int = 2
## Scales every uncertain blowback chance (the per-move values stay as authored
## relative weights); certain ones (1.0) are untouched.
const BLOWBACK_CHANCE_SCALE: float = 0.5
const KNOCKDOWN_LAUNCH_VELOCITY: float = -8.0
const KNOCKDOWN_DRIFT: float = 4.5
const KNOCKDOWN_BOUNCE_VELOCITY: float = -3.5
## A body landing slower than this (px/tick) settles without bouncing; up to
## BOUNCE_HARD_IMPACT it rebounds by restitution alone; harder falls get at
## least KNOCKDOWN_BOUNCE_VELOCITY (the arcade slam).
const BOUNCE_MIN_IMPACT: float = 5.0
const BOUNCE_HARD_IMPACT: float = 10.0
const BOUNCE_RESTITUTION: float = 0.4
const KNOCKDOWN_LIE_FRAMES: int = 34
const GETUP_FRAMES: int = 26

## Blowback physics: strong hits can launch the opponent into a tumbling flight,
## off the wall, and into backward rolls along the floor.
## Radius of the tucked (balled) body: the drawing rolls about its centre
## without slipping, so one roll covers 2 * PI * this much floor.
const BALL_RADIUS: float = 32.0
const ROLL_DISTANCE: float = TAU * BALL_RADIUS
const ROLL_MIN_SPEED: float = 3.5
## A knockdown roll starts at least this fast and decelerates evenly to rest
## on a whole revolution (it never crawls at a constant speed).
const ROLL_START_SPEED: float = 7.5
const ROLL_END_SPEED: float = 1.2
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
## Voluntary jumps (Space) have their own arc, so knockbacks, launches, power
## leaps and finishers keep the shared gravity above. Targets: apex ~100 px
## (low enough for jump-in punches to reach the head) with a short hang at the
## top (|vy| < JUMP_APEX_BAND), a firmer fall, about 30 ticks in the air;
## ~135 px forward, ~95 px back.
## Momentum rule: holding the travel direction keeps full speed; releasing
## keeps the momentum, bleeding JUMP_RELEASE_DRAG per tick; reversing steers at
## JUMP_REVERSE_CONTROL (can stop and drift back, never snap round).
const JUMP_LAUNCH: float = -14.0
const JUMP_GRAVITY_RISE: float = 0.92
const JUMP_GRAVITY_FALL: float = 1.45
const JUMP_APEX_BAND: float = 2.0
const JUMP_APEX_GRAVITY: float = 0.45
const JUMP_SPEED_FORWARD: float = 4.2
const JUMP_SPEED_BACK: float = 3.0
const JUMP_RELEASE_DRAG: float = 0.985
const JUMP_REVERSE_CONTROL: float = 0.22

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
##   rehit (optional): the hitbox re-arms every N active ticks (multi-hit).
##   deflect (optional, with slip): every strike that is not low whiffs during
##                    the slip window (hand deflections), not only head strikes.
##   leap / leap_at / leap_vx (optional): the move leaves the ground on tick
##                    leap_at (default 2) with vertical speed `leap` and
##                    forward speed leap_vx (default 2.5) px/tick. Landing ends
##                    it, followed by land_lag ticks of landing recovery.
##   stun (optional): ticks of dizzy on a clean hit (see DIZZY_*).
##   backstep / backstep_ticks (optional): px stepped back over the first
##                    ticks of the startup (a run-up, e.g. the Belly Bomb).
##   guard_break (optional): a blocked hit breaks the guard outright (parries
##                    still beat it; not while the guard is locked after a break).
##   bounce (optional): on contact the attacker rebounds off the target;
##                    hit_land_lag then replaces the (long) whiff landing.
##   no_strike (optional): a technique with no hitbox of its own (a weave, a
##                    feint); it cancels into its chains without needing contact.
##   sequence (optional): this move is a series of other moves (by id), each
##                    with its own frame data and contact window; started one
##                    after another automatically, interrupted by being hit.
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
		"id": &"overhand", "name": "Overhand", "stun": 75, "posture": 18.0, "overhead": true,
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

	# --- Signatures (F at full Focus; never in a combo, never on a key) ------
	# Boxing: Gazelle Hook. An explosive forward step from a crouch into a
	# rising lead hook. Huge stagger; badly punishable if it misses.
	AttackType.GAZELLE_HOOK: {
		"id": &"gazelle_hook", "name": "Gazelle Hook", "posture": 30.0, "signature": true,
		"startup": 12, "active": 4, "recovery": 26, "cancel_window": 0,
		"damage": 22, "hitstun": 30, "blockstun": 18,
		"knockback": 9.0, "lunge": 4.0, "hitstop": 12,
		"blowback_chance": 1.0, "blowback_vx": 9.0, "blowback_vy": -9.0, "blowback_rolls": 1,
		"hitbox": Rect2(18.0, -178.0, 62.0, 62.0),
	},
	# Taekwondo: 540 Tornado Kick. Leap, one and a half turns in the air, a
	# head-height kick at the end of the spin. Long landing on a miss.
	AttackType.TORNADO_540: {
		"id": &"tornado_540", "name": "540 Tornado Kick", "posture": 28.0, "signature": true,
		"spin": true, "spin_turns": 1.5, "leap": -12.0, "land_lag": 18,
		"startup": 14, "active": 5, "recovery": 28, "cancel_window": 0,
		"damage": 24, "hitstun": 30, "blockstun": 18,
		"knockback": 10.0, "lunge": 1.5, "hitstop": 12,
		"blowback_chance": 1.0, "blowback_vx": 10.0, "blowback_vy": -9.0, "blowback_rolls": 2,
		# Relative to the feet at the top of the leap (~70 px up): head height.
		"hitbox": Rect2(22.0, -128.0, 82.0, 60.0),
	},

	# --- Taekwondo ------------------------------------------------------------
	# Axe kick: the straight leg rises high and chops down onto the head/guard.
	AttackType.AXE_KICK: {
		"id": &"axe_kick", "name": "Axe Kick", "stun": 75, "posture": 20.0, "overhead": true,
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
	# --- Muay Thai -------------------------------------------------------------
	# Elbow: short, sharp, rear elbow turning through. Close range only.
	AttackType.ELBOW: {
		"id": &"elbow", "name": "Elbow", "posture": 14.0,
		"startup": 6, "active": 3, "recovery": 14, "cancel_window": 8,
		"damage": 11, "hitstun": 20, "blockstun": 13,
		"knockback": 4.0, "lunge": 1.2, "hitstop": 7,
		"hitbox": Rect2(14.0, -166.0, 46.0, 42.0),
	},
	# Knee: driven up into the body.
	AttackType.KNEE: {
		"id": &"knee", "name": "Knee", "posture": 16.0,
		"startup": 8, "active": 3, "recovery": 16, "cancel_window": 7,
		"damage": 12, "hitstun": 22, "blockstun": 14,
		"knockback": 5.5, "lunge": 1.5, "hitstop": 7,
		"hitbox": Rect2(16.0, -126.0, 48.0, 50.0),
	},
	# Low roundhouse: shin into the thigh. A low attack (block it low).
	AttackType.LOW_ROUNDHOUSE: {
		"id": &"low_roundhouse", "name": "Low Kick", "posture": 14.0, "low": true,
		"startup": 8, "active": 3, "recovery": 16, "cancel_window": 7,
		"damage": 9, "hitstun": 18, "blockstun": 12,
		"knockback": 3.5, "lunge": 0.8, "hitstop": 6,
		"hitbox": Rect2(30.0, -72.0, 64.0, 42.0),
	},
	# Body roundhouse: shin into the ribs, hips turned over.
	AttackType.BODY_ROUNDHOUSE: {
		"id": &"body_roundhouse", "name": "Body Kick", "posture": 18.0,
		"startup": 9, "active": 3, "recovery": 18, "cancel_window": 7,
		"damage": 12, "hitstun": 20, "blockstun": 14,
		"knockback": 6.5, "lunge": 0.8, "hitstop": 7,
		"blowback_chance": 0.2, "blowback_vx": 7.0, "blowback_vy": -6.0, "blowback_rolls": 1,
		"hitbox": Rect2(32.0, -132.0, 66.0, 42.0),
	},
	# Signature: Flying Knee. Leap in, knee to the head.
	AttackType.FLYING_KNEE: {
		"id": &"flying_knee", "name": "Flying Knee", "posture": 34.0, "signature": true,
		"leap": -10.0, "land_lag": 16,
		"startup": 11, "active": 5, "recovery": 24, "cancel_window": 0,
		"damage": 24, "hitstun": 30, "blockstun": 18,
		"knockback": 9.0, "lunge": 3.0, "hitstop": 12,
		"blowback_chance": 1.0, "blowback_vx": 9.0, "blowback_vy": -9.0, "blowback_rolls": 1,
		# Relative to the feet at the top of the leap (~50 px up).
		"hitbox": Rect2(14.0, -112.0, 60.0, 62.0),
	},

	# --- Karate ----------------------------------------------------------------
	# Reverse punch (gyaku-zuki): rear hand, long stance, hips snap through.
	AttackType.REVERSE_PUNCH: {
		"id": &"reverse_punch", "name": "Reverse Punch", "posture": 14.0,
		"startup": 9, "active": 3, "recovery": 17, "cancel_window": 8,
		"damage": 12, "hitstun": 21, "blockstun": 14,
		"knockback": 6.0, "lunge": 2.5, "hitstop": 7,
		"hitbox": Rect2(36.0, -154.0, 64.0, 30.0),
	},
	# Knife-hand strike: the blade of the lead hand chops down to the neck.
	AttackType.KNIFE_HAND: {
		"id": &"knife_hand", "name": "Knife Hand", "posture": 10.0,
		"startup": 7, "active": 3, "recovery": 14, "cancel_window": 8,
		"damage": 9, "hitstun": 18, "blockstun": 12,
		"knockback": 3.5, "lunge": 1.0, "hitstop": 6,
		"hitbox": Rect2(26.0, -166.0, 54.0, 42.0),
	},
	# Rising punch: a straight-armed punch driving upward (launches).
	AttackType.RISING_PUNCH: {
		"id": &"rising_punch", "name": "Rising Punch", "posture": 12.0,
		"startup": 8, "active": 3, "recovery": 17, "cancel_window": 6,
		"damage": 11, "hitstun": 22, "blockstun": 13,
		"knockback": 2.5, "lunge": 1.5, "hitstop": 7, "launch": 7.0,
		"hitbox": Rect2(18.0, -198.0, 44.0, 78.0),
	},
	# Spinning counter kick: turning away slips head strikes, then the heel.
	AttackType.SPIN_COUNTER_KICK: {
		"id": &"spin_counter_kick", "name": "Spinning Counter Kick", "posture": 14.0, "spin": true, "slip": 7,
		"startup": 10, "active": 3, "recovery": 20, "cancel_window": 0,
		"damage": 13, "hitstun": 22, "blockstun": 14,
		"knockback": 7.0, "lunge": 0.8, "hitstop": 8,
		"blowback_chance": 0.3, "blowback_vx": 8.0, "blowback_vy": -6.0, "blowback_rolls": 1,
		"hitbox": Rect2(30.0, -152.0, 70.0, 42.0),
	},
	# Signature: Perfect Gyaku-Zuki. Rooted stance, heel drive, hip snap.
	AttackType.PERFECT_GYAKU: {
		"id": &"perfect_gyaku", "name": "Perfect Gyaku-Zuki", "posture": 45.0, "signature": true,
		"startup": 14, "active": 3, "recovery": 26, "cancel_window": 0,
		"damage": 22, "hitstun": 30, "blockstun": 20,
		"knockback": 10.0, "lunge": 3.0, "hitstop": 14,
		"blowback_chance": 1.0, "blowback_vx": 10.0, "blowback_vy": -6.0, "blowback_rolls": 1,
		"hitbox": Rect2(34.0, -158.0, 70.0, 36.0),
	},

	# --- Kung Fu ----------------------------------------------------------------
	AttackType.STRAIGHT_PALM: {
		"id": &"straight_palm", "name": "Straight Palm", "posture": 7.0,
		"startup": 5, "active": 3, "recovery": 12, "cancel_window": 9,
		"damage": 6, "hitstun": 16, "blockstun": 10,
		"knockback": 3.0, "lunge": 1.0, "hitstop": 4,
		"hitbox": Rect2(28.0, -154.0, 54.0, 32.0),
	},
	AttackType.DOUBLE_PALM: {
		"id": &"double_palm", "name": "Double Palm", "posture": 18.0,
		"startup": 11, "active": 4, "recovery": 20, "cancel_window": 0,
		"damage": 12, "hitstun": 22, "blockstun": 15,
		"knockback": 9.0, "lunge": 2.0, "hitstop": 8,
		"blowback_chance": 0.35, "blowback_vx": 9.0, "blowback_vy": -5.0, "blowback_rolls": 1,
		"hitbox": Rect2(28.0, -152.0, 58.0, 52.0),
	},
	# Low side kick: stamping side kick to the knee (block it low).
	AttackType.LOW_SIDE_KICK: {
		"id": &"low_side_kick", "name": "Low Side Kick", "posture": 12.0, "low": true,
		"startup": 8, "active": 3, "recovery": 16, "cancel_window": 7,
		"damage": 9, "hitstun": 18, "blockstun": 12,
		"knockback": 5.0, "lunge": 0.8, "hitstop": 6,
		"hitbox": Rect2(36.0, -64.0, 66.0, 36.0),
	},
	AttackType.RISING_PALM: {
		"id": &"rising_palm", "name": "Rising Palm", "posture": 12.0,
		"startup": 9, "active": 3, "recovery": 18, "cancel_window": 6,
		"damage": 11, "hitstun": 22, "blockstun": 13,
		"knockback": 2.5, "lunge": 1.5, "hitstop": 7, "launch": 7.5,
		"hitbox": Rect2(18.0, -198.0, 44.0, 78.0),
	},
	# Chain palms: three quick alternating palms in one move (each can land).
	AttackType.CHAIN_PALMS: {
		"id": &"chain_palms", "name": "Chain Palms", "posture": 5.0, "rehit": 3,
		"startup": 6, "active": 9, "recovery": 14, "cancel_window": 6,
		"damage": 4, "hitstun": 14, "blockstun": 8,
		"knockback": 1.5, "lunge": 1.2, "hitstop": 3,
		"hitbox": Rect2(26.0, -154.0, 54.0, 36.0),
	},
	# Deflection counter: the lead forearm turns aside any strike that is not
	# low during the first 8 ticks, then the rear palm answers.
	AttackType.DEFLECT_COUNTER: {
		"id": &"deflect_counter", "name": "Deflection Counter", "posture": 12.0, "slip": 8, "deflect": true,
		"startup": 10, "active": 3, "recovery": 16, "cancel_window": 6,
		"damage": 11, "hitstun": 22, "blockstun": 13,
		"knockback": 5.5, "lunge": 1.5, "hitstop": 7,
		"hitbox": Rect2(30.0, -152.0, 58.0, 38.0),
	},
	# Signature: Flowing Palm Barrage. Three palms flowing into a double palm.
	# A sequence: each strike is its own move with its own contact window.
	AttackType.PALM_BARRAGE: {
		"id": &"palm_barrage", "name": "Flowing Palm Barrage", "posture": 0.0, "signature": true,
		"sequence": [&"straight_palm", &"straight_palm", &"straight_palm", &"double_palm"],
		"startup": 5, "active": 3, "recovery": 12, "cancel_window": 0,
		"damage": 0, "hitstun": 0, "blockstun": 0,
		"knockback": 0.0, "lunge": 1.0, "hitstop": 0,
		"hitbox": Rect2(28.0, -154.0, 54.0, 32.0),
	},

	# --- Kickboxing --------------------------------------------------------------
	# Signature: Breaker Combination. Jab, cross, low kick, high roundhouse.
	AttackType.BREAKER_COMBO: {
		"id": &"breaker_combo", "name": "Breaker Combination", "posture": 0.0, "signature": true,
		"sequence": [&"jab", &"cross", &"low_roundhouse", &"high_kick"],
		"startup": 5, "active": 3, "recovery": 11, "cancel_window": 0,
		"damage": 0, "hitstun": 0, "blockstun": 0,
		"knockback": 0.0, "lunge": 0.8, "hitstop": 0,
		"hitbox": Rect2(28.0, -150.0, 52.0, 26.0),
	},

	# --- Style techniques (L) and level-changing strikes (S + J) ----------------
	# Bob and weave (Boxing L): sink at the knees and roll the head under in a
	# U; head-height strikes pass over the whole dip. No strike of its own: it
	# flows straight into a counter (its chains) as the head comes back up.
	AttackType.BOB_WEAVE: {
		"id": &"bob_weave", "name": "Bob and Weave", "posture": 0.0, "no_strike": true, "slip": 18,
		"startup": 6, "active": 10, "recovery": 8, "cancel_window": 12,
		"damage": 0, "hitstun": 0, "blockstun": 0,
		"knockback": 0.0, "lunge": 0.4, "hitstop": 0,
		"hitbox": Rect2(20.0, -120.0, 40.0, 30.0),
	},
	# Lead-leg feint (Taekwondo L): the lead knee snaps up as if to kick and
	# drops back. No strike; it flows into a real kick (its chains) at once.
	AttackType.LEG_FEINT: {
		"id": &"lead_leg_feint", "name": "Lead-Leg Feint", "posture": 0.0, "no_strike": true,
		"startup": 5, "active": 6, "recovery": 8, "cancel_window": 12,
		"damage": 0, "hitstun": 0, "blockstun": 0,
		"knockback": 0.0, "lunge": 0.0, "hitstop": 0,
		"hitbox": Rect2(30.0, -120.0, 50.0, 30.0),
	},
	# Double kick (Taekwondo L): one press, two kicks with alternating legs.
	# The rear leg's low roundhouse to the lead thigh (5), that foot plants
	# forward and takes the weight, then the other leg's roundhouse to the ribs
	# (9). Timeline from the press: startup 9, low kick active ticks 9-11, a
	# 9-tick plant and weight transfer (SEQUENCE_GAP 3 + the mid kick's
	# startup 6), mid kick active ticks 21-23, recovery 20 (ends at tick 44).
	# The second kick follows whether the first lands, whiffs or is blocked; an
	# interrupted attacker drops it. Mid-sequence hits never knock down.
	AttackType.DOUBLE_KICK: {
		"id": &"double_kick", "name": "Double Kick", "posture": 0.0,
		"sequence": [&"double_kick_low", &"double_kick_mid"],
		"startup": 9, "active": 3, "recovery": 20, "cancel_window": 0,
		"damage": 0, "hitstun": 0, "blockstun": 0,
		"knockback": 0.0, "lunge": 0.0, "hitstop": 0,
		"hitbox": Rect2(30.0, -72.0, 64.0, 42.0),
	},
	AttackType.DOUBLE_KICK_LOW: {
		"id": &"double_kick_low", "name": "Double Kick (low)", "posture": 8.0, "low": true,
		"startup": 9, "active": 3, "recovery": 12, "cancel_window": 0,
		"damage": 5, "hitstun": 20, "blockstun": 16,
		"knockback": 1.5, "lunge": 0.6, "hitstop": 4,
		"hitbox": Rect2(30.0, -72.0, 64.0, 42.0),
	},
	AttackType.DOUBLE_KICK_MID: {
		"id": &"double_kick_mid", "name": "Double Kick (mid)", "posture": 14.0,
		"startup": 6, "active": 3, "recovery": 20, "cancel_window": 0,
		"damage": 9, "hitstun": 20, "blockstun": 14,
		"knockback": 5.5, "lunge": 1.0, "hitstop": 6,
		"hitbox": Rect2(32.0, -132.0, 66.0, 42.0),
	},
	# Rising elbow (Muay Thai W + J): the rear elbow driven up through the chin.
	AttackType.RISING_ELBOW: {
		"id": &"rising_elbow", "name": "Rising Elbow", "posture": 14.0,
		"startup": 8, "active": 3, "recovery": 17, "cancel_window": 6,
		"damage": 12, "hitstun": 22, "blockstun": 14,
		"knockback": 3.0, "lunge": 1.2, "hitstop": 7, "launch": 6.5,
		"hitbox": Rect2(14.0, -196.0, 46.0, 70.0),
	},
	# Body straight (Muay Thai S + J): level change, rear hand straight to the body.
	AttackType.BODY_STRAIGHT: {
		"id": &"body_straight", "name": "Body Straight", "posture": 14.0,
		"startup": 8, "active": 3, "recovery": 16, "cancel_window": 7,
		"damage": 10, "hitstun": 20, "blockstun": 13,
		"knockback": 5.5, "lunge": 1.5, "hitstop": 6,
		"hitbox": Rect2(34.0, -118.0, 60.0, 28.0),
	},
	# Body punch (Karate / Taekwondo S + J): chudan gyaku-zuki, a reverse punch
	# from a deep front stance into the solar plexus.
	AttackType.BODY_PUNCH: {
		"id": &"body_punch", "name": "Body Punch", "posture": 12.0,
		"startup": 8, "active": 3, "recovery": 16, "cancel_window": 7,
		"damage": 10, "hitstun": 20, "blockstun": 13,
		"knockback": 5.0, "lunge": 2.0, "hitstop": 6,
		"hitbox": Rect2(36.0, -122.0, 62.0, 28.0),
	},
	# Low palm (Kung Fu S + J): sink into a horse stance, lead palm to the belly.
	AttackType.LOW_PALM: {
		"id": &"low_palm", "name": "Low Palm", "posture": 10.0,
		"startup": 7, "active": 3, "recovery": 15, "cancel_window": 8,
		"damage": 8, "hitstun": 18, "blockstun": 12,
		"knockback": 4.5, "lunge": 1.2, "hitstop": 5,
		"hitbox": Rect2(30.0, -116.0, 56.0, 30.0),
	},

	# --- Power chords (Space + J / Space + K) -------------------------------------
	# Leaping moves: hitboxes are relative to the feet at the height the fighter
	# has reached on the first active tick (head- or body-level on a standing
	# opponent). Landing ends the move; the landing recovery then runs out the
	# move's own startup + active + recovery (see Fighter._land).
	# Power uppercut (Boxing Space + J): grounded. Sit deep, rear glove dropped,
	# then the whole body drives up through the fist. Launches on hit.
	AttackType.POWER_UPPERCUT: {
		"id": &"power_uppercut", "name": "Crouching Power Uppercut", "posture": 18.0,
		"startup": 12, "active": 4, "recovery": 24, "cancel_window": 0,
		"damage": 16, "hitstun": 26, "blockstun": 16,
		"knockback": 3.0, "lunge": 1.6, "hitstop": 9, "launch": 10.5,
		"hitbox": Rect2(30.0, -176.0, 48.0, 76.0),
	},
	# Superman punch (Boxing / Kickboxing Space + K): rear knee feints a kick,
	# the leg snaps back and the body flies forward behind a rear straight.
	AttackType.SUPERMAN_PUNCH: {
		"id": &"superman_punch", "name": "Superman Punch", "stun": 60, "posture": 16.0,
		"leap": -7.0, "leap_at": 4, "leap_vx": 6.5,
		"startup": 10, "active": 4, "recovery": 21, "cancel_window": 0,
		"damage": 13, "hitstun": 22, "blockstun": 15,
		"knockback": 7.0, "lunge": 0.0, "hitstop": 8,
		"blowback_chance": 0.25, "blowback_vx": 8.0, "blowback_vy": -6.0, "blowback_rolls": 0,
		"hitbox": Rect2(54.0, -150.0, 54.0, 44.0),
	},
	# Jumping elbow (Muay Thai Space + J): leap in, rear elbow chops down on the head.
	AttackType.JUMPING_ELBOW: {
		"id": &"jumping_elbow", "name": "Jumping Downward Elbow", "stun": 80, "posture": 20.0,
		"leap": -9.0, "leap_at": 3, "leap_vx": 5.0,
		"startup": 9, "active": 4, "recovery": 23, "cancel_window": 0,
		"damage": 14, "hitstun": 24, "blockstun": 16,
		"knockback": 5.0, "lunge": 0.0, "hitstop": 9,
		"hitbox": Rect2(27.0, -145.0, 54.0, 52.0),
	},
	# Flying knee to the face (Muay Thai Space + K): hands reach for the head,
	# the rear knee drives up into the face.
	AttackType.FLYING_KNEE_FACE: {
		"id": &"flying_knee_face", "name": "Flying Knee to Face", "stun": 70, "posture": 22.0,
		"leap": -10.0, "leap_at": 4, "leap_vx": 5.0,
		"startup": 12, "active": 5, "recovery": 25, "cancel_window": 0,
		"damage": 16, "hitstun": 26, "blockstun": 16,
		"knockback": 6.0, "lunge": 0.0, "hitstop": 10,
		"blowback_chance": 0.35, "blowback_vx": 7.5, "blowback_vy": -8.0, "blowback_rolls": 1,
		"hitbox": Rect2(4.0, -136.0, 54.0, 50.0),
	},
	# Jumping reverse punch (Karate Space + J): tucked leap, rear fist driven
	# straight to the head with the lead fist pulled back to the hip.
	AttackType.JUMPING_REVERSE_PUNCH: {
		"id": &"jumping_reverse_punch", "name": "Jumping Reverse Punch", "stun": 60, "posture": 14.0,
		"leap": -8.0, "leap_at": 3, "leap_vx": 4.5,
		"startup": 10, "active": 4, "recovery": 22, "cancel_window": 0,
		"damage": 12, "hitstun": 22, "blockstun": 14,
		"knockback": 6.0, "lunge": 0.0, "hitstop": 8,
		"hitbox": Rect2(48.0, -155.0, 54.0, 44.0),
	},
	# Flying side kick (Karate Space + K): tight chamber, then the lead heel
	# spears out level at head height with the body laid back behind it.
	AttackType.FLYING_SIDE_KICK: {
		"id": &"flying_side_kick", "name": "Flying Side Kick", "stun": 70, "posture": 20.0,
		"leap": -10.0, "leap_at": 3, "leap_vx": 6.0,
		"startup": 11, "active": 5, "recovery": 23, "cancel_window": 0,
		"damage": 14, "hitstop": 9, "hitstun": 24, "blockstun": 16,
		"knockback": 8.0, "lunge": 0.0,
		"blowback_chance": 0.35, "blowback_vx": 9.0, "blowback_vy": -6.5, "blowback_rolls": 1,
		"hitbox": Rect2(40.0, -127.0, 64.0, 40.0),
	},
	# Leaping palm (Kung Fu Space + J): a low quick bound, lead palm to the chest.
	AttackType.LEAPING_PALM: {
		"id": &"leaping_palm", "name": "Leaping Palm Strike", "posture": 12.0,
		"leap": -6.5, "leap_at": 2, "leap_vx": 5.5,
		"startup": 8, "active": 4, "recovery": 19, "cancel_window": 0,
		"damage": 10, "hitstun": 20, "blockstun": 13,
		"knockback": 5.0, "lunge": 0.0, "hitstop": 6,
		"hitbox": Rect2(41.0, -120.0, 54.0, 44.0),
	},
	# Flying double palm (Kung Fu Space + K): both palms drawn to the hips in
	# the air, then driven together into the chest. Big push.
	AttackType.FLYING_DOUBLE_PALM: {
		"id": &"flying_double_palm", "name": "Flying Double-Palm Strike", "posture": 20.0,
		"leap": -7.5, "leap_at": 4, "leap_vx": 5.0,
		"startup": 12, "active": 4, "recovery": 24, "cancel_window": 0,
		"damage": 14, "hitstun": 24, "blockstun": 16,
		"knockback": 9.5, "lunge": 0.0, "hitstop": 9,
		"blowback_chance": 0.45, "blowback_vx": 9.5, "blowback_vy": -5.5, "blowback_rolls": 1,
		"hitbox": Rect2(50.0, -121.0, 58.0, 46.0),
	},
	# Leaping spinning backfist (Kung Fu Space + J): dip and coil, a small leap
	# turning the back, the rear fist whips round at head height, then the
	# rotation completes into a controlled landing.
	AttackType.LEAPING_SPIN_BACKFIST: {
		"id": &"leaping_spin_backfist", "name": "Leaping Spinning Backfist", "stun": 60, "posture": 12.0, "spin": true,
		"leap": -7.0, "leap_at": 3, "leap_vx": 4.0,
		"startup": 9, "active": 3, "recovery": 19, "cancel_window": 0,
		"damage": 12, "hitstun": 22, "blockstun": 14,
		"knockback": 5.5, "lunge": 0.0, "hitstop": 8,
		"hitbox": Rect2(36.0, -157.0, 56.0, 44.0),
	},
	# Flying axe kick (Kung Fu Space + K): leap up, chamber the knee, the leg
	# rises straight at the apex and the heel chops down onto the head.
	# Heavy guard damage; long landing recovery.
	AttackType.FLYING_AXE_KICK: {
		"id": &"flying_axe_kick", "name": "Flying Axe Kick", "stun": 100, "posture": 32.0, "overhead": true,
		"leap": -10.0, "leap_at": 4, "leap_vx": 4.5,
		"startup": 12, "active": 5, "recovery": 25, "cancel_window": 0,
		"damage": 17, "hitstun": 26, "blockstun": 18,
		"knockback": 5.0, "lunge": 0.0, "hitstop": 11,
		"hitbox": Rect2(52.0, -126.0, 58.0, 50.0),
	},
	# --- Bangla Maar (para street fighting, a parody style) -----------------------
	# Light slap: a quick open palm across the cheek.
	AttackType.LIGHT_SLAP: {
		"id": &"light_slap", "name": "Light Slap", "posture": 6.0,
		"startup": 5, "active": 2, "recovery": 11, "cancel_window": 9,
		"damage": 6, "hitstun": 16, "blockstun": 10,
		"knockback": 2.5, "lunge": 0.8, "hitstop": 5,
		"hitbox": Rect2(26.0, -162.0, 52.0, 30.0),
	},
	# Street punch (J): a loose, wide, unschooled lead-hand punch thrown with
	# the shoulder behind it and the chin up; same speed as the old slap.
	AttackType.STREET_PUNCH: {
		"id": &"street_punch", "name": "Street Punch", "posture": 6.0,
		"startup": 5, "active": 2, "recovery": 11, "cancel_window": 9,
		"damage": 6, "hitstun": 16, "blockstun": 10,
		"knockback": 2.8, "lunge": 1.0, "hitstop": 5,
		"hitbox": Rect2(26.0, -160.0, 54.0, 30.0),
	},
	# Front thrust kick: a flat-footed shove of a kick into the stomach.
	AttackType.THRUST_KICK: {
		"id": &"thrust_kick", "name": "Front Thrust Kick", "posture": 16.0,
		"startup": 9, "active": 4, "recovery": 18, "cancel_window": 6,
		"damage": 10, "hitstun": 19, "blockstun": 13,
		"knockback": 8.5, "lunge": 1.0, "hitstop": 6,
		"hitbox": Rect2(36.0, -118.0, 62.0, 32.0),
	},
	# Double-hand push: a two-palmed shove. Big push on a clean hit and a 20%
	# knockdown roll (blocked: reduced push, never a knockdown).
	AttackType.DOUBLE_PUSH: {
		"id": &"double_push", "name": "Double-Hand Push", "posture": 12.0,
		"startup": 10, "active": 4, "recovery": 22, "cancel_window": 0,
		"damage": 5, "hitstun": 20, "blockstun": 12,
		"knockback": 10.0, "lunge": 1.2, "hitstop": 6,
		"blowback_chance": 0.2, "blowback_vx": 7.5, "blowback_vy": -5.0, "blowback_rolls": 0,
		"hitbox": Rect2(24.0, -142.0, 56.0, 48.0),
	},
	# Jor Dhakka (Bangla Maar L): a reckless charging shoulder bash. Lean in,
	# brace, then drive forward shoulder-first: a bounded charge (lunge 4.5 px
	# a tick through startup + active, at most ~70 px) that stops on contact
	# ("charge": no chasing the body it just knocked away). One shoulder hit,
	# heavy knockback (reduced on block), no random knockdown; a long recovery
	# leaves it wide open on a miss.
	# Smashes straight through a raised guard (guard_break) and throws a cleanly
	# hit opponent off balance (off_balance: reeling, counter-hittable) on top
	# of the knockback. Slow to start and punishable on a miss.
	AttackType.JOR_DHAKKA: {
		"id": &"jor_dhakka", "name": "Jor Dhakka", "posture": 16.0, "charge": true, "guard_break": true,
		"off_balance": 40,
		"startup": 12, "active": 4, "recovery": 26, "cancel_window": 0,
		"damage": 11, "hitstun": 20, "blockstun": 14,
		"knockback": 14.0, "lunge": 4.5, "hitstop": 10,
		"hitbox": Rect2(4.0, -140.0, 40.0, 54.0),
	},
	# Head elbow: the rear elbow swung round at head height.
	AttackType.HEAD_ELBOW: {
		"id": &"head_elbow", "name": "Head Elbow", "posture": 14.0,
		"startup": 8, "active": 3, "recovery": 17, "cancel_window": 6,
		"damage": 11, "hitstun": 21, "blockstun": 13,
		"knockback": 4.5, "lunge": 1.2, "hitstop": 7,
		"hitbox": Rect2(14.0, -170.0, 48.0, 40.0),
	},
	# Double-hand hammer: both fists clasped high overhead, brought down on the
	# head. Bangla Maar's guard breaker: blocking it breaks the guard.
	AttackType.HAMMER_FIST: {
		"id": &"hammer_fist", "name": "Double-Hand Hammer", "stun": 80, "posture": 22.0, "guard_break": true, "overhead": true,
		"startup": 15, "active": 4, "recovery": 25, "cancel_window": 0,
		"damage": 15, "hitstun": 24, "blockstun": 16,
		"knockback": 6.5, "lunge": 1.5, "hitstop": 10,
		"hitbox": Rect2(26.0, -172.0, 56.0, 56.0),
	},
	# Stomach shot: a dipping rear-hand punch to the belly.
	AttackType.STOMACH_SHOT: {
		"id": &"stomach_shot", "name": "Stomach Shot", "posture": 10.0,
		"startup": 7, "active": 3, "recovery": 14, "cancel_window": 8,
		"damage": 8, "hitstun": 18, "blockstun": 11,
		"knockback": 4.0, "lunge": 1.2, "hitstop": 5,
		"hitbox": Rect2(30.0, -118.0, 54.0, 30.0),
	},
	# Leg kick: a toe-poke to the shin (block it low).
	AttackType.PARA_LEG_KICK: {
		"id": &"leg_kick", "name": "Leg Kick", "posture": 12.0, "low": true,
		"startup": 9, "active": 3, "recovery": 17, "cancel_window": 6,
		"damage": 9, "hitstun": 18, "blockstun": 12,
		"knockback": 3.5, "lunge": 0.8, "hitstop": 6,
		"hitbox": Rect2(30.0, -62.0, 60.0, 36.0),
	},
	# Flying slap (Space + J): a hop and an open palm across the face.
	AttackType.FLYING_SLAP: {
		"id": &"flying_slap", "name": "Flying Slap", "posture": 12.0,
		"leap": -7.5, "leap_at": 3, "leap_vx": 5.0,
		"startup": 9, "active": 4, "recovery": 20, "cancel_window": 0,
		"damage": 11, "hitstun": 21, "blockstun": 13,
		"knockback": 5.0, "lunge": 0.0, "hitstop": 8,
		"hitbox": Rect2(40.0, -155.0, 54.0, 42.0),
	},
	# Flying chest kick (Space + K): a leap and a flat kick into the chest.
	AttackType.FLYING_CHEST_KICK: {
		"id": &"flying_chest_kick", "name": "Flying Chest Kick", "stun": 70, "posture": 20.0,
		"leap": -9.0, "leap_at": 4, "leap_vx": 5.5,
		"startup": 12, "active": 5, "recovery": 24, "cancel_window": 0,
		"damage": 14, "hitstun": 24, "blockstun": 16,
		"knockback": 8.0, "lunge": 0.0, "hitstop": 9,
		"blowback_chance": 0.3, "blowback_vx": 8.0, "blowback_vy": -6.0, "blowback_rolls": 1,
		"hitbox": Rect2(46.0, -110.0, 62.0, 40.0),
	},
	# Signature: Belly Bomb. Backstep, crouch, a forward leap belly-first into
	# the opponent, bounce off and land. Badly punishable if it misses.
	AttackType.BELLY_BOMB: {
		"id": &"belly_bomb", "name": "Belly Bomb", "posture": 30.0, "signature": true,
		"backstep": 34.0, "backstep_ticks": 8, "leap": -8.0, "leap_at": 14, "leap_vx": 11.0,
		"bounce": true, "hit_land_lag": 10,
		"startup": 20, "active": 6, "recovery": 32, "cancel_window": 0,
		"damage": 22, "hitstun": 30, "blockstun": 18,
		"knockback": 10.0, "lunge": 0.0, "hitstop": 12,
		"blowback_chance": 1.0, "blowback_vx": 11.0, "blowback_vy": -8.0, "blowback_rolls": 1,
		"hitbox": Rect2(4.0, -120.0, 58.0, 60.0),
	},
	# Jumping backfist (Taekwondo Space + J): lead fist folded across the chest
	# on the way up, whipped out to the temple at the top.
	AttackType.JUMPING_BACKFIST: {
		"id": &"jumping_backfist", "name": "Jumping Backfist", "posture": 10.0,
		"leap": -8.0, "leap_at": 3, "leap_vx": 4.0,
		"startup": 9, "active": 3, "recovery": 21, "cancel_window": 0,
		"damage": 11, "hitstun": 20, "blockstun": 13,
		"knockback": 4.5, "lunge": 0.0, "hitstop": 7,
		"hitbox": Rect2(41.0, -159.0, 54.0, 42.0),
	},
	# Jumping spinning hook kick (Taekwondo Space + K): leap and turn the back,
	# the rear heel whips across at head height.
	AttackType.JUMPING_SPIN_HOOK: {
		"id": &"jumping_spin_hook", "name": "Jumping Spinning Hook Kick", "stun": 80, "posture": 22.0, "spin": true,
		"leap": -9.5, "leap_at": 3, "leap_vx": 3.0,
		"startup": 15, "active": 5, "recovery": 27, "cancel_window": 0,
		"damage": 17, "hitstun": 26, "blockstun": 17,
		"knockback": 8.0, "lunge": 0.0, "hitstop": 10,
		"blowback_chance": 0.4, "blowback_vx": 9.0, "blowback_vy": -7.5, "blowback_rolls": 1,
		"hitbox": Rect2(36.0, -152.0, 66.0, 46.0),
	},
	# Jumping roundhouse (Kickboxing Space + K): knees tucked on the way up,
	# then the shin whips round at head height with the body leaning away.
	AttackType.LEAPING_ROUNDHOUSE: {
		"id": &"leaping_roundhouse", "name": "Jumping Roundhouse Kick", "stun": 75, "posture": 20.0,
		"leap": -9.0, "leap_at": 3, "leap_vx": 4.5,
		"startup": 11, "active": 4, "recovery": 24, "cancel_window": 0,
		"damage": 15, "hitstun": 24, "blockstun": 16,
		"knockback": 7.0, "lunge": 0.0, "hitstop": 9,
		"blowback_chance": 0.3, "blowback_vx": 8.0, "blowback_vy": -7.0, "blowback_rolls": 1,
		"hitbox": Rect2(36.0, -148.0, 62.0, 46.0),
	},
	AttackType.DEMPSEY_ROLL: {
		"id": &"dempsey_roll", "name": "Dempsey Roll", "x_move": true, "x_strike": false,
		"startup": 24, "active": 4, "recovery": 30, "cancel_window": 0,
		"damage": 0, "hitstun": 24, "blockstun": 16, "posture": 16.0,
		"knockback": 4.0, "lunge": 0.5, "hitstop": 8,
		"hitbox": Rect2(25.0, -170.0, 47.0, 65.0), "sequence": [&"dempsey_hook_left", &"dempsey_hook_right"],
	},
	AttackType.DEMPSEY_HOOK_LEFT: {
		"id": &"dempsey_hook_left", "name": "Dempsey Roll (lead hook)", "x_move": false, "x_strike": true,
		"startup": 24, "active": 4, "recovery": 10, "cancel_window": 0,
		"damage": 9, "hitstun": 24, "blockstun": 16, "posture": 16.0,
		"knockback": 1.0, "lunge": 1.0, "hitstop": 10, "impact_power": 2,
		"hitbox": Rect2(25.0, -170.0, 47.0, 65.0),
	},
	AttackType.DEMPSEY_HOOK_RIGHT: {
		"id": &"dempsey_hook_right", "name": "Dempsey Roll (rear hook)", "x_move": false, "x_strike": true,
		"startup": 8, "active": 4, "recovery": 30, "cancel_window": 0,
		"damage": 9, "hitstun": 24, "blockstun": 16, "posture": 16.0,
		"knockback": 16.0, "lunge": 1.0, "hitstop": 14, "impact_power": 3,
		"hitbox": Rect2(25.0, -170.0, 47.0, 65.0),
	},
	AttackType.RETREATING_JUMP_ELBOW: {
		"id": &"retreating_jump_elbow", "name": "Retreating Jump Elbow", "x_move": true, "x_strike": false,
		"startup": 26, "active": 5, "recovery": 32, "cancel_window": 0,
		"damage": 18, "hitstun": 24, "blockstun": 16, "posture": 16.0,
		"knockback": 6.0, "lunge": 0.0, "hitstop": 8,
		"hitbox": Rect2(22.0, -132.0, 34.0, 65.0), "backstep": 28.0, "backstep_ticks": 10, "leap": -9.0, "leap_at": 14, "leap_vx": 4.0,
	},
	AttackType.STEP_BACK_SPINNING_BACKFIST: {
		"id": &"step_back_spinning_backfist", "name": "Step-Back Spinning Backfist", "x_move": true, "x_strike": false,
		"startup": 18, "active": 5, "recovery": 32, "cancel_window": 0,
		"damage": 18, "hitstun": 24, "blockstun": 16, "posture": 16.0,
		"knockback": 14.0, "lunge": 4.0, "travel_start": 6, "impact_power": 3, "hitstop": 8,
		"hitbox": Rect2(28.0, -182.0, 66.0, 62.0), "backstep": 16.0, "backstep_ticks": 6, "spin": true,
	},
	AttackType.BUTTERFLY_KICK: {
		"id": &"butterfly_kick", "name": "Butterfly Kick", "x_move": true, "x_strike": false,
		"startup": 24, "active": 6, "recovery": 34, "cancel_window": 0,
		"damage": 18, "hitstun": 24, "blockstun": 16, "posture": 16.0,
		"knockback": 6.0, "lunge": 0.0, "hitstop": 8,
		"hitbox": Rect2(22.0, -130.0, 74.0, 65.0), "leap": -9.0, "leap_at": 14, "leap_vx": 2.0, "spin": true,
	},
	AttackType.TRIPLE_KICK: {
		"id": &"triple_kick", "name": "Triple Kick", "x_move": true, "x_cooldown_frames": 900, "x_strike": false,
		"startup": 12, "active": 3, "recovery": 24, "cancel_window": 0,
		"damage": 0, "hitstun": 24, "blockstun": 16, "posture": 16.0,
		"knockback": 4.0, "lunge": 0.5, "hitstop": 8,
		"hitbox": Rect2(28.0, -138.0, 50.0, 55.0), "sequence": [&"triple_kick_body_one", &"triple_kick_body_two", &"triple_kick_head"],
	},
	AttackType.TRIPLE_KICK_BODY_ONE: {
		"id": &"triple_kick_body_one", "name": "Triple Kick (first body)", "x_move": false, "x_strike": true,
		"startup": 12, "active": 3, "recovery": 8, "cancel_window": 0,
		"damage": 6, "hitstun": 24, "blockstun": 16, "posture": 16.0,
		"knockback": 0.5, "lunge": 1.0, "hitstop": 2, "sequence_gap": 1,
		"hitbox": Rect2(28.0, -138.0, 50.0, 55.0),
	},
	AttackType.TRIPLE_KICK_BODY_TWO: {
		"id": &"triple_kick_body_two", "name": "Triple Kick (second body)", "x_move": false, "x_strike": true,
		"startup": 3, "active": 3, "recovery": 8, "cancel_window": 0,
		"damage": 6, "hitstun": 24, "blockstun": 16, "posture": 16.0,
		"knockback": 0.5, "lunge": 1.0, "hitstop": 2, "sequence_gap": 1,
		"hitbox": Rect2(28.0, -138.0, 50.0, 55.0),
	},
	AttackType.TRIPLE_KICK_HEAD: {
		"id": &"triple_kick_head", "name": "Triple Kick (head)", "x_move": false, "x_strike": true,
		"startup": 3, "active": 4, "recovery": 24, "cancel_window": 0,
		"damage": 6, "hitstun": 24, "blockstun": 16, "posture": 16.0,
		"knockback": 7.0, "lunge": 1.0, "hitstop": 6, "impact_power": 2,
		"hitbox": Rect2(28.0, -198.0, 50.0, 60.0),
	},
	AttackType.BIG_FOOT: {
		"id": &"big_foot", "name": "Big Foot", "x_move": true, "x_cooldown_frames": 900, "x_strike": false,
		"startup": 24, "active": 5, "recovery": 34, "cancel_window": 0,
		"damage": 18, "hitstun": 24, "blockstun": 16, "posture": 16.0,
		"knockback": 8.0, "lunge": 0.8, "hitstop": 12,
		"hitbox": Rect2(28.0, -144.0, 62.0, 62.0), "blowback_chance": 1.0, "blowback_vx": 16.0, "blowback_vy": -9.0, "blowback_rolls": 0, "impact_power": 3,
	},
	AttackType.DROPKICK: {
		"id": &"dropkick", "name": "Dropkick", "x_move": true, "x_cooldown_frames": 900, "x_strike": false,
		"startup": 24, "active": 6, "recovery": 40, "cancel_window": 0,
		"damage": 18, "hitstun": 24, "blockstun": 16, "posture": 16.0,
		"knockback": 8.0, "lunge": 0.0, "hitstop": 12,
		"hitbox": Rect2(28.0, -128.0, 68.0, 62.0), "blowback_chance": 1.0, "blowback_vx": 10.0, "blowback_vy": -7.5, "blowback_rolls": 0, "impact_power": 3, "leap": -9.0, "leap_at": 14, "leap_vx": 4.5, "land_lag": 70,
	},

	AttackType.SCORPION_KICK: {
		"id": &"scorpion_kick", "name": "Scorpion Kick", "x_move": true,
		"startup": 18, "active": 5, "recovery": 30, "cancel_window": 0,
		"damage": 18, "hitstun": 24, "blockstun": 16, "posture": 16.0,
		"knockback": 6.0, "lunge": 0.6, "hitstop": 9, "impact_power": 2,
		"hitbox": Rect2(22.0, -185.0, 50.0, 60.0),
	},

	AttackType.THAI_ROUNDHOUSE: {
		"id": &"thai_roundhouse", "name": "Thai Roundhouse Kick (Tae Chiang)", "x_move": true, "x_cooldown_frames": 900,
		"startup": 20, "active": 5, "recovery": 30, "cancel_window": 0,
		"damage": 18, "hitstun": 26, "blockstun": 16, "posture": 16.0,
		"knockback": 16.0, "lunge": 1.2, "hitstop": 14, "impact_power": 3,
		"blowback_chance": 1.0, "blowback_vx": 8.0, "blowback_vy": -5.0, "blowback_rolls": 0,
		"hitbox": Rect2(28.0, -165.0, 58.0, 60.0),
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
	## Step-in distance (STEP_IN).
	var step: float = 0.0
	var hitstop: int = 0
	## Presentation force independent of health damage; 0 uses normal damage tier.
	var impact_power: int = 0
	## Pause before the next strike of a sequence; shared default preserves old moves.
	var sequence_gap: int = SEQUENCE_GAP
	## Committed grounded travel begins here; -1 uses ordinary range-limited lunge.
	var travel_start: int = -1
	var posture: float = 0.0
	var launch: float = 0.0
	var knockdown: bool = false
	## Low attacks can only be blocked crouching (low block).
	var low: bool = false
	## Overheads come down from above and beat a crouching (low) block: they
	## must be blocked standing. Every attack thrown in the air counts as one.
	var overhead: bool = false
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
	## Turns for spinning moves (1 = turn the back and come round again).
	var spin_turns: float = 1.0
	## Signature technique (F at full Focus).
	var signature: bool = false
	var x_move: bool = false
	## Independent cooldown starts when the X move begins, before sequence expansion.
	var x_cooldown_frames: int = X_COOLDOWN_FRAMES
	var x_strike: bool = false
	## Leaves the ground at the start of the move with this vertical velocity.
	var leap_vy: float = 0.0
	## Tick the leap leaves the ground, and its forward speed (px/tick).
	var leap_at: int = 2
	var leap_vx: float = 2.5
	## Landing recovery for a leaping move (0 = the normal air-attack landing).
	var land_lag: int = 0
	var rehit: int = 0
	var deflect: bool = false
	## Sub-moves (ids) for sequence moves; empty for ordinary moves.
	var sequence: Array = []
	## No hitbox (a weave, a feint): chains out without contact.
	var no_strike: bool = false
	## A charge: the lunge stops for good once the swing connects.
	var charge: bool = false
	## Dizzy ticks on a clean hit (0 = this move never stuns).
	var stun: int = 0
	## Run-up: px stepped back over the first backstep_ticks of the startup.
	var backstep: float = 0.0
	var backstep_ticks: int = 0
	## Breaks a blocking opponent's guard outright (parries still beat it).
	var guard_break: bool = false
	## A clean hit throws the opponent off balance: they reel (STAGGER, open to
	## counter hits) for this many ticks instead of the usual hitstun (0 = no).
	var off_balance: int = 0
	## Rebounds off the target on contact; landing lag after a contact.
	var bounce: bool = false
	var hit_land_lag: int = 0

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
	## F: signature technique (only at full Focus).
	var signature: bool = false
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
	attack.step = STEP_IN.get(row["id"], 0.0)
	attack.hitstop = row["hitstop"]
	attack.impact_power = row.get("impact_power", 0)
	attack.sequence_gap = row.get("sequence_gap", SEQUENCE_GAP)
	attack.travel_start = row.get("travel_start", -1)
	attack.posture = row["posture"]
	attack.launch = row.get("launch", 0.0)
	attack.knockdown = row.get("knockdown", false)
	attack.low = row.get("low", false)
	attack.overhead = row.get("overhead", false)
	attack.blowback_chance = row.get("blowback_chance", 0.0)
	attack.blowback_vx = row.get("blowback_vx", 0.0)
	attack.blowback_vy = row.get("blowback_vy", 0.0)
	attack.blowback_rolls = row.get("blowback_rolls", 0)
	attack.hitbox = row["hitbox"]
	attack.id = row["id"]
	attack.slip_frames = row.get("slip", 0)
	attack.air_only = row.get("air", false)
	attack.spin = row.get("spin", false)
	attack.spin_turns = row.get("spin_turns", 1.0)
	attack.signature = row.get("signature", false)
	attack.x_move = row.get("x_move", false)
	attack.x_cooldown_frames = row.get("x_cooldown_frames", X_COOLDOWN_FRAMES)
	attack.x_strike = row.get("x_strike", false)
	attack.leap_vy = row.get("leap", 0.0)
	attack.land_lag = row.get("land_lag", 0)
	attack.leap_at = row.get("leap_at", 2)
	attack.leap_vx = row.get("leap_vx", 2.5)
	attack.rehit = row.get("rehit", 0)
	attack.deflect = row.get("deflect", false)
	attack.sequence = row.get("sequence", [])
	attack.no_strike = row.get("no_strike", false)
	attack.charge = row.get("charge", false)
	attack.stun = row.get("stun", 0)
	attack.backstep = row.get("backstep", 0.0)
	attack.backstep_ticks = row.get("backstep_ticks", 0)
	attack.bounce = row.get("bounce", false)
	attack.guard_break = row.get("guard_break", false)
	attack.off_balance = row.get("off_balance", 0)
	attack.hit_land_lag = row.get("hit_land_lag", 0)
	_attack_cache[type] = attack
	return attack


## Focus for landing `attack` cleanly: kicks, heavy blows, light blows;
## a counter hit pays the counter rate instead; signatures pay nothing.
## Focus for TAKING a clean hit of `damage`.
static func focus_for_hurt(damage: int) -> float:
	return damage * FOCUS_HURT_PER_DAMAGE


static func focus_for_hit(attack: Attack, counter: bool) -> float:
	if attack.signature:
		return 0.0
	if counter:
		return FOCUS_COUNTER
	var n := String(attack.id)
	if n.contains("kick") or n == "sweep" or n.contains("knee"):
		return FOCUS_KICK
	return FOCUS_HEAVY if attack.damage >= 10 else FOCUS_LIGHT


static var _id_lookup: Dictionary = {}


## Move by permanent id (NONE if unknown).
static func type_for_id(move_id: StringName) -> AttackType:
	if _id_lookup.is_empty():
		for t in ATTACK_TABLE:
			_id_lookup[ATTACK_TABLE[t]["id"]] = t
	return _id_lookup.get(move_id, AttackType.NONE)


static func id_for_type(type: AttackType) -> StringName:
	return ATTACK_TABLE[type]["id"] if ATTACK_TABLE.has(type) else &""


static func impact_kind(type: AttackType) -> ImpactKind:
	match type:
		AttackType.SCORPION_KICK:
			return ImpactKind.DOWNWARD
		AttackType.THAI_ROUNDHOUSE, AttackType.DEMPSEY_HOOK_LEFT, AttackType.DEMPSEY_HOOK_RIGHT, AttackType.STEP_BACK_SPINNING_BACKFIST, AttackType.BUTTERFLY_KICK, AttackType.RETREATING_JUMP_ELBOW:
			return ImpactKind.HOOK
		AttackType.LEAD_HOOK, AttackType.REAR_HOOK, AttackType.BODY_HOOK, AttackType.BACKHAND, 				AttackType.KNIFE_HAND, AttackType.ELBOW, AttackType.HIGH_KICK, AttackType.BODY_ROUNDHOUSE, 				AttackType.LOW_ROUNDHOUSE, AttackType.SPIN_HOOK_KICK, AttackType.JUMP_ROUNDHOUSE, 				AttackType.JUMP_SPIN_KICK, AttackType.TORNADO_540, AttackType.SPIN_COUNTER_KICK, AttackType.GAZELLE_HOOK:
			return ImpactKind.HOOK
		AttackType.UPPERCUT, AttackType.RISING_PUNCH, AttackType.RISING_PALM, AttackType.KNEE, AttackType.FLYING_KNEE, \
				AttackType.RISING_ELBOW, AttackType.POWER_UPPERCUT, AttackType.FLYING_KNEE_FACE:
			return ImpactKind.RISING
		AttackType.AXE_KICK, AttackType.OVERHAND, AttackType.JUMP_PUNCH, AttackType.JUMPING_ELBOW, \
				AttackType.FLYING_AXE_KICK, AttackType.HAMMER_FIST:
			return ImpactKind.DOWNWARD
		AttackType.JUMPING_BACKFIST, AttackType.JUMPING_SPIN_HOOK, AttackType.LEAPING_ROUNDHOUSE, \
				AttackType.LEAPING_SPIN_BACKFIST, AttackType.LIGHT_SLAP, AttackType.HEAD_ELBOW, AttackType.FLYING_SLAP:
			return ImpactKind.HOOK
	return ImpactKind.STRAIGHT


## World direction a strike drives the target (facing: the attacker's).
static func impact_dir(type: AttackType, facing: int) -> Vector2:
	return dir_for_kind(impact_kind(type), facing)


static func dir_for_kind(kind: ImpactKind, facing: int) -> Vector2:
	match kind:
		ImpactKind.HOOK:
			return Vector2(facing, -0.18).normalized()
		ImpactKind.RISING:
			return Vector2(facing * 0.55, -1.0).normalized()
		ImpactKind.DOWNWARD:
			return Vector2(facing * 0.75, 0.75).normalized()
	return Vector2(facing, -0.06).normalized()


## Impact tier for presentation: 1 light, 2 solid, 3 heavy.
static func impact_tier(damage: int) -> int:
	return 1 if damage <= 7 else (2 if damage <= 11 else 3)


static func attack_name(type: AttackType) -> String:
	return AttackType.keys()[type]
