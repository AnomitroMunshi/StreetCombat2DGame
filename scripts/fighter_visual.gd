class_name FighterVisual
extends Node2D
## Procedural joint-based stickman renderer. A read-only view of its parent Fighter.
##
## A pose is an array of joint angles (radians). Limb angles are measured from
## straight down, positive = toward the facing direction. The torso angle is
## measured from straight up, positive = leaning forward. Everything is drawn
## facing right and mirrored in the draw transform.
##
## Animation layers:
##  * Moves are keyframe timelines (chamber -> strike -> re-chamber -> stance),
##    keyed to the attack's startup/active/recovery ticks, so the animation
##    always matches combat timing.
##  * Outside attacks, joints follow their target pose as damped springs
##    (overshoot and settle) and receive impulses from hits and blocks.
##  * Knocked-down / KO'd bodies become a Verlet ragdoll (gravity, bone
##    constraints, floor and wall collisions) and blend back into the get-up.
##  * Breakfall rolls curl into a ball that rolls without slipping.
## Poses are sampled in continuous time between 60 Hz ticks, and this node's own
## transform is never touched, so physics interpolation of the Fighter applies.

## PIVOT turns the rear (support) foot: 0 = toes forward, 1 = toes pointing back.
## SPREAD is body rotation in px: how far the lead shoulder/hip sit in front of
## the rear ones. Side-on stances spread wide, squared stances stack them, and a
## cross drives it negative (rear shoulder turns through).
enum { TORSO, HEAD, UA_F, LA_F, UA_B, LA_B, TH_F, SH_F, TH_B, SH_B, HIP_X, DROP, PIVOT, SPREAD, CHANNELS }
## Joint indices for world-space skeletons (ragdoll, trails).
enum { J_HIP, J_KNEE_F, J_FOOT_F, J_KNEE_B, J_FOOT_B, J_NECK, J_SHOULDER, J_ELBOW_F, J_HAND_F, J_ELBOW_B, J_HAND_B, J_HEAD,
	J_SHOULDER_F, J_SHOULDER_B, J_HIP_F, J_HIP_B, JOINTS }
## Keyframe phases: a key's time is a fraction of startup, active or recovery.
enum { S, A, R }
## Keyframe easing into a key.
enum { EASE_SMOOTH, EASE_IN, EASE_OUT, EASE_LINEAR }

const THIGH: float = 44.0
const SHIN: float = 44.0
const TORSO_LEN: float = 56.0
const NECK: float = 7.0
const HEAD_R: float = 13.0
const UPPER_ARM: float = 30.0
const FOREARM: float = 30.0
const LIMB_WIDTH: float = 9.0
const OUTLINE_WIDTH: float = 2.2
## Torso side profile along hip -> neck: (fraction, chest-side width, back-side width).
const TORSO_PROFILE: Array[Vector3] = [
	Vector3(0.0, 10.0, 11.0), Vector3(0.35, 8.5, 8.0), Vector3(0.62, 11.0, 9.5),
	Vector3(0.85, 11.0, 11.0), Vector3(1.0, 6.0, 8.0),
]
const TORSO_WIDTH: float = 13.0
## Hip height used while airborne (no floor to lock the feet to).
const AIR_HIP_HEIGHT: float = 86.0
## Joint springs (stiffness, damping ratio) used outside attacks.
const SPRING_DEFAULT := Vector2(340.0, 0.7)
const SPRING_HITSTUN := Vector2(260.0, 0.45)
const SPRING_LIMP := Vector2(140.0, 0.4)
const SPRING_FAST := Vector2(700.0, 0.75)
const MAX_ANGULAR_SPEED: float = 25.0
const MAX_LINEAR_SPEED: float = 400.0
## Lying / getting up.
const FALL_FRAMES: float = 14.0
## Breakfall roll: curled ball rolling without slipping (angle = distance / radius).
const ROLL_RADIUS: float = CombatData.ROLL_DISTANCE / TAU
const TUMBLE_SPIN: float = 13.0
const TUCK_PIVOT := Vector2(12.0, -50.0)
const TUCK_HIP := Vector2(-34.0, -32.0)
## Afterimage trail for fast moves.
const TRAIL_INTERVAL: float = 1.0 / 60.0
const TRAIL_LIFE: float = 0.16
const TRAIL_MAX: int = 6
## Ragdoll (per-tick Verlet).
const RAG_GRAVITY: float = 0.95
const RAG_DAMPING: float = 0.988
const RAG_ITERATIONS: int = 8
const RAG_FLOOR_FRICTION: float = 0.7
const RAG_FOLLOW: float = 0.06
const RAG_BLEND_TIME: float = 0.3
## Planted feet: legs are solved with 2-bone IK to feet fixed on the floor; a
## foot that drifts too far from its stance spot steps (one foot at a time).
const STEP_THRESHOLD: float = 13.0
const STEP_TIME: float = 0.075
const STEP_HEIGHT: float = 9.0
const PLANT_RATE: float = 12.0
## Steps land at most this far past their stance spot.
const STEP_LEAD_MAX: float = 18.0
## While walking the stance narrows by this much (front / rear foot, px).
const WALK_NARROW_FRONT: float = 4.0
const WALK_NARROW_REAR: float = 14.0
## Legs never straighten beyond this fraction of full length (soft knees);
## the hips settle lower (up to MAX_SETTLE px) to keep that bend.
const KNEE_SOFT: float = 0.95
const MAX_SETTLE: float = 8.0
## Default body rotation for poses that do not set it.
const DEFAULT_SPREAD: float = 6.0
## Body rotation per pose (var name -> px). Others use DEFAULT_SPREAD.
const POSE_SPREAD: Dictionary = {
	"_jab_windup": 9.0, "_jab_strike": 15.0, "_heavy_windup": 12.0, "_heavy_strike": -8.0,
	"_backhand_windup": 14.0, "_backhand_strike": 15.0, "_uppercut_windup": 4.0, "_uppercut_strike": -6.0,
	"_side_chamber": 12.0, "_side_extend": 14.0, "_front_chamber": 5.0, "_front_extend": 6.0,
	"_high_chamber": 10.0, "_high_extend": 12.0, "_block": 5.0, "_crouch": 6.0, "_crouch_block": 4.0,
	"_palm_lead": 12.0, "_palm_rear": -6.0, "_palm_strike": 2.0, "_hitstun": 3.0, "_hitstun_body": 3.0,
	"_ko": 0.0, "_getup_sit": 0.0, "_slumped": 0.0, "_tuck": 0.0, "_knock_fly": 2.0,
	"_dodge_back": 9.0, "_dodge_slip": 4.0, "_jump_punch_strike": 14.0, "_tornado_kick": 10.0,
}
## Swoosh arc traced by the striking fist or foot.
## Contact-aware reach: a strike's fist or foot may sink this far into the
## opponent's body outline, never further (it stops on the target instead of
## passing through). Presentation only; hitboxes are unchanged.
const CONTACT_DEPTH: float = 9.0
## Half the visible body thickness used for the target's near surface.
const BODY_HALF: float = 18.0
const REACH_SEARCH_STEPS: int = 6
## Active idle (the looping fighting movement in neutral, per stance: see
## Stances.DATA "idle"). It fades in over 1 / IDLE_FADE_IN s after any action
## (so recoveries look settled, not bouncy), out fast when acting, and is damped
## by up to IDLE_POSTURE_DAMP as posture fills. Purely visual: the gameplay root
## never moves; the hips dip over planted feet and heels lift with toes down.
const IDLE_FADE_IN: float = 2.2
const IDLE_FADE_OUT: float = 14.0
const IDLE_POSTURE_DAMP: float = 0.7
const MAX_IDLE_BOB: float = 6.0
const MAX_HEEL_LIFT: float = 5.0
const SWOOSH_POINTS: int = 10
const SWOOSH_FADE: float = 0.12

#                                  torso  head   ua_f   la_f   ua_b   la_b   th_f   sh_f   th_b   sh_b   hip_x drop
# Stance: knees bent, lead hand forward at chin height, rear hand guarding the cheek.
var _guard := PackedFloat32Array([0.22, 0.15, 0.95, 2.6, 0.55, 2.95, 0.6, -0.05, -0.62, -0.3, 0.0, 0.0])
# High guard: elbows tucked in front of the ribs, forearms vertical over the face, chin down.
var _block := PackedFloat32Array([0.25, 0.3, 1.25, 3.1, 1.05, 3.05, 0.7, -0.15, -0.62, -0.4, -2.0, 0.0])
# Guard broken: arms dropped, hunched, knees buckling (wobbles in _target_pose).
var _broken := PackedFloat32Array([0.55, 0.5, 0.25, 0.55, 0.15, 0.45, 0.8, -0.35, -0.5, -0.65, -4.0, 12.0])
# Parry deflect: the lead forearm sweeps the strike up and out, weight forward.
var _deflect := PackedFloat32Array([0.3, 0.2, 2.0, 3.5, 1.0, 3.05, 0.72, -0.2, -0.62, -0.4, 4.0, 0.0])
var _blockstun := PackedFloat32Array([0.05, 0.22, 1.1, 3.25, 0.9, 3.2, 0.62, -0.1, -0.7, -0.45, -6.0, 0.0])

# Punches.
var _jab_windup := PackedFloat32Array([0.18, 0.15, 1.0, 2.4, 0.55, 2.95, 0.6, -0.05, -0.62, -0.3, -2.0, 0.0])
var _jab_strike := PackedFloat32Array([0.3, 0.1, 1.57, 1.6, 0.55, 2.95, 0.66, 0.0, -0.66, -0.32, 6.0, 0.0])
# Cross: hips and shoulders rotate in, rear leg drives straight, front knee bends into a lunge.
var _heavy_windup := PackedFloat32Array([0.05, 0.15, 0.95, 2.7, 0.25, 2.5, 0.55, -0.1, -0.6, -0.35, -6.0, 0.0])
# The rear heel turns out (pivot) as the hips drive the cross through.
var _heavy_strike := PackedFloat32Array([0.5, 0.05, 0.75, 2.8, 1.57, 1.6, 0.85, 0.25, -0.8, -0.65, 16.0, 0.0, 0.5])
var _backhand_windup := PackedFloat32Array([0.1, 0.15, 1.3, 4.08, 0.55, 2.95, 0.6, -0.05, -0.62, -0.3, -3.0, 0.0])
var _backhand_strike := PackedFloat32Array([0.25, 0.05, 1.8, 2.05, 0.55, 2.95, 0.68, 0.05, -0.66, -0.32, 6.0, 0.0])
var _uppercut_windup := PackedFloat32Array([0.45, 0.15, 0.9, 2.6, 0.15, 0.9, 1.0, -0.4, -0.75, -1.1, -4.0, 0.0])
var _uppercut_strike := PackedFloat32Array([-0.1, -0.1, 0.7, 2.8, 1.3, 2.95, 0.5, 0.05, -0.45, -0.15, 8.0, 0.0, 0.4])

