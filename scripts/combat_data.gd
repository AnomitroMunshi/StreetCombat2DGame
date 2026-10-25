class_name CombatData
extends RefCounted
## Combat tuning tables and shared value types.
##
## Pure data: no scene or node dependencies. All durations are measured in
## fixed simulation ticks (TICK_RATE per second), never in render frames.

## JUMP_KICK / JUMP_PUNCH are never pressed directly: any kick or punch button
## while airborne becomes one of them.
enum AttackType { NONE, LIGHT, HEAVY, KICK, FRONT_KICK, BACKHAND, UPPERCUT, JUMP_KICK, JUMP_PUNCH, SWEEP, HIGH_KICK }
enum HitResult { WHIFF, HIT, BLOCKED, KO, PARRIED }

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
##   launch (optional): upward velocity given to a grounded opponent on hit.
##   knockdown (optional): a clean hit always knocks down (sweeps).
##   blowback_* (optional): chance that a clean hit sends the opponent flying
##     (vx, vy in px/tick) into a knockdown with `blowback_rolls` floor rolls.
##     The 3rd-hit combo knockdown also uses these values when present.
const ATTACK_TABLE: Dictionary = {
	AttackType.LIGHT: {
		"name": "Jab",
		"startup": 5, "active": 3, "recovery": 11, "cancel_window": 9,
		"damage": 6, "hitstun": 16, "blockstun": 10,
		"knockback": 2.5, "lunge": 0.8, "hitstop": 4,
		"hitbox": Rect2(28.0, -150.0, 52.0, 26.0),
	},
	AttackType.HEAVY: {
		"name": "Cross",
		"startup": 11, "active": 3, "recovery": 20, "cancel_window": 8,
		"damage": 13, "hitstun": 22, "blockstun": 14,
		"knockback": 6.0, "lunge": 2.0, "hitstop": 7,
		"blowback_chance": 0.15, "blowback_vx": 7.0, "blowback_vy": -6.0, "blowback_rolls": 0,
		"hitbox": Rect2(36.0, -154.0, 62.0, 30.0),
	},
	AttackType.KICK: {
		"name": "Side Kick",
		"startup": 9, "active": 4, "recovery": 17, "cancel_window": 8,
		"damage": 10, "hitstun": 18, "blockstun": 12,
		"knockback": 6.5, "lunge": 0.6, "hitstop": 6,
		"blowback_chance": 0.3, "blowback_vx": 8.0, "blowback_vy": -7.0, "blowback_rolls": 1,
		"hitbox": Rect2(40.0, -126.0, 62.0, 30.0),
	},
	# Push kick: quick, low damage, big push. Keeps the opponent out; fairly safe on block.
	AttackType.FRONT_KICK: {
		"name": "Front Kick",
		"startup": 7, "active": 3, "recovery": 15, "cancel_window": 6,
		"damage": 8, "hitstun": 17, "blockstun": 13,
		"knockback": 9.0, "lunge": 1.2, "hitstop": 5,
		"blowback_chance": 0.4, "blowback_vx": 9.0, "blowback_vy": -5.5, "blowback_rolls": 1,
		"hitbox": Rect2(34.0, -94.0, 60.0, 30.0),
	},
	# Lead-hand backfist: quick snap to the head, slightly longer reach than the jab.
	AttackType.BACKHAND: {
		"name": "Backhand",
		"startup": 6, "active": 2, "recovery": 12, "cancel_window": 8,
		"damage": 7, "hitstun": 16, "blockstun": 11,
		"knockback": 3.0, "lunge": 1.0, "hitstop": 4,
		"hitbox": Rect2(30.0, -162.0, 58.0, 28.0),
	},
	# Rear-hand rising punch: short reach, tall hitbox (anti-air), launches on hit.
	AttackType.UPPERCUT: {
		"name": "Uppercut",
		"startup": 9, "active": 3, "recovery": 18, "cancel_window": 6,
		"damage": 12, "hitstun": 24, "blockstun": 14,
		"knockback": 2.0, "lunge": 2.0, "hitstop": 7, "launch": 8.0,
		"hitbox": Rect2(18.0, -200.0, 44.0, 80.0),
	},
	# Airborne only. Ends early on landing; never chains.
	AttackType.JUMP_KICK: {
		"name": "Jump Kick",
		"startup": 4, "active": 8, "recovery": 12, "cancel_window": 0,
		"damage": 11, "hitstun": 20, "blockstun": 12,
		"knockback": 5.0, "lunge": 0.0, "hitstop": 6,
		"hitbox": Rect2(28.0, -82.0, 62.0, 36.0),
	},
	# Airborne only. Flying straight punch that carries forward momentum.
	AttackType.JUMP_PUNCH: {
		"name": "Jump Punch",
		"startup": 3, "active": 6, "recovery": 10, "cancel_window": 0,
		"damage": 8, "hitstun": 18, "blockstun": 10,
		"knockback": 3.5, "lunge": 2.0, "hitstop": 5,
		"hitbox": Rect2(28.0, -150.0, 58.0, 72.0),
	},
	# Face-level kick (W + L): fast for a kick, high damage, unsafe on block.
	AttackType.HIGH_KICK: {
		"name": "High Kick",
		"startup": 7, "active": 3, "recovery": 18, "cancel_window": 6,
		"damage": 12, "hitstun": 20, "blockstun": 14,
		"knockback": 5.5, "lunge": 0.8, "hitstop": 7,
		"blowback_chance": 0.2, "blowback_vx": 7.5, "blowback_vy": -7.5, "blowback_rolls": 1,
		"hitbox": Rect2(24.0, -182.0, 62.0, 40.0),
	},
	# Low rotational leg sweep (S + L): takes the legs out, always knocks down.
	AttackType.SWEEP: {
		"name": "Sweep",
		"startup": 10, "active": 3, "recovery": 19, "cancel_window": 0,
		"damage": 9, "hitstun": 24, "blockstun": 12,
		"knockback": 2.0, "lunge": 1.0, "hitstop": 6, "knockdown": true, "low": true,
		"blowback_vx": 2.5, "blowback_vy": -6.0,
		"hitbox": Rect2(30.0, -30.0, 82.0, 30.0),
	},
}


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
	var launch: float = 0.0
	var knockdown: bool = false
	## Low attacks can only be blocked crouching (low block).
	var low: bool = false
	var blowback_chance: float = 0.0
	var blowback_vx: float = 0.0
	var blowback_vy: float = 0.0
	var blowback_rolls: int = 0
	var hitbox: Rect2 = Rect2()

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
	attack.launch = row.get("launch", 0.0)
	attack.knockdown = row.get("knockdown", false)
	attack.low = row.get("low", false)
	attack.blowback_chance = row.get("blowback_chance", 0.0)
	attack.blowback_vx = row.get("blowback_vx", 0.0)
	attack.blowback_vy = row.get("blowback_vy", 0.0)
	attack.blowback_rolls = row.get("blowback_rolls", 0)
	attack.hitbox = row["hitbox"]
	_attack_cache[type] = attack
	return attack


static func attack_name(type: AttackType) -> String:
	return AttackType.keys()[type]
