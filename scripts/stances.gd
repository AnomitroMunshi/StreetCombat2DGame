class_name Stances
extends RefCounted
## Fighting stances (starting positions). Presentation and style only: a stance
## sets the guard pose every move starts from and returns to, the idle rhythm,
## and which foot leads. It does not change frame data or damage.
##
## Pose channels match FighterVisual:
##   torso, head, ua_f, la_f, ua_b, la_b, th_f, sh_f, th_b, sh_b, hip_x, drop, pivot, spread
## Every stance keeps at least one hand at the chin and both knees bent; spread
## (body rotation) gives each stance its own silhouette.

## APPEND-ONLY (style files refer to stances by index).
enum Kind { BLADED, SQUARED, BOXING, MUAY_THAI, KARATE, KUNG_FU, GRAPPLER, COUNTER, TAEKWONDO, KICKBOXING, STREET }

## name, guard pose, southpaw (right foot forward), and the active idle (the
## looping fighting movement in neutral; presentation only):
##   hz        bounce rhythm; bob: hip dip in px (knees bend over planted feet)
##   shape     "hop" (springy boxing bounce), "sine" (smooth), "snap" (sharp
##             settle-and-hold adjustments)
##   shift     weight shift between the feet in px, at shift_hz
##   heel      rear heel lift in px (toes stay down); lead_heel: same, lead foot
##   shoulder  shoulder roll (body rotation) in px; guard: hand drift in rad
##   sway      torso sway in rad (the head counters it, eyes stay level)
##   head      extra head movement in rad; circles: hands trace small circles
##   feint     optional lead-hand feint: rad of reach, every feint_every s
##   rear_heel rear heel kept raised in px (on the ball of the rear foot)
##   gestures  street idle: now and then points a finger, puts a hand on the
##             waist, tugs a sleeve or shakes the head (FighterVisual)
##   alternate boxer's bounce: heels lift on alternate bounces (rear, then
##             lead), the weight and shoulders rocking toward the planted
##             foot; one loop = two bounces (2 / hz seconds)
const DATA: Dictionary = {
	Kind.BLADED: {
		"name": "BLADED", "southpaw": false, "idle": {"hz": 2.0, "bob": 3.5, "shape": "hop", "shift": 4.0, "shift_hz": 0.9, "heel": 3.0, "lead_heel": 0.0, "shoulder": 1.5, "guard": 0.05, "sway": 0.02, "head": 0.02},
		# Mobile, side-on, open lead hand reaching forward, rear hand at the chin.
		"pose": [0.12, 0.08, 1.15, 2.2, 0.95, 3.0, 0.55, -0.1, -0.6, -0.15, 0.0, 0.0, 0.0, 13.0],
	},
	Kind.SQUARED: {
		"name": "SQUARED", "southpaw": true, "idle": {"hz": 1.6, "bob": 3.0, "shape": "sine", "shift": 5.0, "shift_hz": 0.6, "heel": 2.0, "lead_heel": 0.0, "shoulder": 2.5, "guard": 0.04, "sway": 0.05, "head": 0.03},
		# Pressure fighter: squared up, crouched forward, both fists high and closed.
		"pose": [0.35, 0.2, 0.85, 2.95, 0.8, 2.95, 0.7, -0.2, -0.5, -0.5, 4.0, 0.0, 0.0, 2.0],
	},
	Kind.BOXING: {
		"name": "BOXING GUARD", "southpaw": false, "idle": {"hz": 2.5, "bob": 3.0, "shape": "hop", "alternate": true, "shift": 3.0, "shift_hz": 1.25, "heel": 3.5, "lead_heel": 3.0, "shoulder": 1.8, "guard": 0.05, "sway": 0.02, "head": 0.035, "feint": 0.35, "feint_every": 2.7, "rear_heel": 4.0},
		# Compact high guard: chin tucked behind the lead shoulder, elbows in
		# over the ribs, rear glove at the cheek, lead glove a little forward;
		# knees soft, weight centred on a staggered stance.
		# Boxing duck (S): knees and waist bend, the head drops under the punch
		# line with the gloves still up; not a full crouch.
		"crouch": [0.7, 0.4, 1.0, 2.95, 0.65, 3.05, 1.05, -0.45, -0.35, -1.1, 6.0, 0.0, 0.0, 5.0],
		"crouch_block": [0.72, 0.5, 1.2, 3.15, 0.95, 3.1, 1.05, -0.45, -0.35, -1.1, 4.0, 0.0, 0.0, 4.0],
		# Rear leg: knee soft and pointing forward, heel up on the ball of the foot.
		"pose": [0.22, 0.34, 0.8, 2.75, 0.55, 3.05, 0.45, -0.12, -0.25, -0.62, 0.0, 2.0, 0.0, 8.0],
	},
	Kind.MUAY_THAI: {
		"name": "MUAY THAI GUARD", "southpaw": false, "idle": {"hz": 1.0, "bob": 2.0, "shape": "sine", "shift": 2.5, "shift_hz": 0.5, "heel": 0.0, "lead_heel": 4.0, "shoulder": 1.0, "guard": 0.03, "sway": 0.02, "head": 0.01},
		# Upright, high hands, elbows in, lead knee lifted and ready to check.
		"pose": [0.02, 0.05, 1.05, 3.0, 0.9, 3.05, 0.75, -0.6, -0.3, -0.3, 0.0, 0.0, 0.0, 4.0],
	},
	Kind.KARATE: {
		"name": "KARATE STANCE", "southpaw": false, "idle": {"hz": 1.7, "bob": 3.0, "shape": "hop", "shift": 7.0, "shift_hz": 0.85, "heel": 3.0, "lead_heel": 0.0, "shoulder": 1.2, "guard": 0.03, "sway": 0.015, "head": 0.01},
		# Side-on long stance, low centre, extended lead guard, rear hand close to the body.
		"pose": [0.05, 0.1, 1.45, 1.9, 0.9, 2.75, 0.95, -0.2, -0.85, -0.35, 0.0, 0.0, 0.0, 15.0],
	},
	Kind.KUNG_FU: {
		"name": "KUNG FU STANCE", "southpaw": false, "idle": {"hz": 0.8, "bob": 3.0, "shape": "sine", "shift": 5.0, "shift_hz": 0.4, "heel": 1.0, "lead_heel": 0.0, "shoulder": 2.5, "guard": 0.12, "sway": 0.05, "head": 0.02, "circles": true},
		# Low and wide, both hands open and forward, fluid.
		"pose": [0.15, 0.1, 1.3, 2.4, 1.0, 2.85, 1.0, -0.4, -0.95, -0.55, 0.0, 0.0, 0.0, 10.0],
	},
	Kind.GRAPPLER: {
		"name": "GRAPPLER STANCE", "southpaw": false, "idle": {"hz": 0.7, "bob": 2.0, "shape": "sine", "shift": 6.0, "shift_hz": 0.35, "heel": 0.0, "lead_heel": 0.0, "shoulder": 3.0, "guard": 0.05, "sway": 0.06, "head": 0.02},
		# Judo: low posture, bent forward, open hands reaching to clinch.
		"pose": [0.45, 0.3, 1.35, 1.7, 1.0, 2.9, 0.7, -0.35, -0.45, -0.6, 6.0, 0.0, 0.0, 4.0],
	},
	Kind.COUNTER: {
		"name": "COUNTER-FIGHTER", "southpaw": false, "idle": {"hz": 1.4, "bob": 1.2, "shape": "snap", "shift": 3.0, "shift_hz": 0.7, "heel": 1.5, "lead_heel": 0.0, "shoulder": 1.0, "guard": 0.04, "sway": 0.03, "head": 0.08},
		# Elusive: upright, lead hand low and loose, rear hand high, lots of head movement.
		"pose": [0.05, 0.05, 0.6, 1.9, 0.9, 3.0, 0.5, -0.12, -0.45, -0.3, 0.0, 0.0, 0.0, 11.0],
	},
	Kind.TAEKWONDO: {
		"name": "TAEKWONDO STANCE", "southpaw": false, "idle": {"hz": 2.6, "bob": 4.5, "shape": "hop", "shift": 3.0, "shift_hz": 1.3, "heel": 4.5, "lead_heel": 3.0, "shoulder": 1.0, "guard": 0.05, "sway": 0.02, "head": 0.02},
		# Side-on and light on the balls of the feet, hands lower and loose:
		# the legs do the work, the bounce never stops.
		"pose": [0.02, 0.05, 1.0, 2.3, 0.8, 2.7, 0.45, -0.1, -0.5, -0.15, 0.0, 0.0, 0.0, 13.0],
	},
	Kind.KICKBOXING: {
		"name": "KICKBOXING GUARD", "southpaw": false, "idle": {"hz": 2.0, "bob": 3.5, "shape": "hop", "shift": 4.0, "shift_hz": 1.0, "heel": 3.0, "lead_heel": 1.5, "shoulder": 1.6, "guard": 0.05, "sway": 0.03, "head": 0.03},
		# Balanced, slightly square, high guard: ready to punch or kick.
		"pose": [0.15, 0.15, 0.95, 2.9, 0.85, 3.0, 0.55, -0.15, -0.5, -0.35, 0.0, 0.0, 0.0, 9.0],
	},
	Kind.STREET: {
		"name": "PARA STANCE", "southpaw": false, "idle": {"hz": 1.1, "bob": 1.5, "shape": "sine", "shift": 4.0, "shift_hz": 0.45, "heel": 1.0, "lead_heel": 0.5, "shoulder": 1.2, "guard": 0.05, "sway": 0.035, "head": 0.06, "gestures": true},
		# Untrained and relaxed: no guard at all, hands hanging loose, shoulders
		# down, leaning a little forward on an easy, narrow stance.
		"pose": [0.14, 0.02, 0.35, 0.75, 0.15, 0.35, 0.28, 0.0, -0.22, -0.28, 0.0, 0.0, 0.0, 3.0],
		# Squatting down with the hands still loose (no fists up).
		"crouch": [0.4, 0.1, 0.7, 1.2, 0.5, 1.0, 1.25, -0.25, 0.5, -1.5, 0.0, 0.0, 0.0, 3.0],
	},
}

## The player's stance survives restarts (scene reloads).
static var player_choice: Kind = Kind.BLADED


static func count() -> int:
	return DATA.size()


static func stance_name(kind: Kind) -> String:
	return DATA[kind]["name"]


static func pose(kind: Kind) -> PackedFloat32Array:
	return PackedFloat32Array(DATA[kind]["pose"])


static func is_southpaw(kind: Kind) -> bool:
	return DATA[kind]["southpaw"]


## The stance's own crouch / low-block pose, or an empty array for the default.
static func crouch_pose(kind: Kind, blocking: bool) -> PackedFloat32Array:
	return PackedFloat32Array(DATA[kind].get("crouch_block" if blocking else "crouch", []))


static func active_idle(kind: Kind) -> Dictionary:
	return DATA[kind]["idle"]


## A random stance that is never the excluded one.
static func random_except(excluded: Kind, rng: RandomNumberGenerator) -> Kind:
	var options: Array[Kind] = []
	for k in DATA.keys():
		if k != excluded:
			options.append(k)
	return options[rng.randi_range(0, options.size() - 1)]