# Side kick (lead leg): pivot and chamber the knee across the body (heel to the
# hip), thrust the heel out with the hips while the torso counter-leans and the
# rear arm swings back for balance, then re-chamber before stepping down.
var _side_chamber := PackedFloat32Array([-0.3, 0.3, 1.2, 2.2, 0.55, 2.95, 1.6, -1.4, -0.22, -0.12, -4.0, 6.0, 0.8])
var _side_extend := PackedFloat32Array([-0.55, 0.45, 1.35, 1.65, 0.6, 2.9, 1.8, 1.8, -0.22, -0.08, 10.0, 3.0, 1.0])
# Front (push) kick, rear leg: knee lifts high in front, the ball of the foot drives
# straight out at hip height with the hips pushing forward, then re-chambers.
var _front_chamber := PackedFloat32Array([-0.05, 0.15, 0.9, 2.7, 0.45, 2.9, 1.8, 0.2, -0.3, -0.25, 0.0, 6.0, 0.2])
var _front_extend := PackedFloat32Array([-0.3, 0.25, 0.8, 2.75, 0.45, 2.9, 1.52, 1.55, -0.45, -0.15, 12.0, 4.0, 0.35])
# Flying side kick: both knees tucked, then the lead leg spears down-forward with
# the rear leg folded underneath.
var _jk_chamber := PackedFloat32Array([0.0, 0.1, 0.8, 2.75, 0.4, 2.8, 2.0, -0.6, 1.2, -1.2, -2.0, 0.0])
var _jk_extend := PackedFloat32Array([-0.5, 0.3, 0.7, 2.7, -1.0, -0.8, 1.25, 1.25, 0.6, -1.2, 6.0, 0.0])
# High kick: knee chambered high and diagonal, then the shin snaps out to face
# level with the torso counter-leaning and the support foot pivoting.
var _high_chamber := PackedFloat32Array([-0.3, 0.3, 1.15, 2.3, 0.55, 2.95, 2.15, -0.7, -0.25, -0.15, -4.0, 0.0, 0.8])
var _high_extend := PackedFloat32Array([-0.6, 0.55, 1.3, 1.9, 0.6, 2.9, 2.6, 2.62, -0.25, -0.1, 10.0, 0.0, 1.0])
# Flying punch: lead fist chambered with the knees tucked, then fired straight
# forward with the rear leg trailing (the body travels with it).
var _jump_punch_windup := PackedFloat32Array([0.15, 0.05, 0.4, 2.9, 0.5, 2.9, 1.7, -0.5, 1.2, -0.9, -4.0, 0.0])
var _jump_punch_strike := PackedFloat32Array([0.4, 0.05, 1.6, 1.55, 0.4, 2.9, 1.3, -0.5, -0.45, -0.9, 8.0, 0.0])
# Sweep: drop into a deep squat on the rear leg, then the lead leg scythes along
# the floor with the rear hand planted for support.
# Leg sweep (S + L), after the reference sheet:
#   startup: lower body drops onto the bent rear leg, weight forward;
#   chamber: lead leg slides out, torso leans, lead hand down for balance;
#   active:  lead leg straight along the floor at ankle height, sweeping through;
#   follow-through: the leg carries on in a low rising arc, then recover.
var _sweep_load := PackedFloat32Array([0.5, 0.35, 0.7, 0.9, 0.85, 2.9, 1.25, -1.1, 1.0, -1.25, -4.0, 0.0, 0.0, 8.0])
var _sweep_chamber := PackedFloat32Array([0.8, 0.5, 0.35, 0.15, 0.85, 2.9, 1.35, 1.0, 1.15, -1.3, -10.0, 0.0, 0.0, 6.0])
var _sweep_extend := PackedFloat32Array([0.85, 0.55, 0.35, 0.15, 0.85, 2.9, 1.28, 1.4, 1.15, -1.3, -8.0, 0.0, 0.3, 4.0])
var _sweep_follow := PackedFloat32Array([0.7, 0.5, 0.45, 0.3, 0.9, 2.9, 1.55, 1.68, 1.15, -1.3, -4.0, 0.0, 0.6, 2.0])
# Back kick (away + L from standing). Drawn while the body is turned away from
# the opponent (see _back_turn), so the kicking leg is the one pointing back:
# knee pulled to the chest, then a heel thrust straight back at the opponent.
var _back_chamber := PackedFloat32Array([0.35, 0.35, 1.0, 2.8, 0.9, 2.9, 0.25, -0.1, 1.3, -1.0, 2.0, 0.0, 0.0, 6.0])
var _back_extend := PackedFloat32Array([0.75, 0.55, 1.2, 2.6, 0.6, 2.4, 0.3, -0.05, -1.45, -1.5, -8.0, 0.0, 0.0, 4.0])

# Jump: deep crouch, toes pointed on the way up, knees tucked at the apex, legs
# reaching for the floor coming down, absorb on landing.
var _jump_squat := PackedFloat32Array([0.3, 0.1, 0.7, 2.7, 0.3, 2.85, 1.05, -0.45, -0.5, -1.25, 0.0, 0.0])
var _jump_rise := PackedFloat32Array([0.08, -0.05, 1.0, 2.6, 0.6, 2.75, 0.15, 0.1, -0.15, -0.2, 0.0, 0.0])
var _jump_air := PackedFloat32Array([0.12, 0.05, 0.85, 2.7, 0.45, 2.85, 1.75, -0.5, 1.35, -0.9, 0.0, 0.0])
var _jump_fall := PackedFloat32Array([0.05, 0.0, 0.8, 2.6, 0.4, 2.7, 0.55, 0.1, -0.2, -0.3, 0.0, 0.0])
var _land := PackedFloat32Array([0.3, 0.15, 0.7, 2.7, 0.3, 2.85, 1.05, -0.45, -0.5, -1.25, 0.0, 0.0])

# Crouch: low squat, rear knee near the floor, guard up; and the crouched (low) block.
var _crouch := PackedFloat32Array([0.35, 0.2, 1.0, 2.75, 0.7, 2.9, 1.25, -0.25, 0.5, -1.5, 0.0, 0.0])
var _crouch_block := PackedFloat32Array([0.42, 0.35, 1.25, 3.1, 1.05, 3.05, 1.25, -0.25, 0.5, -1.5, -2.0, 0.0])
# Dodge: backstep sway (lean out of range) and slip-in (duck under, forward).
var _dodge_back := PackedFloat32Array([-0.45, -0.25, 1.0, 2.9, 0.8, 3.0, 0.35, 0.1, -0.85, -0.6, -10.0, 0.0])
var _dodge_slip := PackedFloat32Array([0.65, 0.35, 1.0, 2.9, 0.8, 3.0, 0.9, -0.3, -0.7, -0.55, 8.0, 0.0])
# Hit reactions: head hits snap the head back, body hits fold the fighter forward.
var _hitstun := PackedFloat32Array([-0.45, -0.4, 0.2, 0.9, -0.3, 0.4, 0.3, 0.0, -0.5, -0.3, -6.0, 6.0])
var _hitstun_body := PackedFloat32Array([0.5, 0.35, 0.35, 1.9, 0.25, 1.7, 0.55, -0.2, -0.45, -0.5, -8.0, 14.0])
# Heavy head hit: head and shoulders whipped back and twisted, arms flung.
var _hitstun_heavy := PackedFloat32Array([-0.62, -0.6, -0.35, 0.4, -0.55, 0.1, 0.25, 0.05, -0.55, -0.25, -10.0, 8.0, 0.0, -4.0])
# Launched (uppercut / air hit): arched back, arms thrown up, legs trailing.
var _launched := PackedFloat32Array([-0.75, -0.55, 2.3, 2.9, 1.9, 2.5, 0.5, 0.35, -0.1, -0.4, 0.0, 0.0])
# Light hits are half-way between the stance and the full reaction (built in _ready).
var _hitstun_light := PackedFloat32Array()
var _hitstun_body_light := PackedFloat32Array()
# Knockdown / get-up.
var _knock_fly := PackedFloat32Array([-0.3, -0.5, 2.2, 2.6, 1.8, 2.4, 0.6, 0.3, 0.1, -0.2, 0.0, 0.0])
var _ko := PackedFloat32Array([-1.5, 0.15, -1.3, -1.6, 1.3, 1.5, 1.48, 1.55, 1.42, 1.5, 0.0, 6.0])
var _getup_sit := PackedFloat32Array([0.25, 0.1, 0.9, 2.2, -0.5, -0.2, 1.45, 1.55, 1.4, 1.5, 0.0, 6.0])
var _getup_crouch := PackedFloat32Array([0.5, 0.1, 0.85, 2.4, 0.5, 2.5, 1.45, -0.55, 1.15, -0.85, -4.0, 14.0])
var _tuck := PackedFloat32Array([1.15, 0.6, 1.2, 4.26, 1.0, 4.1, 2.3, -0.64, 2.1, -0.7, 0.0, 0.0])

# Finisher poses.
# Palm Flurry: alternating open-hand strikes from a rooted lunge.
var _palm_lead := PackedFloat32Array([0.32, 0.05, 1.55, 1.6, 0.55, 2.9, 0.75, 0.15, -0.7, -0.45, 10.0, 0.0])
var _palm_rear := PackedFloat32Array([0.4, 0.0, 0.85, 2.6, 1.55, 1.55, 0.8, 0.2, -0.72, -0.5, 13.0, 0.0])
# Air Smash: reach and grab in the air, then the overhead hammer-fist.
var _grab := PackedFloat32Array([0.25, -0.2, 2.1, 2.2, 1.6, 1.9, 1.5, -0.4, 0.6, -1.0, 4.0, 0.0])
var _hammer_windup := PackedFloat32Array([0.05, 0.0, 2.6, 3.9, 0.4, 2.8, 1.7, -0.5, 1.3, -0.9, -3.0, 0.0])
var _hammer_strike := PackedFloat32Array([0.45, 0.15, 0.8, 0.7, 0.5, 2.7, 1.1, -0.1, 0.4, -0.8, 4.0, 0.0])
# Follow-through: land low and controlled after an aerial finisher.
var _land_crouch := PackedFloat32Array([0.4, 0.25, 1.1, 2.6, 0.5, 2.9, 1.25, -0.6, -0.7, -1.4, 0.0, 0.0])
var _palm_windup := PackedFloat32Array([-0.05, 0.05, -0.3, 1.2, -0.4, 1.1, 0.5, 0.0, -0.5, -0.2, -6.0, 10.0])
var _palm_strike := PackedFloat32Array([0.35, -0.05, 1.5, 1.55, 1.45, 1.5, 0.75, 0.25, -0.7, -0.4, 14.0, 10.0])
var _spin_windup := PackedFloat32Array([-0.1, 0.3, 0.8, 2.6, 0.4, 2.7, 0.3, 0.0, 1.6, -0.3, 0.0, 4.0])
var _spin_kick := PackedFloat32Array([-0.7, 0.5, 1.0, 2.5, -1.2, -1.0, 2.1, 1.9, -0.15, -0.05, 6.0, 0.0])
var _knee_windup := PackedFloat32Array([0.0, 0.05, 1.2, 2.9, 0.8, 2.9, 0.4, 0.05, -0.6, -0.5, -4.0, 8.0])
var _knee := PackedFloat32Array([0.25, -0.1, 1.4, 0.8, 1.2, 0.9, 1.9, -0.3, -0.3, -0.6, 8.0, 0.0])
# Slumped against the wall: back resting on it, head dropped, one knee up,
# the other leg out, arms limp on the floor.
var _slumped := PackedFloat32Array([-0.7, 1.35, 0.35, 0.7, -0.15, 0.1, 2.1, 0.9, 1.45, 1.55, -24.0, 6.0, 0.0, 2.0])
var _stagger := PackedFloat32Array([-0.15, -0.3, 0.1, 0.4, -0.1, 0.2, 0.25, 0.05, -0.35, -0.15, -2.0, 8.0])
# Tornado (360) kick: coil low, spring up with knees tucked, lash out a high
# roundhouse while the arms fling out for balance.
var _tornado_windup := PackedFloat32Array([0.3, 0.2, -0.5, 1.0, 1.2, 2.0, 0.8, -0.4, -0.5, -0.9, -4.0, 18.0])
var _tornado_chamber := PackedFloat32Array([0.1, 0.1, 0.9, 2.8, 0.6, 2.8, 1.9, -0.6, 1.6, -1.0, 0.0, 0.0])
var _tornado_kick := PackedFloat32Array([-0.6, 0.45, 1.3, 2.3, -1.3, -1.0, 1.95, 2.05, 0.9, -1.1, 6.0, 0.0])
# Pre-match: standing relaxed (arms loose at the sides, narrow natural stance),
# a fist-in-palm salute with a slight bow, and a chin-down glare with the fists
# held low and loose. main.gd picks them through Fighter.prefight_pose.
var _relaxed := PackedFloat32Array([0.03, 0.02, 0.14, 0.32, 0.1, 0.28, 0.24, 0.02, -0.2, -0.26, 0.0, 0.0, 0.0, 3.0])
var _salute := PackedFloat32Array([0.34, 0.42, 0.8, 1.95, 0.85, 2.15, 0.24, 0.02, -0.2, -0.26, -1.0, 2.0, 0.0, 2.0])
var _glare := PackedFloat32Array([0.22, 0.35, 0.4, 1.35, 0.32, 1.25, 0.34, -0.1, -0.32, -0.32, 0.0, 3.0, 0.0, 5.0])

## Named poses a FinisherDirector can request via Fighter.script_pose.
var _pose_library: Dictionary = {}
## AttackType -> keyframes [phase, fraction, pose, easing].
var _moves: Dictionary = {}

var _pose := PackedFloat32Array()
var _pose_vel := PackedFloat32Array()
var _seen_hits: int = 0
var _seen_blocks: int = 0
var _down_amount: float = 0.0
## Pose captured when a new swing starts, so chains flow from wherever the body is.
var _swing_from := PackedFloat32Array()
var _seen_swing: int = 0
var _time: float = 0.0
var _shake_x: float = 0.0
# Jump height and roll distance, sampled per tick and interpolated per frame.
var _prev_height: float = 0.0
var _cur_height: float = 0.0
var _height: float = 0.0
var _prev_roll: float = 0.0
var _cur_roll: float = 0.0
# Whole-body rotation (breakfall roll) and finisher spin about the vertical axis.
var _body_rot: float = 0.0
var _tuck_amount: float = 0.0
var _roll_base: float = 0.0
var _was_rolling: bool = false
var _spin_angle: float = 0.0
# Afterimages.
var _trail: Array[Dictionary] = []
var _trail_clock: float = 0.0
var _seen_stance: int = -1
var _swoosh := PackedVector2Array()
var _swoosh_fade: float = 0.0
var _swoosh_striking: bool = false
var _swoosh_joint: int = -1
# Ragdoll state (world space).
var _fk_world := PackedVector2Array()
var _rag_on: bool = false
var _rag_pos := PackedVector2Array()
var _rag_prev := PackedVector2Array()
var _rag_blend: float = 0.0
# Ragdoll positions at the previous tick, for smooth interpolated rendering.
var _rag_last := PackedVector2Array()
var _frac: float = 1.0
# Rest lengths of ragdoll bones, captured when the ragdoll starts.
var _rag_len := PackedFloat32Array()
# Planted feet (world space): positions, step in progress, blend weight.
var _plant: float = 0.0
var _feet_ready: bool = false
var _feet := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
var _step_leg: int = -1
var _last_step_leg: int = -1
var _step_t: float = 0.0
var _step_from := Vector2.ZERO
var _step_to := Vector2.ZERO
var _last_delta: float = 0.0
var _last_hip_x: float = 0.0
var _body_speed: float = 0.0
# Idle breathing (0 = off), scales the torso length slightly.
var _breath: float = 0.0
var _pose_ready: bool = false
## Skeleton as last drawn (world space), for the developer overlay.
var _last_joints := PackedVector2Array()
# Active idle: amount (0..1), hip dip in px and heel lifts (x lead, y rear).
var _idle_amount: float = 0.0
var _bob: float = 0.0
var _bob_target: float = 0.0
var _heel := Vector2.ZERO
var _heel_target := Vector2.ZERO
## Heel lifts for the legs as drawn (swapped for southpaw stances).
var _heel_draw := Vector2.ZERO

@onready var fighter: Fighter = get_parent() as Fighter


func _ready() -> void:
	# Pose literals may omit trailing channels: PIVOT defaults to 0 and SPREAD
	# to the per-pose table (or DEFAULT_SPREAD).
	for prop in get_property_list():
		var value: Variant = get(prop["name"])
		if not value is PackedFloat32Array:
			continue
		var padded: PackedFloat32Array = value
		if padded.size() < PIVOT or padded.size() >= CHANNELS:
			continue
		if padded.size() == PIVOT:
			padded.append(0.0)
		padded.append(POSE_SPREAD.get(prop["name"], DEFAULT_SPREAD))
		set(prop["name"], padded)
	_pose_library = {
		&"guard": _guard, &"stagger": _stagger, &"hitstun": _hitstun, &"hitstun_body": _hitstun_body,
		&"knock_fly": _knock_fly, &"jab_strike": _jab_strike, &"heavy_strike": _heavy_strike,
		&"backhand_strike": _backhand_strike, &"uppercut_strike": _uppercut_strike,
		&"kick_strike": _side_extend, &"jump_squat": _jump_squat, &"jump_rise": _jump_rise,
		&"jump_punch_windup": _hammer_windup, &"jump_punch_strike": _hammer_strike,
		&"hammer_windup": _hammer_windup, &"hammer_strike": _hammer_strike, &"grab": _grab,
		&"palm_lead": _palm_lead, &"palm_rear": _palm_rear, &"land_crouch": _land_crouch,
		&"palm_windup": _palm_windup, &"palm_strike": _palm_strike, &"spin_windup": _spin_windup,
		&"spin_kick": _spin_kick, &"knee_windup": _knee_windup, &"knee": _knee, &"slumped": _slumped,
		&"tornado_windup": _tornado_windup, &"tornado_chamber": _tornado_chamber, &"tornado_kick": _tornado_kick,
		&"relaxed": _relaxed, &"salute": _salute, &"glare": _glare,
	}
	_moves = {
		CombatData.AttackType.LIGHT: [
			[S, 0.45, _jab_windup, EASE_SMOOTH], [A, 0.0, _jab_strike, EASE_IN],
			[A, 1.0, _over(_jab_strike, _jab_windup), EASE_LINEAR], [R, 0.45, null, EASE_OUT]],
		CombatData.AttackType.HEAVY: [
			[S, 0.5, _heavy_windup, EASE_SMOOTH], [A, 0.0, _heavy_strike, EASE_IN],
			[A, 1.0, _over(_heavy_strike, _heavy_windup), EASE_LINEAR], [R, 0.25, _heavy_strike, EASE_LINEAR]],
		CombatData.AttackType.BACKHAND: [
			[S, 0.5, _backhand_windup, EASE_SMOOTH], [A, 0.0, _backhand_strike, EASE_IN],
			[A, 1.0, _over(_backhand_strike, _backhand_windup), EASE_LINEAR]],
		CombatData.AttackType.UPPERCUT: [
			[S, 0.55, _uppercut_windup, EASE_SMOOTH], [A, 0.0, _uppercut_strike, EASE_IN],
			[A, 1.0, _over(_uppercut_strike, _uppercut_windup), EASE_LINEAR], [R, 0.2, _uppercut_strike, EASE_LINEAR]],
		CombatData.AttackType.KICK: [
			[S, 0.5, _side_chamber, EASE_SMOOTH], [A, 0.0, _side_extend, EASE_IN],
			[A, 1.0, _over(_side_extend, _side_chamber), EASE_LINEAR], [R, 0.4, _side_chamber, EASE_OUT]],
		CombatData.AttackType.FRONT_KICK: [
			[S, 0.55, _front_chamber, EASE_SMOOTH], [A, 0.0, _front_extend, EASE_IN],
			[A, 1.0, _over(_front_extend, _front_chamber), EASE_LINEAR], [R, 0.4, _front_chamber, EASE_OUT]],
		CombatData.AttackType.JUMP_KICK: [
			[S, 0.5, _jk_chamber, EASE_SMOOTH], [A, 0.0, _jk_extend, EASE_IN],
			[A, 1.0, _jk_extend, EASE_LINEAR], [R, 0.5, _jk_chamber, EASE_OUT]],
		CombatData.AttackType.JUMP_PUNCH: [
			[S, 0.4, _jump_punch_windup, EASE_SMOOTH], [A, 0.0, _jump_punch_strike, EASE_IN],
			[A, 1.0, _over(_jump_punch_strike, _jump_punch_windup), EASE_LINEAR]],
		CombatData.AttackType.HIGH_KICK: [
			[S, 0.5, _high_chamber, EASE_SMOOTH], [A, 0.0, _high_extend, EASE_IN],
			[A, 1.0, _over(_high_extend, _high_chamber), EASE_LINEAR], [R, 0.4, _high_chamber, EASE_OUT]],
		CombatData.AttackType.SWEEP: [
			[S, 0.45, _sweep_load, EASE_SMOOTH], [S, 0.85, _sweep_chamber, EASE_SMOOTH],
			[A, 0.0, _sweep_extend, EASE_IN], [A, 1.0, _over(_sweep_extend, _sweep_chamber), EASE_LINEAR],
			[R, 0.3, _sweep_follow, EASE_OUT], [R, 0.65, _sweep_load, EASE_SMOOTH]],
		CombatData.AttackType.BACK_KICK: [
			[S, 0.7, _back_chamber, EASE_SMOOTH], [A, 0.0, _back_extend, EASE_IN],
			[A, 1.0, _over(_back_extend, _back_chamber), EASE_LINEAR], [R, 0.35, _back_chamber, EASE_OUT]],
	}
	_build_light_reactions()
	_pose = _guard.duplicate()
	_swing_from = _guard.duplicate()
	_pose_vel.resize(CHANNELS)
	_pose_vel.fill(0.0)
	if fighter != null:
		_seen_swing = fighter.swing_id
		_seen_hits = fighter.hit_counter
		_seen_blocks = fighter.block_counter


## Light reactions sit between the stance guard and the full reaction: a
## flinch that keeps the guard partly up.
func _build_light_reactions() -> void:
	_hitstun_light = _blend(_guard, _hitstun, 0.5)
	_hitstun_body_light = _blend(_guard, _hitstun_body, 0.5)


## The guard is the fighter's stance: every move starts from it and returns to it.
func _sync_stance() -> void:
	if fighter.stance == _seen_stance:
		return
	_seen_stance = fighter.stance
	_guard = Stances.pose(fighter.stance)
	while _guard.size() < CHANNELS:
		_guard.append(DEFAULT_SPREAD if _guard.size() == SPREAD else 0.0)
	_pose_library[&"guard"] = _guard
	_build_light_reactions()


## Strike pose pushed slightly past its line of travel (follow-through).
static func _over(strike: PackedFloat32Array, from: PackedFloat32Array) -> PackedFloat32Array:
	var out := strike.duplicate()
	for i in out.size():
		out[i] = strike[i] + (strike[i] - from[i]) * 0.08
	return out


func _physics_process(_delta: float) -> void:
	# Runs after main.gd has ticked the fighter (parents process first).
	if fighter == null:
		return
	_prev_height = _cur_height
	_cur_height = maxf(fighter.ground_y - fighter.position.y, 0.0)
	_prev_roll = _cur_roll if fighter.rolling else fighter.roll_distance
	_cur_roll = fighter.roll_distance
	_update_ragdoll()


func _process(delta: float) -> void:
	if fighter == null:
		return
	_time += delta
	_last_delta = delta
	_sync_stance()
	var calm := fighter.state in [Fighter.State.IDLE, Fighter.State.WALK, Fighter.State.BLOCK, Fighter.State.CROUCH]
	_breath = move_toward(_breath, sin(_time * TAU * 0.32) if calm else 0.0, delta * 3.0)
	_update_idle_amount(delta)
	_bob_target = 0.0
	_heel_target = Vector2.ZERO
	var frozen := fighter.hitstop_frames > 0
	# During hitstop nothing moves, so show the current tick: the impact freeze
	# must display the fully extended strike, not the frame before contact.
	var fraction := 1.0 if frozen else Engine.get_physics_interpolation_fraction()
	_frac = fraction
	# Rendered positions lag one tick behind the simulation (interpolating from the
	# previous tick to the current one), so sample poses on the same timeline.
	var t := maxf(float(fighter.state_frame) - 1.0 + fraction, 0.0)
	_height = lerpf(_prev_height, _cur_height, fraction)

	if fighter.swing_id != _seen_swing:
		_seen_swing = fighter.swing_id
		_swing_from = _pose.duplicate()

	_apply_impulses()
	var target := _target_pose(t)
	var dt := minf(delta, 1.0 / 30.0)
	if not _pose_ready:
		# First frame: start in the target pose instead of springing into it.
		_pose_ready = true
		_pose = target.duplicate()
	elif fighter.state == Fighter.State.ATTACK:
		target = _limit_reach(target)
		# Attack timelines are continuous (they start from _swing_from), so follow
		# them exactly, but record joint velocity: if the attack is interrupted,
		# that momentum carries into the reaction.
		for i in CHANNELS:
			if dt > 0.0:
				_pose_vel[i] = _clamp_speed(i, (target[i] - _pose[i]) / dt)
		_pose = target
	elif dt > 0.0:
		_spring_toward(target, dt, _spring_params())

	_update_down_amount(t)
	_update_spin(dt, fraction)
	if _is_back_kick():
		_spin_angle = PI * _back_turn(t)
	# Idle dip and heel lifts ease toward the wave (and to zero when acting).
	var ease := 1.0 - exp(-20.0 * dt)
	_bob = lerpf(_bob, clampf(_bob_target, 0.0, MAX_IDLE_BOB), ease)
	_heel = _heel.lerp(_heel_target.clamp(Vector2.ZERO, Vector2.ONE * MAX_HEEL_LIFT), ease)
	_update_trail(delta)
	_swoosh_fade = maxf(_swoosh_fade - delta / maxf(Engine.time_scale, 0.01), 0.0)
	if not _rag_on and _rag_blend > 0.0:
		_rag_blend = maxf(_rag_blend - delta / maxf(Engine.time_scale, 0.01) / RAG_BLEND_TIME, 0.0)

	# Hitstop shake on the fighter taking the hit (presentation only).
	_shake_x = 0.0
	var stunned := fighter.state == Fighter.State.HITSTUN or fighter.state == Fighter.State.BLOCKSTUN \
		or fighter.state == Fighter.State.STAGGER \
		or fighter.state == Fighter.State.FINISHED or fighter.is_down()
	if frozen and stunned:
		_shake_x = 3.0 if fighter.hitstop_frames % 2 == 0 else -3.0
	queue_redraw()


# --- Ragdoll ------------------------------------------------------------------

## Limp bodies (knocked down without a breakfall roll, or knocked out) become a
## ragdoll. A trained breakfall roll and the Wall Crush slump stay animated.
func _wants_ragdoll() -> bool:
	if not fighter.is_down() or _is_balled():
		return false
	if fighter.state == Fighter.State.KO and fighter.script_pose == &"slumped":
		return false
	return fighter.state == Fighter.State.KO or fighter.pending_rolls == 0


func _update_ragdoll() -> void:
	var want := _wants_ragdoll()
	if want and not _rag_on and _fk_world.size() == JOINTS:
		_rag_on = true
		_rag_blend = 1.0
		_rag_pos = _fk_world.duplicate()
		_rag_prev = _fk_world.duplicate()
		_rag_last = _fk_world.duplicate()
		_rag_len = PackedFloat32Array()
		for bone in _RAG_BONES:
			_rag_len.append(_fk_world[bone.x].distance_to(_fk_world[bone.y]))
		_seed_ragdoll()
	elif not want and _rag_on:
		_rag_on = false  # _rag_blend fades to the animated pose in _process
	if not _rag_on or fighter.hitstop_frames > 0:
		return
	_rag_last = _rag_pos.duplicate()
	var floor_y := fighter.ground_y
	var min_x := Fighter.ARENA_MIN_X - 20.0
	var max_x := Fighter.ARENA_MAX_X + 20.0
	for i in JOINTS:
		var p := _rag_pos[i]
		var v := (p - _rag_prev[i]) * RAG_DAMPING
		_rag_prev[i] = p
		_rag_pos[i] = p + v + Vector2(0.0, RAG_GRAVITY)
	# Keep the limp body with the simulated (gameplay) body horizontally.
	var follow := (fighter.position.x - _rag_pos[J_HIP].x) * RAG_FOLLOW
	for i in JOINTS:
		_rag_pos[i].x += follow
	for iteration in RAG_ITERATIONS:
		for b in _RAG_BONES.size():
			_satisfy(_RAG_BONES[b].x, _RAG_BONES[b].y, _rag_len[b], false)
		# Soft limits stop limbs folding flat (no knees bending through the shin).
		_satisfy(J_HIP_F, J_FOOT_F, (THIGH + SHIN) * 0.55, true)
		_satisfy(J_HIP_B, J_FOOT_B, (THIGH + SHIN) * 0.55, true)
		_satisfy(J_SHOULDER_F, J_HAND_F, (UPPER_ARM + FOREARM) * 0.45, true)
		_satisfy(J_SHOULDER_B, J_HAND_B, (UPPER_ARM + FOREARM) * 0.45, true)
		_satisfy(J_HIP, J_HEAD, TORSO_LEN + NECK, true)
		for i in JOINTS:
			var r := HEAD_R if i == J_HEAD else LIMB_WIDTH * 0.5
			var p := _rag_pos[i]
			if p.y > floor_y - r:
				p.y = floor_y - r
				# Floor friction: bleed horizontal speed on contact.
				_rag_prev[i].x = lerpf(_rag_prev[i].x, p.x, 1.0 - RAG_FLOOR_FRICTION)
			p.x = clampf(p.x, min_x + r, max_x - r)
			_rag_pos[i] = p


## Ragdoll bones; rest lengths are taken from the pose at the moment it starts.
const _RAG_BONES: Array[Vector2i] = [
	Vector2i(J_HIP_F, J_KNEE_F), Vector2i(J_KNEE_F, J_FOOT_F), Vector2i(J_HIP_B, J_KNEE_B),
	Vector2i(J_KNEE_B, J_FOOT_B), Vector2i(J_HIP, J_NECK), Vector2i(J_NECK, J_HEAD),
	Vector2i(J_SHOULDER_F, J_ELBOW_F), Vector2i(J_ELBOW_F, J_HAND_F), Vector2i(J_SHOULDER_B, J_ELBOW_B),
	Vector2i(J_ELBOW_B, J_HAND_B), Vector2i(J_HIP, J_SHOULDER), Vector2i(J_NECK, J_SHOULDER),
	Vector2i(J_SHOULDER, J_SHOULDER_F), Vector2i(J_SHOULDER, J_SHOULDER_B), Vector2i(J_SHOULDER_F, J_SHOULDER_B),
	Vector2i(J_HIP, J_HIP_F), Vector2i(J_HIP, J_HIP_B), Vector2i(J_HIP_F, J_HIP_B), Vector2i(J_HIP_F, J_NECK),
]


## Initial ragdoll motion: the body's flight velocity plus a spin around the hip
## proportional to how hard it was thrown (upper body whips back, legs sweep
## up). A swept fighter instead has the feet kicked out from under them.
func _seed_ragdoll() -> void:
	var vel := Vector2(fighter.jump_vx + fighter.velocity_x, fighter.velocity_y)
	var away := signf(vel.x) if not is_zero_approx(vel.x) else float(-fighter.facing)
	var hip := _rag_pos[J_HIP]
	var spin := clampf(vel.length() * 0.012, 0.03, 0.14) * -away
	for i in JOINTS:
		var r := _rag_pos[i] - hip
		var swirl := Vector2(-r.y, r.x) * spin  # tangential velocity of a rotation
		var extra := Vector2.ZERO
		if fighter.last_hit_low:
			# Swept: the feet are kicked out toward the sweeper and up, the head
			# drops back and away (the body flips onto its back).
			var low := clampf(r.y / 80.0, -1.0, 1.0)
			extra = Vector2(-away * 3.0 * low, -5.0 * maxf(low, 0.0))
			swirl *= 0.3
		_rag_prev[i] -= vel + swirl + extra


## Distance constraint; `at_least` only pushes points apart (soft joint limit).
func _satisfy(a: int, b: int, length: float, at_least: bool) -> void:
	var delta := _rag_pos[b] - _rag_pos[a]
	var d := delta.length()
	if d < 0.0001 or (at_least and d >= length):
		return
	var correction := delta * ((d - length) / d) * 0.5
	_rag_pos[a] += correction
	_rag_pos[b] -= correction


# --- Rolling, spinning, afterimages -------------------------------------------

## A controlled breakfall (knockdown with rolls) curls into a ball. Limp KO'd
## bodies are ragdolls instead.
func _is_balled() -> bool:
	if fighter.state == Fighter.State.EVADE_ROLL:
		# Tucked from the end of the startup until the roll has travelled.
		return fighter.state_frame >= CombatData.ROLL_STARTUP - 1 and fighter.is_rolling_through()
	return fighter.state == Fighter.State.KNOCKDOWN and (fighter.rolling or (fighter.airborne and fighter.tumble))


func _update_spin(dt: float, fraction: float) -> void:
	var balled := _is_balled()
	_tuck_amount = move_toward(_tuck_amount, 1.0 if balled else 0.0, dt * 14.0)
	if fighter.state == Fighter.State.EVADE_ROLL and balled:
		# Evasive roll: the ball turns by the distance actually travelled
		# (rolls without slipping, forward or backward).
		var roll_dir := float(fighter.dodge_world_dir * fighter.facing)
		_body_rot = roll_dir * fighter.evade_travelled / ROLL_RADIUS
	elif fighter.rolling and balled:
		var local_dir := float(fighter.roll_dir * fighter.facing)
		var dist := lerpf(_prev_roll, _cur_roll, fraction)
		if not _was_rolling:
			_roll_base = _body_rot - local_dir * dist / ROLL_RADIUS
		_body_rot = _roll_base + local_dir * dist / ROLL_RADIUS
	elif balled:
		var travel := signf(fighter.jump_vx) * fighter.facing
		_body_rot += (travel if travel != 0.0 else -1.0) * TUMBLE_SPIN * dt
	else:
		_body_rot = lerp_angle(_body_rot, 0.0, 1.0 - exp(-14.0 * dt))
	_was_rolling = fighter.rolling and balled
	# Finisher spin about the vertical axis (Tornado Kick): advance while the
	# director asks for it, otherwise settle onto the nearest full turn.
	if fighter.state == Fighter.State.FINISHER and fighter.script_spin_rate != 0.0:
		_spin_angle += fighter.script_spin_rate * TAU * 60.0 * dt * (0.0 if fighter.hitstop_frames > 0 else 1.0)
	else:
		_spin_angle = lerp_angle(_spin_angle, 0.0, 1.0 - exp(-18.0 * dt))


func _trail_active() -> bool:
	match fighter.state:
		Fighter.State.ATTACK:
			var attack := fighter.current_attack
			if attack == null:
				return false
			var f := fighter.state_frame
			return f >= int(attack.startup * 0.6) and f < attack.startup + attack.active + 3
		Fighter.State.FINISHER:
			return true
		Fighter.State.DODGE:
			return fighter.is_evading()
		Fighter.State.KNOCKDOWN, Fighter.State.KO, Fighter.State.FINISHED:
			return fighter.airborne or fighter.rolling
	return false


func _update_trail(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	for i in range(_trail.size() - 1, -1, -1):
		_trail[i]["age"] += real_delta
		if _trail[i]["age"] >= TRAIL_LIFE:
			_trail.remove_at(i)
	_trail_clock += real_delta


# --- Springs and impulses -----------------------------------------------------

func _spring_params() -> Vector2:
	if _is_balled():
		return SPRING_FAST
	match fighter.state:
		Fighter.State.HITSTUN, Fighter.State.FINISHED, Fighter.State.STAGGER, Fighter.State.BROKEN:
			return SPRING_HITSTUN
		Fighter.State.KNOCKDOWN, Fighter.State.KO:
			return SPRING_LIMP
		Fighter.State.FINISHER, Fighter.State.JUMP, Fighter.State.BLOCK, Fighter.State.DODGE, Fighter.State.CROUCH, Fighter.State.PARRY:
			return SPRING_FAST
	return SPRING_DEFAULT


## Damped spring per joint (semi-implicit Euler): overshoot and settle.
func _spring_toward(target: PackedFloat32Array, dt: float, params: Vector2) -> void:
	var stiffness := params.x
	var damping := 2.0 * sqrt(stiffness) * params.y
	for i in CHANNELS:
		var accel := stiffness * (target[i] - _pose[i]) - damping * _pose_vel[i]
		_pose_vel[i] = _clamp_speed(i, _pose_vel[i] + accel * dt)
		_pose[i] += _pose_vel[i] * dt


func _clamp_speed(channel: int, speed: float) -> float:
	var limit := MAX_LINEAR_SPEED if channel == HIP_X or channel == DROP else MAX_ANGULAR_SPEED
	return clampf(speed, -limit, limit)


## Clean hits whip the joints (head hits snap back, body hits fold forward);
## blocked hits jolt the guard back into the face. Springs handle the rest.
func _apply_impulses() -> void:
	if fighter.hit_counter != _seen_hits:
		_seen_hits = fighter.hit_counter
		# Heavier hits whip harder; light ones are a short flinch.
		var k := 1.25 if fighter.last_hit_heavy else 0.6
		if fighter.last_hit_high:
			_pose_vel[TORSO] -= 9.0 * k
			_pose_vel[HEAD] -= 14.0 * k
			_pose_vel[HIP_X] -= 120.0 * k
		else:
			_pose_vel[TORSO] += 7.0 * k
			_pose_vel[HEAD] += 6.0 * k
			_pose_vel[DROP] += 90.0 * k
		_pose_vel[UA_F] -= 6.0 * k
		_pose_vel[UA_B] -= 5.0 * k
	if fighter.block_counter != _seen_blocks:
		_seen_blocks = fighter.block_counter
		_pose_vel[TORSO] -= 5.0
		_pose_vel[UA_F] -= 5.0
		_pose_vel[UA_B] -= 4.0
		_pose_vel[LA_F] += 4.0
		_pose_vel[HIP_X] -= 160.0
		_pose_vel[DROP] += 60.0


## How "horizontal" the body is (0 standing .. 1 lying); stretches the shadow.
func _update_down_amount(t: float) -> void:
	var down := 0.0
	match fighter.state:
		Fighter.State.KNOCKDOWN, Fighter.State.KO:
			down = 0.3 if _is_balled() else smoothstep(0.0, 1.0, t / FALL_FRAMES)
		Fighter.State.GETUP:
			if not fighter.getup_from_roll:
				down = 1.0 - smoothstep(0.0, 0.55, t / float(fighter.getup_frames))
	_down_amount = down


# --- Pose selection -----------------------------------------------------------

func _target_pose(t: float) -> PackedFloat32Array:
	if fighter.prefight_pose != &"" and (fighter.state == Fighter.State.IDLE or fighter.state == Fighter.State.WALK):
		# Before the fight: the springs carry the body between these poses, so
		# relaxed -> gesture -> stance guard all blend smoothly.
		var pre: PackedFloat32Array = _pose_library.get(fighter.prefight_pose, _guard).duplicate()
		pre[HIP_X] += sin(_time * TAU * 0.3) * 1.5  # settling weight, feet planted
		return pre
	match fighter.state:
		Fighter.State.WALK:
			return _walk_pose()
		Fighter.State.ATTACK:
			return _attack_pose(t)
		Fighter.State.CROUCH:
			return _crouch
		Fighter.State.BLOCK:
			return _crouch_block if fighter.crouch_held else _block
		Fighter.State.BLOCKSTUN:
			var guard := _crouch_block if fighter.crouch_held else _block
			return _recover(_blockstun if not fighter.crouch_held else _crouch_block, guard, t, fighter.stun_frames)
		Fighter.State.DODGE:
			var d := _dodge_slip if fighter.dodge_relative > 0 else _dodge_back
			var f := t
			if f < CombatData.DODGE_INVULN_START:
				return _blend(_guard, d, f / CombatData.DODGE_INVULN_START)
			if f < CombatData.DODGE_INVULN_END:
				return d
			return _blend(d, _guard, smoothstep(0.0, 1.0, (f - CombatData.DODGE_INVULN_END) / float(CombatData.DODGE_FRAMES - CombatData.DODGE_INVULN_END)))
		Fighter.State.EVADE_ROLL:
			if _is_balled():
				return _tuck
			var travel_end := CombatData.ROLL_STARTUP + CombatData.ROLL_TRAVEL
			if t < travel_end:
				# Anticipation: drop low and lean into the roll.
				return _blend(_guard, _jump_squat, smoothstep(0.0, float(CombatData.ROLL_STARTUP), t))
			# Recovery: come out of the tuck in a crouch and rise to the stance.
			return _blend(_getup_crouch, _guard, smoothstep(float(travel_end), float(travel_end + CombatData.ROLL_RECOVERY), t))
		Fighter.State.PARRY:
			return _blend(_deflect, _block if fighter.block_held else _guard,
				smoothstep(0.3, 1.0, t / float(CombatData.PARRY_DEFLECT_FRAMES)))
		Fighter.State.BROKEN:
			var wob := _broken.duplicate()
			var w := sin(_time * TAU * 1.6)
			wob[TORSO] += w * 0.08
			wob[HEAD] += w * 0.12
			wob[HIP_X] += w * 3.0
			return _recover(wob, _guard, t, fighter.stun_frames)
		Fighter.State.STAGGER:
			# Thrown off balance by the parry: reel back, then regain the stance.
			return _recover(_stagger, _guard, t, fighter.stun_frames)
		Fighter.State.GUARD_RELEASE:
			return _blend(_block, _guard, smoothstep(0.0, 1.0, t / maxf(float(fighter.stun_frames), 1.0)))
		Fighter.State.HITSTUN:
			return _recover(_reaction_pose(), _guard, t, fighter.stun_frames)
		Fighter.State.KNOCKDOWN:
			if _is_balled():
				return _tuck
			return _blend(_knock_fly, _ko, smoothstep(0.0, 1.0, t / FALL_FRAMES))
		Fighter.State.GETUP:
			var g := t / float(fighter.getup_frames)
			if fighter.getup_from_roll:
				# Came out of a backward roll already crouched: just rise.
				return _getup_crouch if g < 0.4 else _blend(_getup_crouch, _guard, smoothstep(0.4, 1.0, g))
			if g < 0.35:
				return _blend(_ko, _getup_sit, smoothstep(0.0, 0.35, g))
			if g < 0.7:
				return _blend(_getup_sit, _getup_crouch, smoothstep(0.35, 0.7, g))
			return _blend(_getup_crouch, _guard, smoothstep(0.7, 1.0, g))
		Fighter.State.JUMP:
			return _air_pose() if fighter.airborne else _jump_squat
		Fighter.State.LAND:
			return _blend(_land, _guard, smoothstep(0.0, 1.0, t / maxf(float(fighter.stun_frames), 1.0)))
		Fighter.State.KO:
			return _slumped if fighter.script_pose == &"slumped" else _ko
		Fighter.State.FINISHER, Fighter.State.FINISHED:
			return _pose_library.get(fighter.script_pose, _guard)
	return _active_idle()


## Neutral fighting movement for the current stance: a bounce (the hips dip
## over planted feet, see _plant_feet), weight shifts between the feet, heel
## lifts, shoulder roll, torso sway with a level head and small guard
## adjustments. Each fighter has its own tempo and phase (Fighter.idle_*).
func _active_idle() -> PackedFloat32Array:
	var st := Stances.active_idle(fighter.stance)
	var idle := _guard.duplicate()
	var k := _idle_amount
	if k <= 0.0:
		return idle
	var t := _time * fighter.idle_tempo + fighter.idle_phase
	var shape: String = st["shape"]
	var hz: float = st["hz"]
	var shift_hz: float = st["shift_hz"]
	var dip := _idle_wave(shape, hz * t)
	var shift := sin(TAU * shift_hz * t)
	if shape == "snap":
		shift = tanh(3.0 * shift) / tanh(3.0)  # settle and hold, then a quick adjustment
	_bob_target = float(st["bob"]) * dip * k
	# Heels: up on the balls of the feet as the hips rise out of a bounce, or the
	# rear heel as the weight rocks forward (lead heel as it rocks back).
	var rise := 1.0 - dip if shape == "hop" else 0.5 + 0.5 * shift
	_heel_target = Vector2(float(st["lead_heel"]) * (0.5 - 0.5 * shift), float(st["heel"]) * rise) * k
	idle[HIP_X] += float(st["shift"]) * shift * k
	idle[SPREAD] += float(st["shoulder"]) * sin(TAU * shift_hz * t + 0.8) * k
	var sway := float(st["sway"]) * sin(PI * shift_hz * t) * k
	idle[TORSO] += sway
	idle[HEAD] -= sway * 0.8  # eyes stay level on the opponent
	var head_wave := sin(TAU * hz * 0.5 * t + 1.3)
	if shape == "snap":
		head_wave = tanh(4.0 * head_wave) / tanh(4.0)
	idle[HEAD] += float(st["head"]) * head_wave * k
	var g := float(st["guard"]) * k
	var gp := TAU * shift_hz * t
	if st.get("circles", false):
		# Kung fu: both hands trace small circles, opposite phase.
		idle[UA_F] += g * sin(gp * 2.0)
		idle[LA_F] += g * cos(gp * 2.0)
		idle[UA_B] += g * 0.8 * sin(gp * 2.0 + PI)
		idle[LA_B] += g * 0.8 * cos(gp * 2.0 + PI)
	else:
		idle[UA_F] += g * sin(gp * 1.7 + 0.4)
		idle[LA_F] += g * 0.7 * sin(gp * 2.3 + 1.0)
		idle[UA_B] += g * 0.6 * sin(gp * 1.3 + 2.0)
	return idle


## Bounce dip 0..1 at `phase` (cycles): "hop" = springy landing dips,
## "sine" = smooth, "snap" = settle-and-hold with quick transitions.
static func _idle_wave(shape: String, phase: float) -> float:
	match shape:
		"hop":
			return 1.0 - absf(sin(PI * phase))
		"snap":
			return 0.5 + 0.5 * tanh(4.0 * sin(TAU * phase)) / tanh(4.0)
	return 0.5 - 0.5 * cos(TAU * phase)


func _update_idle_amount(delta: float) -> void:
	var idle_ok := fighter.state == Fighter.State.IDLE and fighter.prefight_pose == &""
	var target := 1.0 if idle_ok else 0.0
	target *= 1.0 - IDLE_POSTURE_DAMP * smoothstep(0.5, 1.0, fighter.posture / CombatData.POSTURE_MAX)
	var rate := IDLE_FADE_IN if target > _idle_amount else IDLE_FADE_OUT
	_idle_amount = move_toward(_idle_amount, target, delta * rate)


func _is_back_kick() -> bool:
	return fighter.state == Fighter.State.ATTACK and fighter.current_attack != null \
		and fighter.current_attack.type == CombatData.AttackType.BACK_KICK


## Back kick body turn in half-turns: 0 -> 1 (back to the opponent) through the
## startup, held through the strike, then 1 -> 2 (a full turn, facing again)
## through the recovery.
func _back_turn(t: float) -> float:
	var attack := fighter.current_attack
	var turned := smoothstep(0.0, attack.startup * 0.75, t)
	var strike_end := float(attack.startup + attack.active)
	var back := smoothstep(strike_end + attack.recovery * 0.3, strike_end + attack.recovery * 0.9, t)
	return turned + back


## Hit reaction by where and how hard the hit landed: launched (in the air),
## head (light flinch / heavy whip) or body (light / heavy fold).
func _reaction_pose() -> PackedFloat32Array:
	if fighter.airborne:
		return _launched
	if fighter.last_hit_high:
		return _hitstun_heavy if fighter.last_hit_heavy else _hitstun_light
	return _hitstun_body if fighter.last_hit_heavy else _hitstun_body_light


## Holds a reaction pose, then eases back over the last part of the stun.
func _recover(reaction: PackedFloat32Array, back_to: PackedFloat32Array, t: float, duration: int) -> PackedFloat32Array:
	var k := smoothstep(0.55, 1.0, t / maxf(float(duration), 1.0))
	return _blend(reaction, back_to, k)


func _walk_pose() -> PackedFloat32Array:
	# The stance itself: the planted-feet stepping moves the legs. The body just
	# leans slightly into the direction of travel and bobs with each step.
	var pose := _guard.duplicate()
	var dir := float(fighter.move_input * fighter.facing)
	pose[TORSO] += 0.06 * dir
	pose[HIP_X] += 3.0 * dir
	return pose


## Stretch while rising, tuck at the apex, extend the legs while falling.
func _air_pose() -> PackedFloat32Array:
	var k := clampf(fighter.velocity_y / 9.0, -1.0, 1.0)
	var pose := _blend(_jump_air, _jump_rise, -k) if k < 0.0 else _blend(_jump_air, _jump_fall, k)
	# Lean into the direction of travel.
	pose[TORSO] += clampf(fighter.jump_vx * fighter.facing * 0.03, -0.14, 0.14)
	return pose


## Samples the move's keyframe timeline at tick time t.
func _attack_pose(t: float) -> PackedFloat32Array:
	var attack := fighter.current_attack
	if attack == null:
		return _guard
	var rest := _air_pose() if fighter.airborne else _guard
	var keys: Array = _moves.get(attack.type, [])
	var prev_t := 0.0
	var prev_pose := _swing_from
	for key in keys:
		var key_t := _key_time(key[0], key[1], attack)
		var key_pose: PackedFloat32Array = key[2] if key[2] != null else rest
		if t < key_t:
			var u := (t - prev_t) / maxf(key_t - prev_t, 0.001)
			return _blend(prev_pose, key_pose, _ease(u, key[3]))
		prev_t = key_t
		prev_pose = key_pose
	var total := float(attack.total_frames())
	var w := (t - prev_t) / maxf(total - prev_t, 0.001)
	return _blend(prev_pose, rest, smoothstep(0.0, 1.0, w))


static func _key_time(phase: int, fraction: float, attack: CombatData.Attack) -> float:
	match phase:
		S:
			return fraction * attack.startup
		A:
			return attack.startup + fraction * attack.active
	return attack.startup + attack.active + fraction * attack.recovery


static func _ease(u: float, kind: int) -> float:
	u = clampf(u, 0.0, 1.0)
	match kind:
		EASE_IN:
			return u * u  # accelerate into the impact
		EASE_OUT:
			return 1.0 - (1.0 - u) * (1.0 - u)
		EASE_LINEAR:
			return u
	return smoothstep(0.0, 1.0, u)


func _blend(a: PackedFloat32Array, b: PackedFloat32Array, t: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(CHANNELS)
	var k := clampf(t, 0.0, 1.0)
	for i in CHANNELS:
		out[i] = lerpf(a[i], b[i], k)
	return out


static func _limb_dir(angle: float) -> Vector2:
	return Vector2(sin(angle), cos(angle))


# --- Drawing ------------------------------------------------------------------

## Forward kinematics: joint positions (local, facing right) for a pose.
func _solve_joints(p: PackedFloat32Array) -> PackedVector2Array:
	var hip := Vector2(p[HIP_X], -AIR_HIP_HEIGHT - p[DROP])
	# On the ground (or while falling / lying) the supporting foot is planted on
	# the floor: crouching comes from bending the knees, never from floating.
	# The hip never sinks below the body's own thickness when legs are flat.
	if not fighter.airborne or fighter.is_down():
		var leg_f := THIGH * cos(p[TH_F]) + SHIN * cos(p[SH_F])
		var leg_b := THIGH * cos(p[TH_B]) + SHIN * cos(p[SH_B])
		hip.y = -maxf(maxf(leg_f, leg_b), TORSO_WIDTH * 0.5 + 1.0)
	hip = hip.lerp(TUCK_HIP, smoothstep(0.0, 1.0, _tuck_amount))
	var torso_dir := Vector2(sin(p[TORSO]), -cos(p[TORSO]))
	# Body rotation: lead shoulder / hip sit in front of the rear ones.
	var across := Vector2(cos(p[TORSO]), sin(p[TORSO]))
	var spread := p[SPREAD] * (1.0 - _tuck_amount)
	var hip_f := hip + across * spread * 0.3
	var hip_b := hip - across * spread * 0.3
	var knee_f := hip_f + _limb_dir(p[TH_F]) * THIGH
	var knee_b := hip_b + _limb_dir(p[TH_B]) * THIGH
	var torso_len := TORSO_LEN * (1.0 + 0.03 * _breath)  # chest rises with each breath
	var neck := hip + torso_dir * torso_len
	var shoulder := hip + torso_dir * (torso_len - 6.0)
	var shoulder_f := shoulder + across * spread * 0.5
	var shoulder_b := shoulder - across * spread * 0.5
	var head_angle := p[TORSO] + p[HEAD]
	var elbow_f := shoulder_f + _limb_dir(p[UA_F]) * UPPER_ARM
	var elbow_b := shoulder_b + _limb_dir(p[UA_B]) * UPPER_ARM
	return PackedVector2Array([
		hip, knee_f, knee_f + _limb_dir(p[SH_F]) * SHIN, knee_b, knee_b + _limb_dir(p[SH_B]) * SHIN,
		neck, shoulder, elbow_f, elbow_f + _limb_dir(p[LA_F]) * FOREARM, elbow_b,
		elbow_b + _limb_dir(p[LA_B]) * FOREARM,
		neck + Vector2(sin(head_angle), -cos(head_angle)) * (NECK + HEAD_R),
		shoulder_f, shoulder_b, hip_f, hip_b,
	])


func _draw() -> void:
	if fighter == null:
		return
	var front := fighter.body_color
	if fighter.flash_frames > 0:
		# Hit flash: strong on light fighters, a hot rim-coloured flash on dark ones
		# (so a dark fighter never turns into a white silhouette).
		front = front.lerp(Color.WHITE, 0.75) if front.get_luminance() > 0.4 else front.lerp(fighter.outline_color, 0.45)
	# Far-side limbs: darker on a light fighter, a touch lighter on a dark one.
	var back := front.darkened(0.32) if front.get_luminance() > 0.4 else front.lerp(fighter.outline_color, 0.22)
	var accent := fighter.accent_color
	# Mirror for facing; script_flip turns away (spins), and the finisher spin
	# squashes the body edge-on as it turns about the vertical axis.
	var face := float(fighter.facing) * (-1.0 if fighter.script_flip else 1.0) * cos(_spin_angle)
	if absf(face) < 0.08:
		face = 0.08 * signf(face) if face != 0.0 else 0.08
	var mirror := Transform2D(0.0, Vector2(face, 1.0), 0.0, Vector2(_shake_x, 0.0))

	# Ground shadow: stays on the floor, shrinks with height, stretches when lying.
	var shadow_scale := clampf(1.0 - _height / 260.0, 0.45, 1.0)
	var shadow_len := shadow_scale * lerpf(1.0, 2.2, _down_amount)
	var shadow_x := -40.0 * _down_amount
	if _rag_on:
		shadow_x = (to_local(_rag_pos[J_HIP]).x) * signf(face) - 10.0
	draw_set_transform_matrix(mirror * Transform2D(0.0, Vector2(shadow_len, 0.22 * shadow_scale), 0.0,
		Vector2(shadow_x, 2.0 + _height)))
	draw_circle(Vector2.ZERO, 38.0, Color(0.0, 0.0, 0.0, 0.35 * shadow_scale))

	# Breakfall roll: rotate the curled body around its centre.
	var body := Transform2D(0.0, Vector2.ONE, 0.0, TUCK_PIVOT) \
		* Transform2D(_body_rot, Vector2.ONE, 0.0, Vector2.ZERO) \
		* Transform2D(0.0, Vector2.ONE, 0.0, -TUCK_PIVOT)
	var xform := mirror * body
	var to_world := get_global_transform() * xform
	var joints := _solve_joints(_pose)
	_fk_world = to_world * joints

	# Choose the skeleton to draw: animated, ragdoll, or blending between them.
	var world_joints := _fk_world
	if _rag_on:
		# Interpolate between ticks so flying bodies stay smooth at any frame
		# rate, including slow motion.
		world_joints = PackedVector2Array()
		for i in JOINTS:
			world_joints.append(_rag_last[i].lerp(_rag_pos[i], _frac) if _rag_last.size() == JOINTS else _rag_pos[i])
	elif _rag_blend > 0.0 and _rag_pos.size() == JOINTS:
		world_joints = PackedVector2Array()
		for i in JOINTS:
			world_joints.append(_rag_pos[i].lerp(_fk_world[i], 1.0 - _rag_blend))
	else:
		world_joints = _plant_feet(_fk_world.duplicate(), to_world, Vector2(signf(face), 0.0))

	# Afterimages (world space) behind the body.
	var trail_accent := fighter.state in [Fighter.State.ATTACK, Fighter.State.FINISHER, Fighter.State.DODGE]
	_draw_trail(accent if trail_accent else front)
	if _trail_active() and _trail_clock >= TRAIL_INTERVAL:
		_trail_clock = 0.0
		_trail.append({"pts": world_joints, "age": 0.0})
		if _trail.size() > TRAIL_MAX:
			_trail.pop_front()

	# Draw the body in world space so animated and ragdoll skeletons share one path.
	draw_set_transform_matrix(get_global_transform().affine_inverse())
	_track_swoosh(world_joints)
	_draw_swoosh(accent)
	var forward := Vector2(signf(face), 0.0)
	_draw_body(world_joints, front, back, accent, forward, Stances.is_southpaw(fighter.stance) and not _rag_on)
	_last_joints = world_joints
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_body(j: PackedVector2Array, front: Color, back: Color, accent: Color, forward: Vector2, southpaw: bool = false) -> void:
	_heel_draw = _heel
	if southpaw:
		# Right foot forward: lead limbs are on the far side, rear limbs near.
		j = j.duplicate()
		_heel_draw = Vector2(_heel.y, _heel.x)
		for pair in [[J_KNEE_F, J_KNEE_B], [J_FOOT_F, J_FOOT_B], [J_ELBOW_F, J_ELBOW_B], [J_HAND_F, J_HAND_B],
				[J_SHOULDER_F, J_SHOULDER_B], [J_HIP_F, J_HIP_B]]:
			var tmp := j[pair[0]]
			j[pair[0]] = j[pair[1]]
			j[pair[1]] = tmp
	var pivot := _pose[PIVOT] if not _rag_on else 0.0
	var back_toe := forward.rotated(PI * clampf(pivot, 0.0, 1.0) * signf(forward.x))
	var rim := fighter.outline_color
	# 1) Rim glow (dark fighters), 2) one outline around the whole body so
	# overlapping limbs merge into a single silhouette, 3) the filled body.
	if fighter.rim_glow:
		# Softer glow while at rest, full glow in action.
		var calm := fighter.state in [Fighter.State.IDLE, Fighter.State.WALK, Fighter.State.CROUCH, Fighter.State.BLOCK]
		var k := 0.5 if calm else 1.0
		var glow := rim
		glow.a = 0.16 * k
		_silhouette(j, forward, back_toe, 7.0, glow, glow)
		glow.a = 0.4 * k
		_silhouette(j, forward, back_toe, 4.0, glow, glow)
	_silhouette(j, forward, back_toe, OUTLINE_WIDTH, rim, rim)
	_silhouette(j, forward, back_toe, 0.0, back, front)
	_draw_kit(j, accent, forward)


## The body as solid shapes. `pad` grows every shape (outline / glow passes).
## Far-side limbs use `far`, everything else `near`.
func _silhouette(j: PackedVector2Array, forward: Vector2, back_toe: Vector2, pad: float, far: Color, near: Color) -> void:
	_leg(j[J_HIP_B], j[J_KNEE_B], j[J_FOOT_B], back_toe, pad, far, _heel_draw.y * _plant)
	_arm(j[J_SHOULDER_B], j[J_ELBOW_B], j[J_HAND_B], pad, far)
	_torso(j, forward, pad, near)
	_head(j, forward, pad, near)
	_leg(j[J_HIP_F], j[J_KNEE_F], j[J_FOOT_F], forward, pad, near, _heel_draw.x * _plant)
	_arm(j[J_SHOULDER_F], j[J_ELBOW_F], j[J_HAND_F], pad, near)


## Tapered segment: radius ra at a, rb at b, with rounded ends.
func _capsule(a: Vector2, b: Vector2, ra: float, rb: float, color: Color) -> void:
	var d := b - a
	if d.length_squared() < 0.01:
		draw_circle(a, maxf(ra, rb), color)
		return
	var n := Vector2(-d.y, d.x).normalized()
	draw_colored_polygon(PackedVector2Array([a + n * ra, b + n * rb, b - n * rb, a - n * ra]), color)
	draw_circle(a, ra, color, true, -1.0, true)
	draw_circle(b, rb, color, true, -1.0, true)


func _leg(hip: Vector2, knee: Vector2, ankle: Vector2, toe_dir: Vector2, pad: float, color: Color, heel_lift: float = 0.0) -> void:
	_capsule(hip, knee, 10.5 + pad, 7.5 + pad, color)   # thigh
	_capsule(knee, ankle, 7.5 + pad, 4.5 + pad, color)  # calf to ankle
	# Shoe: perpendicular to the shin, toes toward toe_dir.
	var shin := (ankle - knee).normalized()
	var toe := Vector2(-shin.y, shin.x)
	if toe.dot(toe_dir) < 0.0:
		toe = -toe
	var sole := ankle + shin * 2.5
	if heel_lift > 0.05:
		# Heel raised: tilt the shoe so the toes stay down on the floor.
		var tip := sole + Vector2(toe.x * 13.0, heel_lift)
		toe = (tip - sole).normalized()
	_capsule(sole - toe * 3.5, sole + toe * 13.0, 4.8 + pad, 3.6 + pad, color)


func _arm(shoulder: Vector2, elbow: Vector2, hand: Vector2, pad: float, color: Color) -> void:
	_capsule(shoulder, elbow, 7.5 + pad, 5.5 + pad, color)  # upper arm
	_capsule(elbow, hand, 5.5 + pad, 4.5 + pad, color)      # forearm
	draw_circle(hand, 7.0 + pad, color, true, -1.0, true)    # fist


## Side-profile torso: hips, narrower waist, chest out in front, shoulders.
func _torso(j: PackedVector2Array, forward: Vector2, pad: float, color: Color) -> void:
	var hip := j[J_HIP]
	var neck := j[J_NECK]
	var axis := neck - hip
	var length := axis.length()
	if length < 0.01:
		return
	axis /= length
	var n := Vector2(-axis.y, axis.x)
	if n.dot(forward) < 0.0:
		n = -n  # n points out of the chest
	var front_side := PackedVector2Array()
	var back_side := PackedVector2Array()
	for row in TORSO_PROFILE:
		var c := hip + axis * length * row.x
		front_side.append(c + n * (row.y + pad))
		back_side.append(c - n * (row.z + pad))
	back_side.reverse()
	draw_colored_polygon(front_side + back_side, color)
	draw_circle(hip, 10.5 + pad, color, true, -1.0, true)
	draw_circle(j[J_SHOULDER_F], 8.5 + pad, color, true, -1.0, true)  # deltoids
	draw_circle(j[J_SHOULDER_B], 8.5 + pad, color, true, -1.0, true)
	_capsule(j[J_HIP_F], j[J_HIP_B], 10.0 + pad, 10.0 + pad, color)  # pelvis
	_capsule(neck, neck + axis * 8.0, 5.0 + pad, 4.5 + pad, color)  # neck


## Head with a jaw / chin profile toward the front.
func _head(j: PackedVector2Array, forward: Vector2, pad: float, color: Color) -> void:
	var head := j[J_HEAD]
	var up := (head - j[J_NECK]).normalized()
	draw_circle(head, HEAD_R + pad, color, true, -1.0, true)
	draw_circle(head + forward * 4.5 - up * 5.5, 8.5 + pad, color, true, -1.0, true)


## Belt with a hanging knot, headband with trailing tails, wrist wraps.
func _draw_kit(j: PackedVector2Array, accent: Color, forward: Vector2) -> void:
	var hip := j[J_HIP]
	var axis := (j[J_NECK] - hip).normalized()
	var n := Vector2(-axis.y, axis.x)
	var belt := hip + axis * 6.0
	draw_line(belt - n * 11.5, belt + n * 11.5, accent, 5.5, true)
	var knot := belt - forward * 6.0
	var sway := sin(_time * 7.0) * 2.0
	draw_line(knot, knot + Vector2(-forward.x * 4.0, 12.0 + sway), accent, 3.0, true)
	var head := j[J_HEAD]
	var up := (head - j[J_NECK]).normalized()
	var band_back := head - forward * HEAD_R * 0.95 + up * 3.0
	draw_line(head + forward * HEAD_R * 0.95 + up * 4.5, band_back, accent, 4.0, true)
	var wave := sin(_time * 9.0) * 3.0
	draw_line(band_back, band_back - forward * 17.0 + Vector2(0.0, 4.0 + wave), accent, 3.0, true)
	draw_line(band_back, band_back - forward * 13.0 + Vector2(0.0, 9.0 + wave), accent, 2.5, true)
	for pair in [[J_ELBOW_F, J_HAND_F], [J_ELBOW_B, J_HAND_B]]:
		var wrist: Vector2 = j[pair[0]].lerp(j[pair[1]], 0.78)
		draw_circle(wrist, 4.8, accent.darkened(0.15), true, -1.0, true)


## States where the feet are planted on the floor (legs solved by IK).
func _wants_plant() -> bool:
	if fighter.airborne or _rag_on or _rag_blend > 0.0 or _tuck_amount > 0.0:
		return false
	if absf(_spin_angle) > 0.01 or fighter.script_flip:
		return false
	return fighter.state in [Fighter.State.IDLE, Fighter.State.WALK, Fighter.State.CROUCH, Fighter.State.BLOCK,
		Fighter.State.BLOCKSTUN, Fighter.State.GUARD_RELEASE, Fighter.State.HITSTUN, Fighter.State.LAND,
		Fighter.State.PARRY, Fighter.State.STAGGER, Fighter.State.BROKEN]


## Replaces the legs of a world-space skeleton with IK legs reaching planted
## feet. Each foot has a home spot (the pose's foot position with the weight
## shift removed); when a foot drifts too far from it, that foot steps there in
## a short arc while the other stays planted.
func _plant_feet(j: PackedVector2Array, to_world: Transform2D, forward: Vector2) -> PackedVector2Array:
	var dt := _last_delta
	_plant = move_toward(_plant, 1.0 if _wants_plant() else 0.0, dt * PLANT_RATE)
	# Body speed (for stepping ahead of the motion).
	var hip_x := j[J_HIP].x
	if dt > 0.0:
		_body_speed = lerpf(_body_speed, (hip_x - _last_hip_x) / dt, 0.3)
	_last_hip_x = hip_x
	if _plant <= 0.0:
		_feet_ready = false
		_step_leg = -1
		return j
	var floor_y := fighter.ground_y
	if not _feet_ready:
		_feet[0] = Vector2(j[J_FOOT_F].x, floor_y)
		_feet[1] = Vector2(j[J_FOOT_B].x, floor_y)
		_feet_ready = true
	# Home spots from the current pose without its weight shift.
	var home_pose := _pose.duplicate()
	home_pose[HIP_X] = 0.0
	var home := to_world * _solve_joints(home_pose)
	var homes := [Vector2(home[J_FOOT_F].x, floor_y), Vector2(home[J_FOOT_B].x, floor_y)]
	if fighter.state == Fighter.State.WALK:
		# Fighters narrow their stance on the move, so the trailing leg keeps a
		# bend through the whole stride instead of locking straight.
		homes[0].x -= WALK_NARROW_FRONT * forward.x
		homes[1].x += WALK_NARROW_REAR * forward.x
	# Advance a step in progress.
	if _step_leg >= 0:
		_step_t += dt / STEP_TIME
		if _step_t >= 1.0:
			_feet[_step_leg] = _step_to
			_step_leg = -1
	# Start a step. Footwork order: advancing, the front foot steps first and the
	# rear follows; retreating, the rear foot steps back first. Feet never cross.
	if _step_leg < 0:
		var errs := [absf(_feet[0].x - homes[0].x), absf(_feet[1].x - homes[1].x)]
		var moving_forward := _body_speed * forward.x > 30.0
		var moving_back := _body_speed * forward.x < -30.0
		var moving := moving_forward or moving_back
		var pick := -1
		if moving:
			# Strict alternation while travelling (front, rear, front, rear...),
			# starting with the front foot when advancing, the rear when retreating.
			var next_leg := (0 if moving_forward else 1) if _last_step_leg < 0 else 1 - _last_step_leg
			if errs[next_leg] > STEP_THRESHOLD * 0.4:
				pick = next_leg
		else:
			_last_step_leg = -1
			var worst := 0 if errs[0] >= errs[1] else 1
			if errs[worst] > STEP_THRESHOLD:
				pick = worst
		if pick >= 0:
			_step_leg = pick
			_last_step_leg = pick
			_step_t = 0.0
			_step_from = _feet[pick]
			# Land slightly ahead of home in the direction of travel (capped, so
			# the stance never splays wide).
			var lead := clampf(_body_speed * STEP_TIME * 1.1, -STEP_LEAD_MAX, STEP_LEAD_MAX)
			_step_to = Vector2(homes[pick].x + lead, floor_y)
	var legs := [[J_HIP_F, J_KNEE_F, J_FOOT_F], [J_HIP_B, J_KNEE_B, J_FOOT_B]]
	var targets: Array[Vector2] = []
	for leg in 2:
		var foot := _feet[leg]
		if leg == _step_leg:
			var u := smoothstep(0.0, 1.0, _step_t)
			foot = _step_from.lerp(_step_to, u) + Vector2(0.0, -STEP_HEIGHT * sin(PI * clampf(_step_t, 0.0, 1.0)))
		targets.append(foot)
	# Knees never lock: if either leg would be nearly straight, settle the hips
	# (and the whole upper body) a little lower.
	var comfy := (THIGH + SHIN) * KNEE_SOFT
	var settle := 0.0
	for leg in 2:
		var hip_p: Vector2 = j[legs[leg][0]]
		var dx := absf(targets[leg].x - hip_p.x)
		var highest := targets[leg].y - sqrt(maxf(comfy * comfy - dx * dx, 0.0))
		settle = maxf(settle, highest - hip_p.y)
	settle = minf(settle, MAX_SETTLE) * _plant
	# Active idle: the body dips over the planted feet (knees bend, the root
	# and feet stay put).
	settle += _bob * _plant
	if settle > 0.0:
		for i in JOINTS:
			if i not in [J_KNEE_F, J_FOOT_F, J_KNEE_B, J_FOOT_B]:
				j[i].y += settle
	# Heel lifts: the ankle rises a little while the toes stay on the floor
	# (the shoe tilts in _leg). Never on a stepping foot.
	for leg in 2:
		if leg != _step_leg:
			targets[leg].y -= (_heel.x if leg == 0 else _heel.y) * _plant
	for leg in 2:
		var foot := targets[leg]
		var ids: Array = legs[leg]
		var solved := _ik_leg(j[ids[0]], foot, forward)
		if leg != _step_leg:
			_feet[leg] = Vector2(solved[1].x, floor_y)  # a dragged foot stays dragged
		j[ids[1]] = j[ids[1]].lerp(solved[0], _plant)
		j[ids[2]] = j[ids[2]].lerp(solved[1], _plant)
	return j


## Two-bone leg IK: knee bends forward (toward the fighter's front). If the
## foot is out of reach it is pulled toward the hip.
static func _ik_leg(hip: Vector2, foot: Vector2, forward: Vector2) -> Array:
	var d := foot - hip
	var dist := d.length()
	var reach := THIGH + SHIN - 0.5
	if dist > reach:
		foot = hip + d / dist * reach
		d = foot - hip
		dist = reach
	if dist < 0.001:
		return [hip + Vector2(0.0, THIGH), foot]
	var half := dist * 0.5
	var bend := sqrt(maxf(THIGH * THIGH - half * half, 0.0))
	var perp := Vector2(-d.y, d.x) / dist
	if perp.dot(forward) < 0.0:
		perp = -perp
	return [hip + d * 0.5 + perp * bend, foot]


## Which joint is doing the striking right now (-1 = none).
## Developer overlay: where the striking fist / foot was last drawn (world
## space), or Vector2.INF when not attacking or not drawn yet.
func get_strike_point() -> Vector2:
	if fighter.current_attack == null or _last_joints.size() != JOINTS:
		return Vector2.INF
	return _last_joints[_attack_joint(fighter.current_attack.type)]


## Which joint leads an attack (the one that lands).
static func _attack_joint(type: CombatData.AttackType) -> int:
	match type:
		CombatData.AttackType.KICK, CombatData.AttackType.FRONT_KICK, CombatData.AttackType.JUMP_KICK, \
				CombatData.AttackType.SWEEP, CombatData.AttackType.HIGH_KICK:
			return J_FOOT_F
		CombatData.AttackType.HEAVY, CombatData.AttackType.UPPERCUT:
			return J_HAND_B
		CombatData.AttackType.BACK_KICK:
			return J_FOOT_B
	return J_HAND_F


## Pulls a strike pose back toward the stance just enough that its striking
## joint stops at the opponent's body instead of passing through it. Only when
## the limb is at the height of the opponent's body (a high kick over a crouch,
## or a strike through a dodge, still passes freely).
func _limit_reach(pose: PackedFloat32Array) -> PackedFloat32Array:
	var opp := fighter.opponent
	if opp == null or fighter.current_attack == null or opp.is_down() or opp.is_evading():
		return pose
	var gap := (opp.position.x - fighter.position.x) * fighter.facing
	if gap <= 0.0:
		return pose
	var idx := _attack_joint(fighter.current_attack.type)
	var limit := gap - BODY_HALF + CONTACT_DEPTH
	var box := opp.get_hurtbox_world()
	var top := box.position.y - fighter.position.y - 8.0
	var bottom := box.end.y - fighter.position.y + 8.0
	# Turned away (back kick): the strike reaches along local -x.
	var dir := -1.0 if cos(_spin_angle) < 0.0 else 1.0
	var j := _solve_joints(pose)[idx]
	if j.x * dir <= limit or j.y < top or j.y > bottom:
		return pose
	# Bisect the blend toward the stance: the largest extension that still fits.
	var base := _air_pose() if fighter.airborne else _guard
	var lo := 0.0  # 0 = full strike
	var hi := 1.0  # 1 = stance
	for i in REACH_SEARCH_STEPS:
		var mid := (lo + hi) * 0.5
		if _solve_joints(_blend(pose, base, mid))[idx].x * dir > limit:
			lo = mid
		else:
			hi = mid
	return _blend(pose, base, hi)


func _striking_joint() -> int:
	if fighter.state == Fighter.State.ATTACK and fighter.current_attack != null:
		var f := fighter.state_frame
		var attack := fighter.current_attack
		if f < int(attack.startup * 0.5) or f >= attack.startup + attack.active + 2:
			return -1
		return _attack_joint(attack.type)
	if fighter.state == Fighter.State.FINISHER:
		var pose_name := String(fighter.script_pose)
		if pose_name.contains("kick") or pose_name == "knee":
			return J_FOOT_F if pose_name != "knee" else J_KNEE_F
		if pose_name.contains("strike") or pose_name.begins_with("palm_") or pose_name == "grab":
			return J_HAND_B if pose_name == "heavy_strike" or pose_name == "palm_rear" else J_HAND_F
	return -1


func _track_swoosh(j: PackedVector2Array) -> void:
	var joint := _striking_joint()
	if joint < 0:
		# Strike over: fade the arc out once, then drop it.
		if _swoosh_striking:
			_swoosh_striking = false
			_swoosh_fade = SWOOSH_FADE
		elif _swoosh_fade <= 0.0:
			_swoosh.clear()
		return
	if not _swoosh_striking or joint != _swoosh_joint:
		# A new strike always starts a fresh arc.
		_swoosh.clear()
		_swoosh_striking = true
		_swoosh_joint = joint
		_swoosh_fade = 0.0
	if _swoosh.is_empty() or _swoosh[_swoosh.size() - 1].distance_to(j[joint]) > 2.0:
		_swoosh.append(j[joint])
		if _swoosh.size() > SWOOSH_POINTS:
			_swoosh.remove_at(0)


## Tapered arc behind the striking fist / foot (thin and faint at the tail).
func _draw_swoosh(accent: Color) -> void:
	if _swoosh.size() < 3:
		return
	var fade := 1.0 if _swoosh_striking else _swoosh_fade / SWOOSH_FADE
	if fade <= 0.0:
		return
	var n := _swoosh.size()
	for i in range(1, n):
		var k := float(i) / float(n - 1)
		var c := Color(1.0, 1.0, 1.0).lerp(accent, 0.35)
		c.a = 0.75 * k * fade
		draw_line(_swoosh[i - 1], _swoosh[i], c, 2.0 + 9.0 * k, true)


const _BONES: Array[Vector2i] = [
	Vector2i(J_HIP_F, J_KNEE_F), Vector2i(J_KNEE_F, J_FOOT_F), Vector2i(J_HIP_B, J_KNEE_B),
	Vector2i(J_KNEE_B, J_FOOT_B), Vector2i(J_HIP, J_NECK), Vector2i(J_SHOULDER_F, J_ELBOW_F),
	Vector2i(J_ELBOW_F, J_HAND_F), Vector2i(J_SHOULDER_B, J_ELBOW_B), Vector2i(J_ELBOW_B, J_HAND_B),
]


func _draw_trail(color: Color) -> void:
	if _trail.is_empty():
		return
	draw_set_transform_matrix(get_global_transform().affine_inverse())
	for snap in _trail:
		var pts: PackedVector2Array = snap["pts"]
		var c := color
		c.a = 0.35 * (1.0 - snap["age"] / TRAIL_LIFE)
		for bone in _BONES:
			draw_line(pts[bone.x], pts[bone.y], c, LIMB_WIDTH + 4.0, true)
		draw_circle(pts[J_HEAD], HEAD_R, c)
