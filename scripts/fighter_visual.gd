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
const ROLL_RADIUS: float = CombatData.BALL_RADIUS
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
## Body width kept when turned edge-on in a spin (fraction of facing width).
const SPIN_MIN_WIDTH: float = 0.4
## Boxer skin tones (light fighter, dark fighter) and outfit colours.
const SKIN_LIGHT := Color(0.87, 0.68, 0.54)
const SKIN_DARK := Color(0.42, 0.27, 0.2)
const SHADE_DARKEN: float = 0.22
const HIGHLIGHT_ALPHA: float = 0.35
const BOOT_COLOR := Color(0.94, 0.93, 0.9)
const SOLE_COLOR := Color(0.16, 0.13, 0.12)
## Boxing gloves are drawn this much bigger than a bare fist.
const GLOVE_SCALE: float = 1.35
## Straight punch aim limits (limb angle from straight down; pi/2 = level).
const AIM_MIN: float = 1.15
const AIM_MAX: float = 2.3
## Most a bent arm (hook / uppercut) is swung to reach its target (rad).
const AIM_BENT_MAX: float = 1.3
## Close-range punches: how far the hips sit back and the torso straightens
## before the elbow has to bend.
const PUNCH_ROOM_HIP: float = 10.0
const PUNCH_ROOM_LEAN: float = 0.12
## Close-range kicks: how far the hips shift back and the torso leans away to
## keep the leg extended before the knee has to fold.
const KICK_ROOM_HIP: float = 18.0
const KICK_ROOM_LEAN: float = 0.18
## Active idle (the looping fighting movement in neutral, per stance: see
## Stances.DATA "idle"). It fades in over 1 / IDLE_FADE_IN s after any action
## (so recoveries look settled, not bouncy), out fast when acting, and is damped
## by up to IDLE_POSTURE_DAMP as posture fills. Purely visual: the gameplay root
## never moves; the hips dip over planted feet and heels lift with toes down.
const IDLE_FADE_IN: float = 2.2
const IDLE_FADE_OUT: float = 14.0
const IDLE_POSTURE_DAMP: float = 0.7
const MAX_IDLE_BOB: float = 6.0
## Duration of an idle lead-hand feint (s).
const FEINT_TIME: float = 0.22
const MAX_HEEL_LIFT: float = 5.0
## Strike mechanics (see _mechanics): load depth against the strike, where the
## load peaks (fraction of startup), and how much of the recovery the release takes.
const MECH_LOAD: float = 0.35
const MECH_LOAD_END: float = 0.55
const MECH_RELEASE: float = 0.55
enum { MECH_NONE, MECH_LEAD, MECH_REAR, MECH_RISING, MECH_KICK, MECH_ROUNDHOUSE, MECH_KNEE, MECH_HOOK_LEAD, MECH_HOOK_REAR }
## Per kind: channel -> offset at full drive.
const MECH_GAINS: Dictionary = {
	MECH_LEAD: {HIP_X: 8.0, TORSO: 0.14, SPREAD: 9.0, HEAD: 0.1},
	MECH_REAR: {HIP_X: 12.0, TORSO: 0.12, SPREAD: -18.0, PIVOT: 0.9, DROP: 5.0, HEAD: 0.12},
	MECH_RISING: {HIP_X: 5.0, TORSO: 0.0, SPREAD: -6.0, PIVOT: 0.5},
	MECH_KICK: {HIP_X: 3.0, TORSO: -0.1, PIVOT: 0.8, TH_B: 0.3, SH_B: -0.25},
	MECH_ROUNDHOUSE: {HIP_X: 3.0, TORSO: -0.05, PIVOT: 0.9, TH_B: 0.3, SH_B: -0.25, UA_B: -0.5, LA_B: -0.6},
	MECH_KNEE: {HIP_X: 6.0, TORSO: -0.1, PIVOT: 0.5},
	# Hooks turn the shoulders in (closing) rather than reaching out.
	MECH_HOOK_LEAD: {HIP_X: 5.0, TORSO: 0.05, SPREAD: -10.0, HEAD: 0.08},
	MECH_HOOK_REAR: {HIP_X: 9.0, TORSO: 0.08, SPREAD: -16.0, PIVOT: 0.9, DROP: 3.0, HEAD: 0.1},
}
const MECH_FORWARD_ONLY: Array = [PIVOT, DROP, TH_B, SH_B, UA_B, LA_B]
## Limb muscle profiles: (t along the bone 0..1, half-width) on the front
## (kneecap / shin / inner-arm) side and the back (hamstring / calf / triceps)
## side, so limbs read as legs and arms instead of tubes.
const THIGH_FRONT: Array[Vector2] = [Vector2(0.0, 10.5), Vector2(0.3, 11.5), Vector2(0.7, 8.6), Vector2(1.0, 6.8)]
const THIGH_BACK: Array[Vector2] = [Vector2(0.0, 10.5), Vector2(0.45, 9.8), Vector2(1.0, 6.4)]
const SHIN_FRONT: Array[Vector2] = [Vector2(0.0, 6.4), Vector2(0.5, 5.0), Vector2(1.0, 3.9)]
const SHIN_BACK: Array[Vector2] = [Vector2(0.0, 6.4), Vector2(0.28, 8.6), Vector2(0.62, 5.8), Vector2(1.0, 3.6)]
const UPPER_ARM_FRONT: Array[Vector2] = [Vector2(0.0, 7.5), Vector2(0.45, 7.6), Vector2(1.0, 5.2)]
const UPPER_ARM_BACK: Array[Vector2] = [Vector2(0.0, 7.5), Vector2(0.4, 6.8), Vector2(1.0, 5.2)]
const FOREARM_FRONT: Array[Vector2] = [Vector2(0.0, 5.2), Vector2(0.3, 6.2), Vector2(1.0, 3.8)]
const FOREARM_BACK: Array[Vector2] = [Vector2(0.0, 5.2), Vector2(0.3, 5.6), Vector2(1.0, 3.8)]
const MUSCLE_SAMPLES: int = 8
## A foot this far off the floor is a lifted (kicking / jumping) foot.
const FOOT_LIFTED: float = 22.0
## Toe point (0 = foot square to the shin, heel / blade leading; 1 = toes
## pointed along the shin) for a lifted foot, by technique.
const POINT_ROUNDHOUSE: float = 0.8
const POINT_BALL: float = 0.3
const POINT_RELAXED: float = 0.45
const FOOT_POINT_RATE: float = 18.0
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
var _heavy_strike := PackedFloat32Array([0.32, 0.05, 0.75, 2.8, 1.57, 1.6, 0.6, 0.0, -0.5, -0.78, 12.0, 0.0, 0.8])
var _backhand_windup := PackedFloat32Array([0.1, 0.15, 1.3, 4.08, 0.55, 2.95, 0.6, -0.05, -0.62, -0.3, -3.0, 0.0])
var _backhand_strike := PackedFloat32Array([0.25, 0.05, 1.8, 2.05, 0.55, 2.95, 0.68, 0.05, -0.66, -0.32, 6.0, 0.0])
var _uppercut_windup := PackedFloat32Array([0.45, 0.15, 0.9, 2.6, 0.15, 0.9, 1.0, -0.4, -0.75, -1.1, -4.0, 0.0])
var _uppercut_strike := PackedFloat32Array([0.12, -0.05, 0.7, 2.8, 1.65, 3.0, 0.75, -0.2, -0.5, -0.55, 8.0, 4.0, 0.7])

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
var _high_extend := PackedFloat32Array([-0.6, 0.55, 1.3, 1.9, 0.6, 2.9, 2.38, 2.45, -0.25, -0.1, 10.0, 0.0, 1.0])
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
# --- Boxing ---------------------------------------------------------------------
# Hooks: the elbow comes up to shoulder height and the fist travels across on a
# short arc; the shoulders turn through (spread swings from loaded to closed).
var _lhook_load := PackedFloat32Array([0.15, 0.15, 0.8, 2.9, 0.85, 3.0, 0.55, -0.15, -0.5, -0.45, -3.0, 0.0, 0.0, 15.0])
# Hooks: elbow up at shoulder height, arm bent about 90 degrees, the
# shoulders turning in through the punch (not a straight).
var _lhook_hit := PackedFloat32Array([0.3, 0.1, 1.62, 2.5, 0.85, 3.0, 0.6, -0.1, -0.55, -0.5, 6.0, 0.0, 0.3, -12.0])
var _rhook_load := PackedFloat32Array([0.15, 0.15, 0.95, 2.95, 0.6, 2.9, 0.55, -0.15, -0.5, -0.45, -4.0, 0.0, 0.0, 16.0])
var _rhook_hit := PackedFloat32Array([0.35, 0.05, 0.9, 2.9, 1.62, 2.5, 0.7, 0.1, -0.6, -0.65, 10.0, 0.0, 0.8, -18.0])
# Body hook: dip at the knees and dig the lead fist in at rib height.
# Rear-hand body hook (finishers): the other arm digging into the ribs.
var _rbody_load := PackedFloat32Array([0.45, 0.3, 0.95, 2.95, 0.6, 2.6, 0.95, -0.65, -0.4, -1.0, -4.0, 0.0, 0.0, 14.0])
var _rbody_hit := PackedFloat32Array([0.6, 0.35, 0.95, 2.95, 1.3, 1.6, 1.0, -0.7, -0.45, -1.05, 10.0, 0.0, 0.8, -14.0])
# Deep uppercut load: sat down low on bent knees, rear glove dropped.
var _upper_load_deep := PackedFloat32Array([0.5, 0.2, 0.9, 2.75, 0.1, 0.8, 1.3, -0.75, -0.55, -1.45, -6.0, 0.0, 0.3, 6.0])
var _bhook_load := PackedFloat32Array([0.4, 0.3, 0.6, 2.4, 0.85, 3.0, 0.9, -0.6, -0.4, -1.0, -4.0, 0.0, 0.0, 12.0])
var _bhook_hit := PackedFloat32Array([0.55, 0.35, 1.25, 1.55, 0.85, 3.0, 1.0, -0.7, -0.45, -1.05, 8.0, 0.0, 0.2, -4.0])
# Overhand: rear fist cocked high and back, then looping over the top and down.
var _overhand_load := PackedFloat32Array([-0.05, 0.15, 0.95, 2.95, 3.3, 3.9, 0.5, -0.1, -0.5, -0.4, -6.0, 0.0, 0.0, 14.0])
var _overhand_hit := PackedFloat32Array([0.6, 0.1, 0.8, 2.6, 1.9, 1.35, 0.9, 0.3, -0.8, -0.7, 14.0, 0.0, 0.5, -10.0])
# Slip counter: the head slips down and off the line, then a straight rear hand.
var _slip_dip := PackedFloat32Array([0.5, 0.45, 1.0, 3.0, 0.85, 3.0, 0.9, -0.6, -0.45, -0.9, -6.0, 0.0, 0.0, 4.0])
var _slip_hit := PackedFloat32Array([0.35, 0.1, 0.75, 2.8, 1.57, 1.6, 0.8, 0.2, -0.75, -0.6, 14.0, 0.0, 0.5, -8.0])
# Bob and weave: sink at the knees with the chin tucked behind the gloves, the
# head rolling down and under the line (the bottom of the U), then back up.
var _weave_in := PackedFloat32Array([0.55, 0.45, 1.05, 3.05, 0.8, 3.1, 1.05, -0.55, -0.45, -1.15, -6.0, 0.0, 0.0, 8.0])
var _weave_low := PackedFloat32Array([0.8, 0.5, 1.1, 3.1, 0.85, 3.1, 1.15, -0.65, -0.45, -1.15, 2.0, 0.0, 0.2, 2.0])
var _weave_out := PackedFloat32Array([0.45, 0.35, 1.0, 3.0, 0.75, 3.05, 1.0, -0.45, -0.4, -1.0, 8.0, 0.0, 0.3, 6.0])
# Lead-leg feint: the lead knee snaps up into a kick chamber, then sets down.
var _feint_lift := PackedFloat32Array([-0.15, 0.2, 1.1, 2.4, 0.55, 2.95, 1.45, -0.95, -0.25, -0.15, -2.0, 0.0, 0.4])
var _feint_top := PackedFloat32Array([-0.25, 0.25, 1.15, 2.3, 0.55, 2.95, 1.8, -1.05, -0.25, -0.15, -3.0, 0.0, 0.6])
# Rising elbow: sink with the rear elbow low, then drive it up through the chin
# (forearm folded to the ear) as the legs extend.
var _relbow_load := PackedFloat32Array([0.35, 0.2, 0.95, 2.95, 0.3, 2.9, 0.95, -0.5, -0.5, -0.95, -4.0, 0.0, 0.0, 14.0])
var _relbow_hit := PackedFloat32Array([0.25, -0.05, 0.95, 2.95, 2.2, 4.65, 0.7, -0.2, -0.5, -0.55, 8.0, 0.0, 0.8, -12.0])
# Body straight: drop the level on bent knees, then the rear hand straight to the stomach.
var _bstraight_load := PackedFloat32Array([0.45, 0.25, 0.95, 2.95, 0.4, 2.7, 1.05, -0.55, -0.45, -1.0, -4.0, 0.0, 0.0, 12.0])
var _bstraight_hit := PackedFloat32Array([0.55, 0.3, 0.95, 2.95, 1.35, 1.35, 1.05, -0.45, -0.55, -0.95, 14.0, 0.0, 0.8, -14.0])
# Body punch (chudan gyaku-zuki): deep front stance, the rear fist chambered at
# the hip, then driven straight into the solar plexus with the torso upright.
var _chudan_load := PackedFloat32Array([0.1, 0.15, 1.2, 2.0, 0.3, 2.4, 1.1, -0.45, -0.85, -0.55, -8.0, 0.0, 0.0, 16.0])
var _chudan_hit := PackedFloat32Array([0.2, 0.05, 0.6, 2.4, 1.42, 1.42, 1.2, -0.5, -0.95, -0.6, 18.0, 0.0, 0.9, -10.0])
# Low palm: sink into a horse stance (rear palm chambered at the hip), then the
# lead palm drives low into the belly.
var _lpalm_load := PackedFloat32Array([0.25, 0.2, 1.0, 2.6, 0.2, 1.9, 1.25, -0.75, -0.75, -1.05, -6.0, 0.0, 0.0, 10.0])
var _lpalm_hit := PackedFloat32Array([0.45, 0.2, 1.3, 1.25, 0.3, 2.2, 1.2, -0.6, -0.8, -1.0, 10.0, 0.0, 0.3, 6.0])
# --- Power chords (Space + J / K) -------------------------------------------------
# Channels: torso, head, ua_f, la_f, ua_b, la_b, th_f, sh_f, th_b, sh_b, hip_x, drop, pivot, spread.
# Crouching power uppercut: sit right down, rear glove dropped below the hip,
# then the legs, hips and shoulder drive up through the fist onto the toes.
var _pupper_coil := PackedFloat32Array([0.5, 0.25, 0.95, 2.95, 0.05, 0.6, 0.95, -0.45, -0.35, -0.8, -6.0, 0.0, 0.4, 10.0])
var _pupper_hit := PackedFloat32Array([-0.12, -0.2, 0.95, 2.9, 2.35, 3.35, 0.45, -0.05, -0.4, -0.3, 10.0, 0.0, 0.9, -16.0])
# Superman punch: the rear knee lifts as if to kick (weight on the lead leg),
# then the leg snaps back as the body flies behind a straight rear hand.
var _sm_load := PackedFloat32Array([0.0, 0.15, 1.0, 2.8, 0.6, 2.9, 0.75, -0.3, 1.0, -1.4, -4.0, 0.0, 0.0, 10.0])
var _sm_hit := PackedFloat32Array([0.55, 0.05, 0.35, 2.1, 1.6, 1.58, 1.0, -0.7, -0.95, -0.9, 8.0, 0.0, 0.9, -14.0])
var _sm_land := PackedFloat32Array([0.3, 0.1, 0.9, 2.8, 1.2, 2.2, 0.8, -0.4, -0.5, -0.8, 4.0, 0.0, 0.4, -6.0])
# Jumping downward elbow: knees up and the rear elbow raised high behind the
# head, then the whole body folds forward to chop the elbow point down.
var _jelbow_load := PackedFloat32Array([-0.15, -0.1, 1.6, 3.4, 3.0, 4.7, 1.7, -0.7, 0.9, -1.3, -2.0, 0.0, 0.0, 12.0])
var _jelbow_hit := PackedFloat32Array([0.65, 0.25, 1.4, 2.9, 1.45, 4.3, 1.6, -0.3, -0.2, -0.9, 8.0, 0.0, 0.6, -10.0])
var _jelbow_recoil := PackedFloat32Array([0.35, 0.15, 1.1, 2.9, 1.0, 3.6, 1.3, -0.6, -0.3, -1.0, 0.0, 0.0, 0.3, 0.0])
# Flying knee to the face: both hands reach for the head as the rear knee
# chambers, then the hands pull down while the rear knee drives up.
var _kface_load := PackedFloat32Array([0.05, 0.05, 2.1, 2.2, 2.0, 2.1, 0.4, -0.5, 0.7, -1.4, 0.0, 0.0, 0.0, 6.0])
var _kface_hit := PackedFloat32Array([0.15, 0.15, 1.6, 1.0, 1.5, 0.95, -0.4, -0.7, 2.2, -0.6, 8.0, 0.0, 0.6, -8.0])
# Jumping reverse punch: knees tucked, rear fist chambered at the hip and the
# lead hand reaching; then the rear fist fires as the lead pulls back (hikite).
var _jrp_load := PackedFloat32Array([0.1, 0.1, 1.4, 1.5, 0.3, 2.4, 1.6, -0.9, 1.0, -1.4, -4.0, 0.0, 0.0, 14.0])
var _jrp_hit := PackedFloat32Array([0.35, 0.05, 0.3, 2.4, 1.57, 1.57, 1.45, -0.4, -0.5, -0.9, 10.0, 0.0, 0.9, -12.0])
var _jrp_recoil := PackedFloat32Array([0.2, 0.1, 1.0, 2.3, 0.6, 2.5, 1.0, -0.5, -0.4, -0.9, 2.0, 0.0, 0.3, 4.0])
# Flying side kick: lead knee drawn tight to the chest, rear leg tucked, then
# the lead heel spears out level with the body laid back behind it.
var _fsk_chamber := PackedFloat32Array([-0.25, 0.25, 1.3, 2.3, 0.4, 2.6, 2.3, -0.9, 1.3, -1.5, -2.0, 0.0, 0.8])
var _fsk_extend := PackedFloat32Array([-0.7, 0.5, 1.4, 1.8, -0.4, 0.2, 1.78, 1.8, 1.0, -1.6, 8.0, 0.0, 1.0])
# Leaping palm: a low bound with the lead palm drawn back by the ear, then
# thrust to the chest with the rear palm guarding.
var _leap_palm_load := PackedFloat32Array([0.15, 0.15, 0.6, 3.5, 1.0, 2.6, 1.5, -0.8, 0.6, -1.3, -4.0, 0.0, 0.0, 10.0])
var _leap_palm_hit := PackedFloat32Array([0.5, 0.15, 1.15, 1.15, 1.0, 2.6, 1.3, -0.4, -0.4, -0.9, 10.0, 0.0, 0.4, -4.0])
# Flying double palm: both palms drawn back to the hips with the knees up,
# then driven out together into the chest.
var _fdp_load := PackedFloat32Array([-0.1, 0.05, -0.3, 1.2, -0.4, 1.1, 1.7, -0.8, 1.1, -1.4, -6.0, 0.0, 0.0, 10.0])
var _fdp_hit := PackedFloat32Array([0.5, 0.05, 1.2, 1.25, 1.15, 1.2, 1.2, -0.5, 0.6, -1.0, 14.0, 0.0, 0.3, 10.0])
# Jumping backfist: the lead fist folds across the chest on the way up and
# whips out to the temple, lead knee chambered.
var _jbf_load := PackedFloat32Array([0.0, 0.15, 1.3, 4.08, 0.6, 2.9, 1.8, -0.9, 0.5, -1.3, -3.0, 0.0, 0.3])
var _jbf_hit := PackedFloat32Array([0.3, 0.05, 1.55, 1.7, 0.6, 2.9, 1.6, -0.6, -0.4, -0.9, 8.0, 0.0, 0.6])
# Jumping spinning hook kick: turn the back in the air with the lead leg
# tucked, the rear heel whipping across at head height.
var _jshk_load := PackedFloat32Array([0.4, 0.35, 1.0, 2.8, 0.9, 2.9, 1.7, -0.9, 0.9, -1.6, 0.0, 0.0, 0.0, 6.0])
var _jshk_hit := PackedFloat32Array([0.75, 0.5, 1.2, 2.6, 0.6, 2.4, 1.5, -1.2, -2.05, -1.9, -6.0, 0.0, 0.0, 4.0])
# Jumping roundhouse: both knees tucked high, then the lead shin whips round
# at head height with the body leaning away and the rear arm swinging down.
var _lrh_load := PackedFloat32Array([0.1, 0.15, 1.0, 2.8, 0.4, 2.7, 1.9, -1.2, 1.3, -1.5, -2.0, 0.0, 0.6, 8.0])
var _lrh_hit := PackedFloat32Array([-0.5, 0.45, 1.2, 2.2, -0.5, 0.4, 2.0, 2.0, 0.9, -1.4, 8.0, 0.0, 1.0, -6.0])
# Leaping spinning backfist: dip with the rear shoulder turning down (coil),
# knees tucked as the body turns its back in the air, then the rear fist whips
# round at head height (the body is still turned, so the rear arm leads).
var _lsb_coil := PackedFloat32Array([0.4, 0.25, 1.0, 2.8, 0.5, 3.1, 1.1, -0.6, -0.45, -1.1, -4.0, 0.0, 0.0, 16.0])
var _lsb_turn := PackedFloat32Array([0.15, 0.2, 1.2, 3.0, 0.9, 3.3, 1.7, -0.9, 0.9, -1.4, 0.0, 0.0, 0.0, 6.0])
var _lsb_hit := PackedFloat32Array([-0.25, -0.1, 1.2, 3.0, -1.45, -1.65, 1.5, -0.7, 0.3, -1.2, -4.0, 0.0, 0.0, 4.0])
var _lsb_land := PackedFloat32Array([0.3, 0.2, 1.0, 2.8, 0.6, 2.9, 1.0, -0.5, -0.4, -1.0, 0.0, 0.0, 0.0, 6.0])
# Flying axe kick: step in and rise, chamber the kicking knee high with the
# torso tall, the leg straight up at the apex, then the heel chops down.
var _fax_chamber := PackedFloat32Array([-0.15, 0.2, 1.2, 2.6, 0.5, 2.8, 2.3, -1.1, 0.9, -1.4, -2.0, 0.0, 0.5])
var _fax_apex := PackedFloat32Array([-0.5, 0.4, 1.5, 2.2, 0.0, 2.4, 2.65, 2.7, 0.6, -1.2, 0.0, 0.0, 0.7])
var _fax_chop := PackedFloat32Array([0.25, 0.15, 1.1, 2.6, 0.6, 2.8, 1.85, 1.7, 0.2, -1.3, 8.0, 0.0, 0.8])
var _fax_follow := PackedFloat32Array([0.4, 0.2, 1.0, 2.7, 0.6, 2.8, 1.45, 1.1, 0.1, -1.3, 10.0, 0.0, 0.8])
var _fax_land := PackedFloat32Array([0.35, 0.2, 1.0, 2.8, 0.6, 2.9, 1.1, -0.6, -0.45, -1.1, 2.0, 0.0, 0.3])
# Dizzy: guard dropped, knees soft, head lolling (wobbled in _dizzy_pose).
var _dizzy := PackedFloat32Array([0.28, 0.5, 0.45, 1.1, 0.35, 0.9, 0.75, -0.35, -0.45, -0.75, -3.0, 0.0, 0.0, 2.0])
# --- Victory routines (by style; see _victory_pose) ------------------------------
# Boxing: both gloves thrust overhead, a glove tap, then gloves up again.
var _win_box_raise := PackedFloat32Array([-0.08, -0.3, 2.7, 2.95, 3.55, 3.45, 0.3, 0.0, -0.25, -0.35, 0.0, 0.0, 0.0, 4.0])
var _win_box_tap := PackedFloat32Array([0.1, 0.1, 1.45, 2.3, 1.4, 2.3, 0.3, 0.0, -0.25, -0.35, 0.0, 0.0, 0.0, 4.0])
# Muay Thai: the wai, palms pressed together at the chest, head bowed.
var _win_wai := PackedFloat32Array([0.45, 0.6, 0.55, 2.95, 0.6, 2.9, 0.18, 0.0, -0.18, -0.24, 0.0, 0.0, 0.0, 2.0])
var _win_wai_up := PackedFloat32Array([0.04, 0.12, 0.55, 2.95, 0.6, 2.9, 0.18, 0.0, -0.18, -0.24, 0.0, 0.0, 0.0, 2.0])
# Karate: ready stance (fists before the belt), the rei bow, back to ready.
var _win_rei_ready := PackedFloat32Array([0.0, 0.05, 0.3, 0.75, 0.3, 0.75, 0.14, 0.0, -0.14, -0.16, 0.0, 0.0, 0.0, 1.0])
var _win_rei_bow := PackedFloat32Array([0.55, 0.35, 0.12, 0.12, 0.12, 0.12, 0.14, 0.0, -0.14, -0.16, -4.0, 0.0, 0.0, 1.0])
# Kung Fu: fist-and-palm salute in front of the chest, with a small bow.
var _win_kf_salute := PackedFloat32Array([0.04, 0.1, 1.55, 2.15, 1.6, 2.05, 0.15, 0.0, -0.15, -0.15, 0.0, 0.0, 0.0, 2.0])
var _win_kf_bow := PackedFloat32Array([0.35, 0.35, 1.45, 2.1, 1.5, 2.0, 0.15, 0.0, -0.15, -0.15, -2.0, 0.0, 0.0, 2.0])
# Taekwondo: the ready stance (chunbi, fists before the belt), the bow
# (kyungye) with the fists held, then the fighting guard raised high.
var _win_tkd_ready := PackedFloat32Array([0.0, 0.05, 0.4, 1.1, 0.4, 1.1, 0.12, 0.0, -0.12, -0.12, 0.0, 0.0, 0.0, 1.0])
var _win_tkd_bow := PackedFloat32Array([0.5, 0.35, 0.3, 0.9, 0.3, 0.9, 0.12, 0.0, -0.12, -0.12, -4.0, 0.0, 0.0, 1.0])
var _win_tkd_fists := PackedFloat32Array([-0.05, -0.15, 2.0, 3.3, 1.9, 3.2, 0.12, 0.0, -0.12, -0.12, 0.0, 0.0, 0.0, 1.0])
# Kickboxing: fist pumps, then both fists up.
var _win_kb_pump := PackedFloat32Array([0.08, -0.2, 2.95, 3.05, 1.0, 2.5, 0.3, -0.05, -0.3, -0.4, 0.0, 0.0, 0.0, 4.0])
var _win_kb_chest := PackedFloat32Array([0.15, 0.05, 1.3, 2.6, 1.0, 2.5, 0.3, -0.05, -0.3, -0.4, 0.0, 0.0, 0.0, 4.0])
var _win_kb_both := PackedFloat32Array([-0.1, -0.3, 2.75, 2.95, 3.55, 3.45, 0.3, -0.05, -0.3, -0.4, 0.0, 0.0, 0.0, 4.0])
## Victory routines: style id -> [[tick, pose], ...]; poses are blended
## between keys and the last one is held with a breathing sway.
var _victory: Dictionary = {}
var _victory_seen: StringName = &""
var _victory_t0: float = 0.0
# --- Bangla Maar ---------------------------------------------------------------
# Light slap: the lead hand drawn back low and wide, then swung across the cheek.
var _slap_wind := PackedFloat32Array([0.0, 0.1, 0.2, -0.3, 0.2, 0.4, 0.3, 0.0, -0.25, -0.3, -4.0, 0.0, 0.0, 10.0])
var _slap_hit := PackedFloat32Array([0.25, -0.05, 1.75, 1.95, 0.2, 0.45, 0.32, 0.0, -0.3, -0.35, 8.0, 0.0, 0.3, -6.0])
var _slap_follow := PackedFloat32Array([0.3, -0.1, 2.0, 2.6, 0.2, 0.45, 0.32, 0.0, -0.3, -0.35, 9.0, 0.0, 0.35, -8.0])
# Front thrust kick: arms flung up for balance, a flat-footed shove of a kick.
var _thrust_chamber := PackedFloat32Array([-0.3, 0.2, 1.6, 2.3, 1.3, 2.0, 1.9, 0.2, -0.3, -0.25, -2.0, 6.0, 0.2, 4.0])
var _thrust_extend := PackedFloat32Array([-0.5, 0.3, 1.9, 2.5, 1.5, 2.2, 1.55, 1.55, -0.45, -0.15, 12.0, 4.0, 0.35, 4.0])
# Double-hand push: both hands pulled to the chest, then a full-body shove.
var _push_load := PackedFloat32Array([-0.05, 0.05, 0.85, 2.7, 0.8, 2.7, 0.35, -0.05, -0.35, -0.4, -6.0, 0.0, 0.0, 6.0])
var _push_hit := PackedFloat32Array([0.38, 0.1, 1.5, 1.5, 1.45, 1.45, 0.6, -0.1, -0.6, -0.5, 14.0, 0.0, 0.4, 2.0])
# Head elbow: the rear elbow cocked high, swung round into the head.
var _helbow_load := PackedFloat32Array([0.0, 0.1, 0.6, 0.9, 2.4, 4.4, 0.3, 0.0, -0.3, -0.35, -4.0, 0.0, 0.0, 14.0])
var _helbow_hit := PackedFloat32Array([0.4, 0.05, 0.6, 0.9, 1.8, 4.45, 0.45, -0.05, -0.5, -0.5, 12.0, 0.0, 0.7, -10.0])
# Double-hand hammer: both fists clasped high (a long, comic wind-up), then
# brought straight down.
var _hammer_raise := PackedFloat32Array([-0.35, -0.25, 3.3, 3.45, 3.25, 3.4, 0.35, 0.0, -0.3, -0.35, -6.0, 0.0, 0.0, 4.0])
var _hammer_hit := PackedFloat32Array([0.55, 0.2, 1.35, 1.25, 1.3, 1.2, 0.7, -0.2, -0.55, -0.6, 12.0, 0.0, 0.3, 2.0])
# Stomach shot: dip, rear fist at the hip, then dug into the belly.
var _stomach_load := PackedFloat32Array([0.3, 0.15, 0.7, 1.2, 0.25, 2.3, 0.9, -0.4, -0.45, -0.85, -4.0, 0.0, 0.0, 12.0])
var _stomach_hit := PackedFloat32Array([0.5, 0.25, 0.7, 1.2, 1.3, 1.3, 1.0, -0.45, -0.55, -0.95, 12.0, 0.0, 0.7, -10.0])
# Leg kick: a toe-poke at the shin, lead leg swung forward low.
var _lkick_load := PackedFloat32Array([-0.1, 0.1, 0.5, 0.8, 0.3, 0.6, 0.5, -0.6, -0.3, -0.3, -2.0, 0.0, 0.0, 4.0])
var _lkick_hit := PackedFloat32Array([-0.25, 0.15, 0.7, 1.0, 0.2, 0.5, 0.85, 1.0, -0.35, -0.25, 8.0, 0.0, 0.3, 4.0])
# Flying slap: hop with the slapping hand raised high, swung down across the face.
var _fslap_load := PackedFloat32Array([0.0, 0.05, 2.9, 3.4, 0.5, 2.6, 1.6, -0.8, 0.8, -1.3, -4.0, 0.0, 0.0, 12.0])
var _fslap_hit := PackedFloat32Array([0.35, -0.05, 1.55, 1.5, 0.5, 2.6, 1.3, -0.4, -0.4, -0.9, 8.0, 0.0, 0.3, -4.0])
# Flying chest kick: knees tucked, then one leg flat into the chest with the
# body leaning back and both arms thrown up.
var _fck_load := PackedFloat32Array([0.0, 0.1, 1.5, 2.5, 1.3, 2.4, 2.0, -1.0, 1.2, -1.4, -2.0, 0.0, 0.3])
var _fck_hit := PackedFloat32Array([-0.55, 0.4, 2.2, 2.6, 2.0, 2.4, 1.6, 1.55, 0.9, -1.3, 8.0, 0.0, 0.6])
# Belly Bomb: step back leaning away, crouch, then fly belly-first with the
# back arched and arms flung behind; bounce and land.
var _bb_back := PackedFloat32Array([-0.2, -0.1, 0.6, 1.0, 0.4, 0.8, 0.5, -0.2, -0.4, -0.5, -8.0, 0.0, 0.0, 4.0])
var _bb_crouch := PackedFloat32Array([0.45, 0.2, 0.3, 0.6, 0.2, 0.5, 1.2, -0.8, -0.6, -1.4, -4.0, 0.0, 0.0, 4.0])
var _bb_fly := PackedFloat32Array([-0.75, -0.3, -0.7, -0.4, -0.8, -0.5, 0.9, -0.4, -0.9, -0.5, 16.0, 0.0, 0.0, 4.0])
var _bb_land := PackedFloat32Array([0.2, 0.1, 0.8, 1.6, 0.6, 1.4, 1.1, -0.6, -0.4, -1.1, 0.0, 0.0, 0.0, 4.0])
# Finishers: a punt at a sitting opponent's head, the enormous Super Chor slap
# and shaking the stinging hand afterwards.
# Football punt at a head on the floor: the kicking leg swung far back with the
# arms out for balance, through low along the floor, then a high follow-through.
var _punt_load := PackedFloat32Array([0.05, 0.25, 1.4, 1.6, -0.6, -0.3, -0.75, -1.7, 0.1, -0.1, -6.0, 0.0, 0.0, 6.0])
var _punt_hit := PackedFloat32Array([-0.35, 0.45, 1.6, 2.0, -0.9, -0.6, 0.45, 1.35, 0.5, -0.4, 6.0, 0.0, 0.3, 4.0])
var _punt_follow := PackedFloat32Array([-0.55, 0.2, 2.2, 2.6, -1.0, -0.6, 2.0, 2.1, 0.3, -0.3, 10.0, 0.0, 0.6, 4.0])
var _mega_slap_wind := PackedFloat32Array([-0.4, -0.2, 3.8, 4.1, 0.6, 1.0, 0.35, 0.0, -0.35, -0.35, -10.0, 0.0, 0.0, 18.0])
var _mega_slap_hit := PackedFloat32Array([0.45, 0.0, 1.8, 1.85, 0.3, 0.5, 0.6, -0.1, -0.6, -0.5, 14.0, 0.0, 0.8, -12.0])
var _mega_slap_follow := PackedFloat32Array([0.6, 0.1, 1.85, 2.05, 0.2, 0.4, 0.65, -0.1, -0.65, -0.5, 16.0, 0.0, 1.0, -16.0])
var _hand_shake_a := PackedFloat32Array([0.1, 0.15, 1.1, 1.0, 0.2, 0.4, 0.3, 0.0, -0.25, -0.3, 0.0, 0.0, 0.0, 3.0])
var _hand_shake_b := PackedFloat32Array([0.1, 0.05, 1.0, 1.55, 0.2, 0.4, 0.3, 0.0, -0.25, -0.3, 0.0, 0.0, 0.0, 3.0])
# Victory: hands on the waist, chest out.
var _win_para := PackedFloat32Array([-0.15, -0.2, -0.55, 0.95, -0.55, 0.95, 0.25, 0.0, -0.2, -0.25, 0.0, 0.0, 0.0, 3.0])
var _win_para_point := PackedFloat32Array([-0.1, -0.1, 1.5, 1.6, -0.55, 0.95, 0.25, 0.0, -0.2, -0.25, 0.0, 0.0, 0.0, 3.0])
# --- Signatures -------------------------------------------------------------------
# Gazelle Hook: sink into a deep crouch, then spring up and forward into a
# rising lead hook (the whole body drives up through the fist).
var _gazelle_load := PackedFloat32Array([0.55, 0.4, 0.6, 1.6, 0.85, 3.0, 1.1, -0.9, -0.3, -1.2, -6.0, 0.0, 0.0, 14.0])
var _gazelle_hit := PackedFloat32Array([-0.05, 0.0, 2.0, 2.5, 0.85, 3.0, 0.55, -0.1, -0.6, -0.3, 10.0, 0.0, 0.3, -8.0])
# 540 Tornado Kick (airborne, drawn turned away at contact): knees tucked
# through the spin, then the rear leg lashes out at head height.
var _t540_load := PackedFloat32Array([0.3, 0.3, 1.0, 2.8, 0.8, 2.8, 1.8, -0.6, 1.4, -1.2, 0.0, 0.0])
var _t540_hit := PackedFloat32Array([0.65, 0.5, 1.3, 2.6, 0.5, 2.4, 1.6, -0.4, -2.3, -2.2, -4.0, 0.0])
# --- Muay Thai ------------------------------------------------------------------
# Elbow: the rear forearm folds back and the point of the elbow leads, the
# shoulders turning hard through.
var _elbow_load := PackedFloat32Array([0.15, 0.15, 0.95, 2.95, 0.9, 3.0, 0.55, -0.15, -0.5, -0.45, -4.0, 0.0, 0.0, 15.0])
var _elbow_hit := PackedFloat32Array([0.4, 0.1, 0.9, 2.9, 1.7, 4.3, 0.75, 0.1, -0.7, -0.55, 12.0, 0.0, 0.5, -10.0])
# Roundhouses: hips open (spread), the shin swings through low or at the ribs,
# the torso leaning away as counter-balance.
var _lowrh_load := PackedFloat32Array([0.0, 0.1, 1.0, 2.8, 0.7, 2.9, 0.7, -0.4, -0.5, -0.3, -4.0, 0.0, 0.0, 16.0])
var _lowrh_hit := PackedFloat32Array([-0.35, 0.25, 1.1, 2.6, 0.4, 2.6, 1.05, 1.3, -0.4, -0.25, 6.0, 0.0, 0.8, 2.0])
var _bodyrh_load := PackedFloat32Array([0.0, 0.1, 1.0, 2.8, 0.7, 2.9, 1.2, -0.6, -0.5, -0.3, -4.0, 0.0, 0.0, 16.0])
var _bodyrh_hit := PackedFloat32Array([-0.5, 0.35, 1.2, 2.5, 0.3, 2.4, 1.5, 1.75, -0.35, -0.2, 8.0, 0.0, 0.8, 2.0])
# Flying knee (airborne): hands reaching to grab the head, knee driven up.
var _fknee_load := PackedFloat32Array([0.1, 0.1, 1.5, 2.4, 1.4, 2.3, 1.2, -0.8, -0.3, -0.6, 0.0, 0.0])
var _fknee_hit := PackedFloat32Array([0.35, -0.05, 1.7, 2.6, 1.6, 2.5, 2.1, -0.5, -0.6, -0.4, 8.0, 0.0])
# --- Karate ----------------------------------------------------------------------
# Gyaku-zuki: long low stance, rear fist chambered at the hip, then the hips
# snap square as the rear fist drives straight out, rear heel turning.
var _gyaku_load := PackedFloat32Array([0.1, 0.15, 1.2, 2.0, 0.3, 2.4, 0.9, -0.25, -0.85, -0.35, -8.0, 0.0, 0.0, 16.0])
var _gyaku_hit := PackedFloat32Array([0.25, 0.05, 0.6, 2.4, 1.57, 1.57, 1.0, -0.25, -0.95, -0.4, 18.0, 0.0, 0.9, -10.0])
# Knife hand: the blade of the lead hand raised beside the head, chopping down.
var _knife_load := PackedFloat32Array([0.05, 0.15, 2.7, 3.7, 0.9, 3.0, 0.6, -0.15, -0.6, -0.3, -2.0, 0.0, 0.0, 14.0])
var _knife_hit := PackedFloat32Array([0.3, 0.1, 1.6, 1.25, 0.9, 3.0, 0.7, -0.1, -0.65, -0.35, 8.0, 0.0, 0.3, 6.0])
# Rising punch / rising palm: a straight arm driving upward from a dip.
var _rpunch_hit := PackedFloat32Array([0.1, -0.05, 0.7, 2.8, 1.6, 2.7, 0.75, -0.2, -0.5, -0.55, 8.0, 4.0, 0.7, -6.0])
var _rpalm_hit := PackedFloat32Array([0.1, -0.05, 0.8, 2.8, 1.55, 2.8, 0.75, -0.2, -0.5, -0.55, 8.0, 4.0, 0.7, -6.0])
# Spinning counter kick (turned away): the heel snaps back at chest height.
var _scounter_load := PackedFloat32Array([0.45, 0.4, 1.0, 2.8, 0.9, 2.9, 0.4, -0.3, 0.6, -1.4, -2.0, 0.0, 0.0, 6.0])
var _scounter_hit := PackedFloat32Array([0.7, 0.5, 1.2, 2.6, 0.6, 2.4, 0.3, -0.05, -1.8, -1.7, -6.0, 0.0, 0.0, 4.0])
# --- Kung Fu -----------------------------------------------------------------------
# Low side kick: a stamping side kick at knee height from a sunk stance.
var _lowside_load := PackedFloat32Array([-0.2, 0.25, 1.1, 2.6, 0.7, 2.9, 1.3, -1.2, -0.3, -0.2, -4.0, 4.0, 0.6, 10.0])
var _lowside_hit := PackedFloat32Array([-0.45, 0.35, 1.2, 2.3, 0.7, 2.8, 1.25, 1.45, -0.35, -0.15, 8.0, 2.0, 0.9, 12.0])
# --- Taekwondo ------------------------------------------------------------------
# Axe kick: the straight leg swings up past the head, then chops down.
var _axe_raise := PackedFloat32Array([-0.25, 0.3, 1.1, 2.4, 0.6, 2.8, 2.8, 2.9, -0.3, -0.2, -4.0, 0.0, 0.3, 10.0])
var _axe_chop := PackedFloat32Array([0.15, 0.25, 1.0, 2.4, 0.6, 2.8, 2.15, 2.0, -0.35, -0.2, 6.0, 0.0, 0.3, 8.0])
# Spinning hook kick (drawn turned away, like the back kick): the rear leg
# whips up behind the body at head height.
var _shook_load := PackedFloat32Array([0.4, 0.35, 1.0, 2.8, 0.9, 2.9, 0.25, -0.1, 0.9, -1.6, 0.0, 0.0, 0.0, 6.0])
var _shook_hit := PackedFloat32Array([0.75, 0.5, 1.2, 2.6, 0.6, 2.4, 0.3, -0.05, -2.2, -2.0, -6.0, 0.0, 0.0, 4.0])
# Jump roundhouse: in the air, knee up then the shin lashes out high.
var _jrh_load := PackedFloat32Array([0.0, 0.1, 0.8, 2.7, 0.5, 2.8, 2.0, 0.4, 1.0, -1.2, -2.0, 0.0])
var _jrh_hit := PackedFloat32Array([-0.4, 0.3, 0.9, 2.5, 0.3, 2.6, 2.1, 2.0, 0.8, -1.1, 6.0, 0.0])
# Jumping spin kick (turned away in the air): rear heel thrust back at the target.
var _jspin_load := PackedFloat32Array([0.3, 0.3, 1.0, 2.8, 0.8, 2.8, 1.6, -0.5, 0.6, -1.4, 0.0, 0.0])
var _jspin_hit := PackedFloat32Array([0.6, 0.45, 1.2, 2.6, 0.5, 2.4, 1.5, -0.3, -1.7, -1.6, -4.0, 0.0])

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
var _crouch_default := PackedFloat32Array()
var _crouch_block_default := PackedFloat32Array()
# Dodge: backstep sway (lean out of range) and slip-in (duck under, forward).
var _dodge_back := PackedFloat32Array([-0.45, -0.25, 1.0, 2.9, 0.8, 3.0, 0.35, 0.1, -0.85, -0.6, -10.0, 0.0])
var _dodge_slip := PackedFloat32Array([0.65, 0.35, 1.0, 2.9, 0.8, 3.0, 0.9, -0.3, -0.7, -0.55, 8.0, 0.0])
# Hit reactions: head hits snap the head back, body hits fold the fighter forward.
var _hitstun := PackedFloat32Array([-0.45, -0.4, 0.2, 0.9, -0.3, 0.4, 0.3, 0.0, -0.5, -0.3, -6.0, 6.0])
var _hitstun_body := PackedFloat32Array([0.5, 0.35, 0.35, 1.9, 0.25, 1.7, 0.55, -0.2, -0.45, -0.5, -8.0, 14.0])
# Heavy head hit: head and shoulders whipped back and twisted, arms flung.
var _hitstun_heavy := PackedFloat32Array([-0.62, -0.6, -0.35, 0.4, -0.55, 0.1, 0.25, 0.05, -0.55, -0.25, -10.0, 8.0, 0.0, -4.0])
# Launched (uppercut / air hit): arched back, arms thrown up, legs trailing.
# Directional head reactions (heavy; light ones blend halfway from the guard).
# Hook: the head whips round and down, the shoulders turn with it, a cross-step.
var _hitstun_hook := PackedFloat32Array([-0.25, 0.65, 0.2, 1.0, -0.35, 0.5, 0.5, -0.1, -0.75, -0.4, -8.0, 6.0, 0.3, -10.0])
# Uppercut / knee to the head: chin snapped up, leaning back on the heels, arms flung up.
var _hitstun_up := PackedFloat32Array([-0.75, -0.8, 1.9, 2.6, 1.4, 2.4, 0.35, 0.05, -0.55, -0.25, -10.0, -2.0, 0.0, 2.0])
# Axe kick / overhand: driven down, knees buckling, head dropped.
var _hitstun_down := PackedFloat32Array([0.65, 0.9, 0.5, 1.4, 0.35, 1.2, 0.95, -0.5, -0.45, -0.9, -4.0, 18.0, 0.0, 4.0])
# Low kick: the lead knee buckles, the body dips toward it, a hand drops to the leg.
var _hitstun_leg := PackedFloat32Array([0.5, 0.4, 0.25, 0.5, 0.55, 2.6, 1.15, -0.35, -0.55, -0.5, -6.0, 24.0, 0.0, 6.0])
var _launched := PackedFloat32Array([-0.75, -0.55, 2.3, 2.9, 1.9, 2.5, 0.5, 0.35, -0.1, -0.4, 0.0, 0.0])
# Light hits are half-way between the stance and the full reaction (built in _ready).
var _hitstun_light := PackedFloat32Array()
var _hitstun_body_light := PackedFloat32Array()
# Knockdown / get-up.
var _knock_fly := PackedFloat32Array([-0.3, -0.5, 2.2, 2.6, 1.8, 2.4, 0.6, 0.3, 0.1, -0.2, 0.0, 0.0])
var _ko := PackedFloat32Array([-1.5, 0.15, -1.3, -1.6, 1.3, 1.5, 1.48, 1.55, 1.42, 1.5, 0.0, 6.0])
var _getup_sit := PackedFloat32Array([0.25, 0.1, 0.9, 2.2, -0.5, -0.2, 1.45, 1.55, 1.4, 1.5, 0.0, 6.0])
var _getup_crouch := PackedFloat32Array([0.5, 0.1, 0.85, 2.4, 0.5, 2.5, 1.45, -0.55, 1.15, -0.85, -4.0, 14.0])
# Tucked ball (knockdown / evasive rolls): chin down, knees pulled to the
# chest, heels to the seat and the forearms wrapped round the shins.
var _tuck := PackedFloat32Array([1.3, 1.1, 2.2, 4.5, 2.0, 4.4, 2.55, -0.45, 2.4, -0.5, 0.0, 0.0])

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
var _stagger := PackedFloat32Array([0.3, 0.45, 0.35, 1.1, 0.25, 0.9, 0.55, -0.25, -0.55, -0.6, -4.0, 12.0])
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
# Style intro poses (MartialArtStyle.intro_pose). Muay Thai: on the rear leg,
# lead knee high with the foot hanging, rear glove on top of the head, lead
# glove at the chin.
var _mt_ready := PackedFloat32Array([-0.05, 0.2, 0.35, 2.95, 3.55, 1.75, 2.05, -0.15, -0.05, -0.12, 0.0, 0.0, 0.3, 4.0])
## Intro poses that stand on one leg (the feet are not planted on the floor).
const ONE_LEG_POSES: Array[StringName] = [&"mt_ready"]

# Muay Thai roundhouses: step out, turn the hip over, lean the torso far back
# against a straight leg that lands with the shin; the kicking-side arm swings
# down and back, the other glove stays at the face.
var _mt_rh_load := PackedFloat32Array([-0.2, 0.15, 1.3, 2.85, 0.4, 2.4, 1.1, -0.2, -0.35, -0.45, -2.0, 2.0, 0.5, 12.0])
var _mt_rh_body := PackedFloat32Array([-0.8, 0.55, 2.2, 4.6, -0.2, 0.15, 1.62, 1.72, -0.18, -0.12, 10.0, 0.0, 1.0, 2.0])
var _mt_rh_high := PackedFloat32Array([-1.0, 0.75, 2.0, 4.75, -0.2, 0.2, 2.25, 2.35, -0.2, -0.12, 10.0, 0.0, 1.0, 2.0])
var _mt_rh_low := PackedFloat32Array([-0.5, 0.35, 2.3, 4.6, -0.15, 0.2, 1.0, 1.15, -0.25, -0.2, 8.0, 3.0, 1.0, 2.0])
# Muay Thai flying knees: both hands grab the head and pull it into the knee.
var _mt_kface_hit := PackedFloat32Array([-0.1, 0.25, 1.1, 0.8, 1.0, 0.75, -0.45, -0.75, 2.3, -0.55, 8.0, 0.0, 0.6, -8.0])
var _mt_fknee_hit := PackedFloat32Array([0.0, 0.2, 1.1, 0.8, 1.0, 0.75, 2.25, -0.5, -0.6, -0.5, 8.0, 0.0])

## Named poses a FinisherDirector can request via Fighter.script_pose.
var _pose_library: Dictionary = {}
## AttackType -> keyframes [phase, fraction, pose, easing].
var _moves: Dictionary = {}
## Outfit kit -> {AttackType -> keyframes}: a style's own version of a shared move.
var _kit_moves: Dictionary = {}

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
## This fighter's position when _last_joints was drawn.
var _last_root := Vector2.ZERO
var _last_facing: int = 0
# Active idle: amount (0..1), hip dip in px and heel lifts (x lead, y rear).
var _idle_amount: float = 0.0
var _bob: float = 0.0
var _bob_target: float = 0.0
var _heel := Vector2.ZERO
var _heel_target := Vector2.ZERO
## Heel lifts for the legs as drawn (swapped for southpaw stances).
var _heel_draw := Vector2.ZERO
## Current toe point per leg (x lead, y rear), eased toward the technique's.
var _foot_point := Vector2.ZERO
## Outfit (MartialArtStyle.kit).
var _kit: StringName = &"gi"
## Cel shading on the body fill pass (boxing kit): shadow on the far side of
## every limb and the torso, a highlight along the near edge.
var _shade: bool = false
## Where punches aim (opponent's drawn head / chest, local), held during
## hitstop so the glove stays on the contact point while the target reacts.
var _aim_head := Vector2.INF
var _aim_chest := Vector2.INF
var _aim_chin_offset := Vector2.ZERO
## Shoe colour on the fill pass (transparent = body colour).
var _shoe := Color.TRANSPARENT
# Style outfits: body parts that are cloth (part -> [near colour, far colour,
# extra bulk]); everything else is skin. Details (belts, collars, armbands,
# hair) are drawn in the same body pass, so depth order stays right.
enum { P_UPPER_ARM, P_FOREARM, P_TORSO, P_THIGH, P_SHIN, P_FOOT }
const OUTFIT_KITS: Array[StringName] = [&"muay_thai", &"karate", &"kung_fu", &"taekwondo", &"kickboxing", &"bangla_maar"]
const GLOVED_KITS: Array[StringName] = [&"boxing", &"muay_thai", &"kickboxing"]
const GI_WHITE := Color(0.95, 0.94, 0.9)
const GI_BLACK := Color(0.14, 0.14, 0.16)
const CLOTH_FAR_DARKEN: float = 0.18
var _outfit: Dictionary = {}
var _cols: Dictionary = {}
## Drawing a far-side limb (outfit colours are darkened like the skin).
var _far: bool = false
## Where the belt goes this frame ([waist, across, sway]; set by the torso).
var _belt_at: Array = []
## Extra thickness of the limb segment being drawn (cloth bulk).
var _grow: float = 0.0
var _skin := SKIN_LIGHT

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
		&"relaxed": _relaxed, &"salute": _salute, &"glare": _glare, &"mt_ready": _mt_ready,
		# Style finishers reuse the move poses.
		&"lhook_hit": _lhook_hit, &"rhook_hit": _rhook_hit, &"bhook_load": _bhook_load, &"bhook_hit": _bhook_hit,
		&"overhand_hit": _overhand_hit, &"slip_dip": _slip_dip, &"uppercut_windup": _uppercut_windup,
		&"heavy_windup": _heavy_windup, &"front_extend": _front_extend, &"high_extend": _high_extend,
		&"shook_load": _shook_load, &"shook_hit": _shook_hit, &"axe_raise": _axe_raise, &"axe_chop": _axe_chop,
		&"elbow_load": _elbow_load, &"elbow_hit": _elbow_hit, &"lowrh_hit": _lowrh_hit, &"bodyrh_hit": _bodyrh_hit,
		&"fknee_hit": _fknee_hit, &"gyaku_load": _gyaku_load, &"gyaku_hit": _gyaku_hit, &"knife_hit": _knife_hit,
		&"rpalm_hit": _rpalm_hit, &"lowside_hit": _lowside_hit, &"sweep_load": _sweep_load, &"sweep_extend": _sweep_extend,
		&"back_extend": _back_extend, &"jrh_hit": _jrh_hit, &"deflect": _deflect,
		&"rbody_load": _rbody_load, &"rbody_hit": _rbody_hit, &"upper_load_deep": _upper_load_deep,
		# Directional reactions for finisher victims.
		&"hitstun_hook": _hitstun_hook, &"hitstun_up": _hitstun_up, &"hitstun_down": _hitstun_down,
		&"hitstun_leg": _hitstun_leg, &"hitstun_heavy": _hitstun_heavy,
		# Bangla Maar finishers.
		&"getup_sit": _getup_sit, &"lkick_hit": _lkick_hit, &"thrust_chamber": _thrust_chamber,
		&"thrust_extend": _thrust_extend, &"punt_load": _punt_load, &"punt_hit": _punt_hit, &"punt_follow": _punt_follow, &"ko_lie": _ko,
		&"lkick_load": _lkick_load, &"mega_slap_follow": _mega_slap_follow,
		&"mega_slap_wind": _mega_slap_wind, &"mega_slap_hit": _mega_slap_hit,
		&"hand_shake_a": _hand_shake_a, &"hand_shake_b": _hand_shake_b, &"push_load": _push_load,
		&"push_hit": _push_hit, &"stomach_hit": _stomach_hit, &"hammer_raise": _hammer_raise, &"hammer_hit": _hammer_hit,
		&"slap_hit": _slap_hit, &"bb_fly": _bb_fly,
	}
	_kit_moves = {
		&"muay_thai": {
			CombatData.AttackType.BODY_ROUNDHOUSE: [
				[S, 0.55, _mt_rh_load, EASE_SMOOTH], [A, 0.0, _mt_rh_body, EASE_IN],
				[A, 1.0, _over(_mt_rh_body, _mt_rh_load), EASE_LINEAR], [R, 0.45, _mt_rh_load, EASE_OUT]],
			CombatData.AttackType.HIGH_KICK: [
				[S, 0.5, _mt_rh_load, EASE_SMOOTH], [A, 0.0, _mt_rh_high, EASE_IN],
				[A, 1.0, _over(_mt_rh_high, _mt_rh_load), EASE_LINEAR], [R, 0.45, _mt_rh_load, EASE_OUT]],
			CombatData.AttackType.LOW_ROUNDHOUSE: [
				[S, 0.55, _mt_rh_load, EASE_SMOOTH], [A, 0.0, _mt_rh_low, EASE_IN],
				[A, 1.0, _over(_mt_rh_low, _mt_rh_load), EASE_LINEAR], [R, 0.4, _mt_rh_load, EASE_OUT]],
			CombatData.AttackType.FLYING_KNEE_FACE: [
				[S, 0.3, _jump_squat, EASE_SMOOTH], [S, 0.85, _kface_load, EASE_SMOOTH], [A, 0.0, _mt_kface_hit, EASE_IN],
				[A, 1.0, _mt_kface_hit, EASE_LINEAR], [R, 0.45, _kface_load, EASE_OUT]],
			CombatData.AttackType.FLYING_KNEE: [
				[S, 0.35, _jump_squat, EASE_SMOOTH], [S, 0.85, _kface_load, EASE_SMOOTH],
				[A, 0.0, _mt_fknee_hit, EASE_IN], [A, 1.0, _mt_fknee_hit, EASE_LINEAR], [R, 0.5, _fknee_load, EASE_OUT]],
		},
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
		CombatData.AttackType.LEAD_HOOK: [
			[S, 0.5, _lhook_load, EASE_SMOOTH], [A, 0.0, _lhook_hit, EASE_IN],
			[A, 1.0, _over(_lhook_hit, _lhook_load), EASE_LINEAR], [R, 0.35, _lhook_hit, EASE_LINEAR]],
		CombatData.AttackType.REAR_HOOK: [
			[S, 0.55, _rhook_load, EASE_SMOOTH], [A, 0.0, _rhook_hit, EASE_IN],
			[A, 1.0, _over(_rhook_hit, _rhook_load), EASE_LINEAR], [R, 0.3, _rhook_hit, EASE_LINEAR]],
		CombatData.AttackType.BODY_HOOK: [
			[S, 0.5, _bhook_load, EASE_SMOOTH], [A, 0.0, _bhook_hit, EASE_IN],
			[A, 1.0, _over(_bhook_hit, _bhook_load), EASE_LINEAR], [R, 0.35, _bhook_load, EASE_OUT]],
		CombatData.AttackType.OVERHAND: [
			[S, 0.6, _overhand_load, EASE_SMOOTH], [A, 0.0, _overhand_hit, EASE_IN],
			[A, 1.0, _over(_overhand_hit, _overhand_load), EASE_LINEAR], [R, 0.3, _overhand_hit, EASE_LINEAR]],
		CombatData.AttackType.SLIP_COUNTER: [
			[S, 0.45, _slip_dip, EASE_SMOOTH], [S, 0.8, _slip_dip, EASE_LINEAR], [A, 0.0, _slip_hit, EASE_IN],
			[A, 1.0, _over(_slip_hit, _slip_dip), EASE_LINEAR], [R, 0.3, _slip_hit, EASE_LINEAR]],
		CombatData.AttackType.AXE_KICK: [
			[S, 0.7, _axe_raise, EASE_SMOOTH], [A, 0.0, _axe_chop, EASE_IN],
			[A, 1.0, _over(_axe_chop, _axe_raise), EASE_LINEAR], [R, 0.4, _axe_chop, EASE_LINEAR]],
		CombatData.AttackType.SPIN_HOOK_KICK: [
			[S, 0.7, _shook_load, EASE_SMOOTH], [A, 0.0, _shook_hit, EASE_IN],
			[A, 1.0, _over(_shook_hit, _shook_load), EASE_LINEAR], [R, 0.35, _shook_load, EASE_OUT]],
		CombatData.AttackType.JUMP_ROUNDHOUSE: [
			[S, 0.5, _jrh_load, EASE_SMOOTH], [A, 0.0, _jrh_hit, EASE_IN],
			[A, 1.0, _jrh_hit, EASE_LINEAR], [R, 0.5, _jrh_load, EASE_OUT]],
		CombatData.AttackType.ELBOW: [
			[S, 0.5, _elbow_load, EASE_SMOOTH], [A, 0.0, _elbow_hit, EASE_IN],
			[A, 1.0, _over(_elbow_hit, _elbow_load), EASE_LINEAR], [R, 0.3, _elbow_hit, EASE_LINEAR]],
		CombatData.AttackType.KNEE: [
			[S, 0.5, _knee_windup, EASE_SMOOTH], [A, 0.0, _knee, EASE_IN],
			[A, 1.0, _over(_knee, _knee_windup), EASE_LINEAR], [R, 0.35, _knee, EASE_LINEAR]],
		CombatData.AttackType.LOW_ROUNDHOUSE: [
			[S, 0.55, _lowrh_load, EASE_SMOOTH], [A, 0.0, _lowrh_hit, EASE_IN],
			[A, 1.0, _over(_lowrh_hit, _lowrh_load), EASE_LINEAR], [R, 0.4, _lowrh_load, EASE_OUT]],
		CombatData.AttackType.BODY_ROUNDHOUSE: [
			[S, 0.55, _bodyrh_load, EASE_SMOOTH], [A, 0.0, _bodyrh_hit, EASE_IN],
			[A, 1.0, _over(_bodyrh_hit, _bodyrh_load), EASE_LINEAR], [R, 0.4, _bodyrh_load, EASE_OUT]],
		CombatData.AttackType.FLYING_KNEE: [
			[S, 0.35, _jump_squat, EASE_SMOOTH], [S, 0.85, _fknee_load, EASE_SMOOTH],
			[A, 0.0, _fknee_hit, EASE_IN], [A, 1.0, _fknee_hit, EASE_LINEAR], [R, 0.5, _fknee_load, EASE_OUT]],
		CombatData.AttackType.REVERSE_PUNCH: [
			[S, 0.55, _gyaku_load, EASE_SMOOTH], [A, 0.0, _gyaku_hit, EASE_IN],
			[A, 1.0, _over(_gyaku_hit, _gyaku_load), EASE_LINEAR], [R, 0.35, _gyaku_hit, EASE_LINEAR]],
		CombatData.AttackType.PERFECT_GYAKU: [
			[S, 0.55, _gyaku_load, EASE_SMOOTH], [S, 0.9, _gyaku_load, EASE_LINEAR], [A, 0.0, _gyaku_hit, EASE_IN],
			[A, 1.0, _over(_gyaku_hit, _gyaku_load), EASE_LINEAR], [R, 0.45, _gyaku_hit, EASE_LINEAR]],
		CombatData.AttackType.KNIFE_HAND: [
			[S, 0.55, _knife_load, EASE_SMOOTH], [A, 0.0, _knife_hit, EASE_IN],
			[A, 1.0, _over(_knife_hit, _knife_load), EASE_LINEAR], [R, 0.35, _knife_hit, EASE_LINEAR]],
		CombatData.AttackType.RISING_PUNCH: [
			[S, 0.55, _uppercut_windup, EASE_SMOOTH], [A, 0.0, _rpunch_hit, EASE_IN],
			[A, 1.0, _over(_rpunch_hit, _uppercut_windup), EASE_LINEAR], [R, 0.25, _rpunch_hit, EASE_LINEAR]],
		CombatData.AttackType.SPIN_COUNTER_KICK: [
			[S, 0.7, _scounter_load, EASE_SMOOTH], [A, 0.0, _scounter_hit, EASE_IN],
			[A, 1.0, _over(_scounter_hit, _scounter_load), EASE_LINEAR], [R, 0.35, _scounter_load, EASE_OUT]],
		CombatData.AttackType.STRAIGHT_PALM: [
			[S, 0.45, _jab_windup, EASE_SMOOTH], [A, 0.0, _palm_lead, EASE_IN],
			[A, 1.0, _over(_palm_lead, _jab_windup), EASE_LINEAR], [R, 0.45, null, EASE_OUT]],
		CombatData.AttackType.DOUBLE_PALM: [
			[S, 0.6, _palm_windup, EASE_SMOOTH], [A, 0.0, _palm_strike, EASE_IN],
			[A, 1.0, _over(_palm_strike, _palm_windup), EASE_LINEAR], [R, 0.3, _palm_strike, EASE_LINEAR]],
		CombatData.AttackType.LOW_SIDE_KICK: [
			[S, 0.55, _lowside_load, EASE_SMOOTH], [A, 0.0, _lowside_hit, EASE_IN],
			[A, 1.0, _over(_lowside_hit, _lowside_load), EASE_LINEAR], [R, 0.4, _lowside_load, EASE_OUT]],
		CombatData.AttackType.RISING_PALM: [
			[S, 0.55, _uppercut_windup, EASE_SMOOTH], [A, 0.0, _rpalm_hit, EASE_IN],
			[A, 1.0, _over(_rpalm_hit, _uppercut_windup), EASE_LINEAR], [R, 0.25, _rpalm_hit, EASE_LINEAR]],
		CombatData.AttackType.CHAIN_PALMS: [
			[S, 0.6, _jab_windup, EASE_SMOOTH], [A, 0.0, _palm_lead, EASE_IN], [A, 0.33, _palm_rear, EASE_IN],
			[A, 0.66, _palm_lead, EASE_IN], [A, 1.0, _palm_rear, EASE_IN], [R, 0.4, _palm_rear, EASE_LINEAR]],
		CombatData.AttackType.DEFLECT_COUNTER: [
			[S, 0.35, _deflect, EASE_SMOOTH], [S, 0.8, _deflect, EASE_LINEAR], [A, 0.0, _palm_rear, EASE_IN],
			[A, 1.0, _over(_palm_rear, _deflect), EASE_LINEAR], [R, 0.3, _palm_rear, EASE_LINEAR]],
		CombatData.AttackType.GAZELLE_HOOK: [
			[S, 0.45, _gazelle_load, EASE_SMOOTH], [S, 0.8, _gazelle_load, EASE_LINEAR],
			[A, 0.0, _gazelle_hit, EASE_IN], [A, 1.0, _over(_gazelle_hit, _gazelle_load), EASE_LINEAR],
			[R, 0.4, _gazelle_hit, EASE_LINEAR]],
		CombatData.AttackType.TORNADO_540: [
			[S, 0.3, _jump_squat, EASE_SMOOTH], [S, 0.85, _t540_load, EASE_SMOOTH],
			[A, 0.0, _t540_hit, EASE_IN], [A, 1.0, _t540_hit, EASE_LINEAR], [R, 0.4, _t540_load, EASE_OUT]],
		CombatData.AttackType.JUMP_SPIN_KICK: [
			[S, 0.6, _jspin_load, EASE_SMOOTH], [A, 0.0, _jspin_hit, EASE_IN],
			[A, 1.0, _jspin_hit, EASE_LINEAR], [R, 0.5, _jspin_load, EASE_OUT]],
		CombatData.AttackType.POWER_UPPERCUT: [
			[S, 0.45, _pupper_coil, EASE_SMOOTH], [S, 0.85, _pupper_coil, EASE_LINEAR],
			[A, 0.0, _pupper_hit, EASE_IN], [A, 1.0, _pupper_hit, EASE_LINEAR], [R, 0.35, _pupper_hit, EASE_LINEAR]],
		CombatData.AttackType.SUPERMAN_PUNCH: [
			[S, 0.35, _sm_load, EASE_SMOOTH], [S, 0.6, _sm_load, EASE_LINEAR], [A, 0.0, _sm_hit, EASE_IN],
			[A, 1.0, _sm_hit, EASE_LINEAR], [R, 0.4, _sm_land, EASE_SMOOTH]],
		CombatData.AttackType.JUMPING_ELBOW: [
			[S, 0.3, _jump_squat, EASE_SMOOTH], [S, 0.85, _jelbow_load, EASE_SMOOTH], [A, 0.0, _jelbow_hit, EASE_IN],
			[A, 1.0, _jelbow_hit, EASE_LINEAR], [R, 0.4, _jelbow_recoil, EASE_SMOOTH]],
		CombatData.AttackType.FLYING_KNEE_FACE: [
			[S, 0.3, _jump_squat, EASE_SMOOTH], [S, 0.85, _kface_load, EASE_SMOOTH], [A, 0.0, _kface_hit, EASE_IN],
			[A, 1.0, _kface_hit, EASE_LINEAR], [R, 0.45, _kface_load, EASE_OUT]],
		CombatData.AttackType.JUMPING_REVERSE_PUNCH: [
			[S, 0.3, _jump_squat, EASE_SMOOTH], [S, 0.85, _jrp_load, EASE_SMOOTH], [A, 0.0, _jrp_hit, EASE_IN],
			[A, 1.0, _jrp_hit, EASE_LINEAR], [R, 0.4, _jrp_recoil, EASE_SMOOTH]],
		CombatData.AttackType.FLYING_SIDE_KICK: [
			[S, 0.3, _jump_squat, EASE_SMOOTH], [S, 0.85, _fsk_chamber, EASE_SMOOTH], [A, 0.0, _fsk_extend, EASE_IN],
			[A, 1.0, _fsk_extend, EASE_LINEAR], [R, 0.45, _fsk_chamber, EASE_OUT]],
		CombatData.AttackType.LEAPING_PALM: [
			[S, 0.25, _jump_squat, EASE_SMOOTH], [S, 0.85, _leap_palm_load, EASE_SMOOTH], [A, 0.0, _leap_palm_hit, EASE_IN],
			[A, 1.0, _leap_palm_hit, EASE_LINEAR], [R, 0.4, _leap_palm_load, EASE_OUT]],
		CombatData.AttackType.FLYING_DOUBLE_PALM: [
			[S, 0.3, _jump_squat, EASE_SMOOTH], [S, 0.85, _fdp_load, EASE_SMOOTH], [A, 0.0, _fdp_hit, EASE_IN],
			[A, 1.0, _fdp_hit, EASE_LINEAR], [R, 0.4, _fdp_load, EASE_OUT]],
		CombatData.AttackType.JUMPING_BACKFIST: [
			[S, 0.3, _jump_squat, EASE_SMOOTH], [S, 0.85, _jbf_load, EASE_SMOOTH], [A, 0.0, _jbf_hit, EASE_IN],
			[A, 1.0, _over(_jbf_hit, _jbf_load), EASE_LINEAR], [R, 0.4, _jbf_load, EASE_OUT]],
		CombatData.AttackType.JUMPING_SPIN_HOOK: [
			[S, 0.25, _jump_squat, EASE_SMOOTH], [S, 0.85, _jshk_load, EASE_SMOOTH], [A, 0.0, _jshk_hit, EASE_IN],
			[A, 1.0, _jshk_hit, EASE_LINEAR], [R, 0.45, _jshk_load, EASE_OUT]],
		CombatData.AttackType.LEAPING_ROUNDHOUSE: [
			[S, 0.3, _jump_squat, EASE_SMOOTH], [S, 0.85, _lrh_load, EASE_SMOOTH], [A, 0.0, _lrh_hit, EASE_IN],
			[A, 1.0, _lrh_hit, EASE_LINEAR], [R, 0.45, _lrh_load, EASE_OUT]],
		CombatData.AttackType.LIGHT_SLAP: [
			[S, 0.55, _slap_wind, EASE_SMOOTH], [A, 0.0, _slap_hit, EASE_IN], [A, 1.0, _slap_follow, EASE_LINEAR],
			[R, 0.45, _slap_follow, EASE_OUT]],
		CombatData.AttackType.THRUST_KICK: [
			[S, 0.6, _thrust_chamber, EASE_SMOOTH], [A, 0.0, _thrust_extend, EASE_IN],
			[A, 1.0, _thrust_extend, EASE_LINEAR], [R, 0.4, _thrust_chamber, EASE_OUT]],
		CombatData.AttackType.DOUBLE_PUSH: [
			[S, 0.6, _push_load, EASE_SMOOTH], [A, 0.0, _push_hit, EASE_IN],
			[A, 1.0, _push_hit, EASE_LINEAR], [R, 0.4, _push_hit, EASE_LINEAR]],
		CombatData.AttackType.HEAD_ELBOW: [
			[S, 0.55, _helbow_load, EASE_SMOOTH], [A, 0.0, _helbow_hit, EASE_IN],
			[A, 1.0, _over(_helbow_hit, _helbow_load), EASE_LINEAR], [R, 0.3, _helbow_hit, EASE_LINEAR]],
		CombatData.AttackType.HAMMER_FIST: [
			[S, 0.4, _hammer_raise, EASE_SMOOTH], [S, 0.85, _hammer_raise, EASE_LINEAR], [A, 0.0, _hammer_hit, EASE_IN],
			[A, 1.0, _hammer_hit, EASE_LINEAR], [R, 0.4, _hammer_hit, EASE_LINEAR]],
		CombatData.AttackType.STOMACH_SHOT: [
			[S, 0.55, _stomach_load, EASE_SMOOTH], [A, 0.0, _stomach_hit, EASE_IN],
			[A, 1.0, _over(_stomach_hit, _stomach_load), EASE_LINEAR], [R, 0.35, _stomach_load, EASE_OUT]],
		CombatData.AttackType.PARA_LEG_KICK: [
			[S, 0.55, _lkick_load, EASE_SMOOTH], [A, 0.0, _lkick_hit, EASE_IN],
			[A, 1.0, _lkick_hit, EASE_LINEAR], [R, 0.4, _lkick_load, EASE_OUT]],
		CombatData.AttackType.FLYING_SLAP: [
			[S, 0.3, _jump_squat, EASE_SMOOTH], [S, 0.85, _fslap_load, EASE_SMOOTH], [A, 0.0, _fslap_hit, EASE_IN],
			[A, 1.0, _fslap_hit, EASE_LINEAR], [R, 0.4, _fslap_load, EASE_OUT]],
		CombatData.AttackType.FLYING_CHEST_KICK: [
			[S, 0.3, _jump_squat, EASE_SMOOTH], [S, 0.85, _fck_load, EASE_SMOOTH], [A, 0.0, _fck_hit, EASE_IN],
			[A, 1.0, _fck_hit, EASE_LINEAR], [R, 0.45, _fck_load, EASE_OUT]],
		CombatData.AttackType.BELLY_BOMB: [
			[S, 0.15, _bb_back, EASE_SMOOTH], [S, 0.4, _bb_back, EASE_LINEAR], [S, 0.65, _bb_crouch, EASE_SMOOTH],
			[S, 0.85, _bb_crouch, EASE_LINEAR], [A, 0.0, _bb_fly, EASE_IN], [A, 1.0, _bb_fly, EASE_LINEAR],
			[R, 0.4, _bb_land, EASE_SMOOTH]],
		CombatData.AttackType.LEAPING_SPIN_BACKFIST: [
			[S, 0.35, _lsb_coil, EASE_SMOOTH], [S, 0.75, _lsb_turn, EASE_SMOOTH], [A, 0.0, _lsb_hit, EASE_IN],
			[A, 1.0, _lsb_hit, EASE_LINEAR], [R, 0.45, _lsb_land, EASE_SMOOTH]],
		CombatData.AttackType.FLYING_AXE_KICK: [
			[S, 0.25, _jump_squat, EASE_SMOOTH], [S, 0.45, _fax_chamber, EASE_SMOOTH], [S, 0.7, _fax_apex, EASE_OUT],
			[S, 0.9, _fax_apex, EASE_LINEAR],
			[A, 0.0, _fax_chop, EASE_IN], [A, 1.0, _fax_follow, EASE_IN], [R, 0.4, _fax_land, EASE_SMOOTH]],
		CombatData.AttackType.BOB_WEAVE: [
			[S, 1.0, _weave_in, EASE_SMOOTH], [A, 0.5, _weave_low, EASE_SMOOTH],
			[A, 1.0, _weave_out, EASE_SMOOTH], [R, 0.7, null, EASE_OUT]],
		CombatData.AttackType.LEG_FEINT: [
			[S, 1.0, _feint_lift, EASE_OUT], [A, 0.4, _feint_top, EASE_OUT],
			[A, 1.0, _feint_lift, EASE_LINEAR], [R, 0.6, null, EASE_SMOOTH]],
		CombatData.AttackType.RISING_ELBOW: [
			[S, 0.55, _relbow_load, EASE_SMOOTH], [A, 0.0, _relbow_hit, EASE_IN],
			[A, 1.0, _over(_relbow_hit, _relbow_load), EASE_LINEAR], [R, 0.3, _relbow_hit, EASE_LINEAR]],
		CombatData.AttackType.BODY_STRAIGHT: [
			[S, 0.55, _bstraight_load, EASE_SMOOTH], [A, 0.0, _bstraight_hit, EASE_IN],
			[A, 1.0, _over(_bstraight_hit, _bstraight_load), EASE_LINEAR], [R, 0.35, _bstraight_load, EASE_OUT]],
		CombatData.AttackType.BODY_PUNCH: [
			[S, 0.55, _chudan_load, EASE_SMOOTH], [A, 0.0, _chudan_hit, EASE_IN],
			[A, 1.0, _over(_chudan_hit, _chudan_load), EASE_LINEAR], [R, 0.35, _chudan_hit, EASE_LINEAR]],
		CombatData.AttackType.LOW_PALM: [
			[S, 0.55, _lpalm_load, EASE_SMOOTH], [A, 0.0, _lpalm_hit, EASE_IN],
			[A, 1.0, _over(_lpalm_hit, _lpalm_load), EASE_LINEAR], [R, 0.35, _lpalm_load, EASE_OUT]],
	}
	_victory = {
		&"boxing": [[0, null], [12, _win_box_raise], [40, _win_box_raise], [50, _win_box_tap], [58, _win_box_tap],
			[68, _win_box_raise]],
		&"muay_thai": [[0, null], [16, _win_wai], [60, _win_wai], [80, _win_wai_up]],
		&"karate": [[0, null], [14, _win_rei_ready], [32, _win_rei_ready], [46, _win_rei_bow], [64, _win_rei_bow],
			[80, _win_rei_ready]],
		&"kung_fu": [[0, null], [16, _win_kf_salute], [32, _win_kf_salute], [44, _win_kf_bow], [60, _win_kf_bow],
			[74, _win_kf_salute]],
		&"taekwondo": [[0, null], [14, _win_tkd_ready], [30, _win_tkd_ready], [44, _win_tkd_bow], [62, _win_tkd_bow],
			[76, _win_tkd_ready], [92, _win_tkd_fists]],
		&"bangla_maar": [[0, null], [14, _win_para], [44, _win_para], [56, _win_para_point], [80, _win_para_point],
			[94, _win_para]],
		&"kickboxing": [[0, null], [10, _win_kb_pump], [20, _win_kb_chest], [28, _win_kb_pump], [38, _win_kb_chest],
			[50, _win_kb_both]],
	}
	_build_light_reactions()
	_crouch_default = _crouch.duplicate()
	_crouch_block_default = _crouch_block.duplicate()
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
	_kit = fighter.style.kit if fighter.style != null else &"gi"
	_build_outfit()
	# The stance's own crouch (the boxer's duck), else the default.
	for pair in [[false, "_crouch", _crouch_default], [true, "_crouch_block", _crouch_block_default]]:
		var own := Stances.crouch_pose(fighter.stance, pair[0])
		while not own.is_empty() and own.size() < CHANNELS:
			own.append(DEFAULT_SPREAD if own.size() == SPREAD else 0.0)
		set(pair[1], own if not own.is_empty() else pair[2])
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

	# Hitstop: the whole body holds (both fighters freeze at the contact);
	# the hit's reaction impulse is applied when the freeze ends.
	if not frozen:
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
	elif dt > 0.0 and not frozen:
		_spring_toward(target, dt, _spring_params())

	_update_down_amount(t)
	_update_spin(0.0 if frozen else dt, fraction)  # tumbles hold in hitstop too
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
		Fighter.State.HITSTUN, Fighter.State.FINISHED, Fighter.State.STAGGER, Fighter.State.BROKEN, Fighter.State.DIZZY:
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
			# The head whips the way the blow travelled.
			match fighter.last_hit_kind:
				CombatData.ImpactKind.HOOK:
					_pose_vel[HEAD] += 26.0 * k
					_pose_vel[SPREAD] -= 260.0 * k
				CombatData.ImpactKind.RISING:
					_pose_vel[HEAD] -= 14.0 * k
					_pose_vel[TORSO] -= 6.0 * k
				CombatData.ImpactKind.DOWNWARD:
					_pose_vel[HEAD] += 30.0 * k
					_pose_vel[DROP] += 140.0 * k
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
	if fighter.celebration != &"" and fighter.state == Fighter.State.IDLE:
		return _victory_pose()
	if fighter.state == Fighter.State.DIZZY:
		return _dizzy_pose()
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
## Dizzy: the body sways round in a slow circle, the head lolls the other way
## and the knees buckle in turn. In the shake-off (the last
## DIZZY_RECOVER_FRAMES) the head shakes hard and the guard comes back up.
func _dizzy_pose() -> PackedFloat32Array:
	var phase := _time * TAU * 0.85
	var p := _dizzy.duplicate()
	p[TORSO] += sin(phase) * 0.13
	p[HEAD] += cos(phase) * 0.25
	p[HIP_X] += sin(phase) * 8.0
	p[TH_F] += maxf(sin(phase * 0.5), 0.0) * 0.22
	p[SH_F] -= maxf(sin(phase * 0.5), 0.0) * 0.3
	p[TH_B] -= maxf(-sin(phase * 0.5), 0.0) * 0.15
	p[SH_B] -= maxf(-sin(phase * 0.5), 0.0) * 0.3
	p[UA_F] += sin(phase + 1.0) * 0.12
	p[UA_B] += sin(phase + 2.0) * 0.12
	var recover := 1.0 - float(fighter.dizzy_left) / CombatData.DIZZY_RECOVER_FRAMES
	if recover > 0.0:
		var shake := sin(_time * TAU * 7.0) * 0.28 * (1.0 - recover)
		p = _blend(p, _guard, smoothstep(0.25, 1.0, recover))
		p[HEAD] += shake
	return p


## The winner's style routine: keys blended in time, the last one held with
## a slow breathing sway.
func _victory_pose() -> PackedFloat32Array:
	if fighter.celebration != _victory_seen:
		_victory_seen = fighter.celebration
		_victory_t0 = _time
	var keys: Array = _victory.get(fighter.celebration, [[0, null]])
	var t := (_time - _victory_t0) * 60.0
	var pose: PackedFloat32Array = _key_pose(keys[-1])
	for i in range(1, keys.size()):
		if t < float(keys[i][0]):
			var u: float = (t - float(keys[i - 1][0])) / maxf(float(keys[i][0] - keys[i - 1][0]), 1.0)
			pose = _blend(_key_pose(keys[i - 1]), _key_pose(keys[i]), smoothstep(0.0, 1.0, u))
			break
	var out := pose.duplicate()
	while out.size() < CHANNELS:
		out.append(DEFAULT_SPREAD if out.size() == SPREAD else 0.0)
	out[TORSO] += sin(_time * TAU * 0.4) * 0.025
	out[HIP_X] += sin(_time * TAU * 0.4) * 1.5
	return out


## A routine key's pose (null = the fighter's own stance guard).
func _key_pose(key: Array) -> PackedFloat32Array:
	return key[1] if key[1] != null else _guard


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
	var amp := fighter.idle_amplitude
	_bob_target = float(st["bob"]) * dip * k * amp
	var heel_base := float(st.get("rear_heel", 0.0)) * k
	if st.get("alternate", false):
		# Boxer's bounce: the heels lift on alternate bounces (rear, then lead)
		# while the weight and shoulders rock toward the planted foot.
		var side := sin(PI * hz * t)
		var rise := 1.0 - dip
		_heel_target = Vector2(float(st["lead_heel"]) * maxf(-side, 0.0), float(st["heel"]) * maxf(side, 0.0)) \
			* (0.4 + 0.6 * rise) * k * amp + Vector2(0.0, heel_base)
		idle[HIP_X] += float(st["shift"]) * side * k * amp
		idle[SPREAD] += float(st["shoulder"]) * side * k * amp
	else:
		# Heels: up on the balls of the feet as the hips rise out of a bounce, or
		# the rear heel as the weight rocks forward (lead heel as it rocks back).
		var rise := 1.0 - dip if shape == "hop" else 0.5 + 0.5 * shift
		_heel_target = Vector2(float(st["lead_heel"]) * (0.5 - 0.5 * shift), float(st["heel"]) * rise) * k * amp
		idle[HIP_X] += float(st["shift"]) * shift * k * amp
		idle[SPREAD] += float(st["shoulder"]) * sin(TAU * shift_hz * t + 0.8) * k * amp
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
	if st.get("gestures", false):
		idle = _idle_gesture(idle, t, k)
	var feint := float(st.get("feint", 0.0))
	if feint > 0.0:
		# A quick half-jab with the lead hand now and then (out and straight
		# back), the shoulder turning a touch with it.
		var every := float(st.get("feint_every", 3.0))
		var u := fposmod(t, every) / FEINT_TIME
		if u < 1.0:
			var f := sin(PI * u) * feint * k
			idle[UA_F] += f
			idle[LA_F] -= f * 1.6
			idle[SPREAD] += f * 8.0
	return idle


## Street idle gestures, one at a time on a loop: point a finger at the
## opponent (wagging it), a hand on the waist, tug the rear sleeve, shake the
## head. Each eases in and out of the relaxed stance.
const GESTURE_CYCLE: float = 8.0
const GESTURES: Array = [[0.4, 2.0, "point"], [2.6, 4.2, "waist"], [4.8, 6.0, "sleeve"], [6.5, 7.6, "shake"]]


func _idle_gesture(p: PackedFloat32Array, t: float, k: float) -> PackedFloat32Array:
	var cycle := fposmod(t + fighter.idle_phase * 3.0, GESTURE_CYCLE)
	for g in GESTURES:
		if cycle < g[0] or cycle >= g[1]:
			continue
		var u: float = (cycle - g[0]) / (g[1] - g[0])
		var w := smoothstep(0.0, 0.2, u) * (1.0 - smoothstep(0.8, 1.0, u)) * k
		match g[2]:
			"point":
				p[UA_F] = lerpf(p[UA_F], 1.45, w)
				p[LA_F] = lerpf(p[LA_F], 1.6 + sin(t * TAU * 3.0) * 0.12, w)
				p[TORSO] += 0.05 * w
			"waist":
				p[UA_B] = lerpf(p[UA_B], -0.55, w)
				p[LA_B] = lerpf(p[LA_B], 0.95, w)
			"sleeve":
				p[UA_F] = lerpf(p[UA_F], 0.95, w)
				p[LA_F] = lerpf(p[LA_F], 2.5, w)
				p[UA_B] = lerpf(p[UA_B], 0.7, w)
				p[LA_B] = lerpf(p[LA_B], 1.1 + sin(t * TAU * 4.0) * 0.15, w)
			"shake":
				p[HEAD] += sin(t * TAU * 3.5) * 0.14 * w
	return p


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
	var idle_ok := fighter.state == Fighter.State.IDLE and fighter.prefight_pose == &"" and fighter.celebration == &""
	var target := 1.0 if idle_ok else 0.0
	target *= 1.0 - IDLE_POSTURE_DAMP * smoothstep(0.5, 1.0, fighter.posture / CombatData.POSTURE_MAX)
	var rate := IDLE_FADE_IN if target > _idle_amount else IDLE_FADE_OUT
	_idle_amount = move_toward(_idle_amount, target, delta * rate)


## Back kick and the other spinning techniques (attack data "spin").
func _is_back_kick() -> bool:
	return fighter.state == Fighter.State.ATTACK and fighter.current_attack != null \
		and (fighter.current_attack.type == CombatData.AttackType.BACK_KICK or fighter.current_attack.spin)


## Back kick body turn in half-turns: 0 -> 1 (back to the opponent) through the
## startup, held through the strike, then 1 -> 2 (a full turn, facing again)
## through the recovery.
func _back_turn(t: float) -> float:
	var attack := fighter.current_attack
	if attack.spin_turns > 1.0:
		# Multi-turn spins (540): odd half-turns by contact (back to the target
		# as the heel lands), then the last half-turn round to face again.
		var halves := attack.spin_turns * 2.0
		var spin := halves * smoothstep(0.0, attack.startup + attack.active * 0.3, t)
		var end := float(attack.startup + attack.active)
		return spin + smoothstep(end + attack.recovery * 0.2, end + attack.recovery * 0.8, t)
	var turned := smoothstep(0.0, attack.startup * 0.75, t)
	var strike_end := float(attack.startup + attack.active)
	var back := smoothstep(strike_end + attack.recovery * 0.3, strike_end + attack.recovery * 0.9, t)
	return turned + back


## Hit reaction by where, how and how hard the hit landed: launched (in the
## air), legs (knee buckles), head (by direction: straight whip back, hook
## turning the head, uppercut snapping the chin up, overhand driving it down)
## or body (fold). Light hits blend halfway from the guard. Consecutive hits
## alternate small variations so a combo never repeats the same frame.
func _reaction_pose() -> PackedFloat32Array:
	if fighter.airborne:
		return _launched
	var heavy := fighter.last_hit_heavy
	var pose: PackedFloat32Array
	if fighter.last_hit_low:
		pose = _hitstun_leg
	elif fighter.last_hit_high:
		match fighter.last_hit_kind:
			CombatData.ImpactKind.HOOK:
				pose = _hitstun_hook
			CombatData.ImpactKind.RISING:
				pose = _hitstun_up
			CombatData.ImpactKind.DOWNWARD:
				pose = _hitstun_down
			_:
				return _varied(_hitstun_heavy if heavy else _hitstun_light)
	else:
		return _varied(_hitstun_body if heavy else _hitstun_body_light)
	# Leg kicks always buckle the knee fully; other light hits go most of the way.
	return _varied(pose if heavy or fighter.last_hit_low else _blend(_guard, pose, 0.75))


func _varied(pose: PackedFloat32Array) -> PackedFloat32Array:
	var out := pose.duplicate()
	var s := 1.0 if fighter.hit_counter % 2 == 0 else -1.0
	out[TORSO] += 0.06 * s
	out[HEAD] += 0.12 * s
	out[HIP_X] += 3.0 * s
	out[SPREAD] += 3.0 * s
	return out


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


## Attack pose: the move's keyframes plus whole-body mechanics.
func _attack_pose(t: float) -> PackedFloat32Array:
	if fighter.current_attack == null:
		return _guard
	return _mechanics(_attack_keys(t), t)


## Drive of a strike over time: a small load against the strike (anticipation),
## a snap into the target, held through the active frames, then released quickly
## at the start of the recovery (the limb snaps back, the body settles).
static func _drive(t: float, attack: CombatData.Attack) -> float:
	var s := float(attack.startup)
	if t < s:
		var u := t / maxf(s, 1.0)
		if u < MECH_LOAD_END:
			return -MECH_LOAD * smoothstep(0.0, MECH_LOAD_END, u)
		var v := (u - MECH_LOAD_END) / (1.0 - MECH_LOAD_END)
		return lerpf(-MECH_LOAD, 1.0, v * v)
	var e := s + attack.active
	if t < e:
		return 1.0
	return 1.0 - smoothstep(0.0, MECH_RELEASE, (t - e) / maxf(float(attack.recovery), 1.0))


## Whole-body mechanics shared by every strike of a kind, so no technique is
## thrown with the arm or leg alone: the hips drive in, the shoulders turn
## through, the rear heel pivots, the chin tucks; kicks pivot on a bent support
## leg with the torso counterbalancing. Spins, sequences and air moves have
## their own full-body keys and are left alone.
func _mechanics(pose: PackedFloat32Array, t: float) -> PackedFloat32Array:
	var attack := fighter.current_attack
	if fighter.airborne or attack.spin or attack.leap_vy != 0.0 or not attack.sequence.is_empty() or attack.no_strike:
		return pose
	var gains: Dictionary = MECH_GAINS.get(_mech_kind(attack.type), {})
	if gains.is_empty():
		return pose
	var d := _drive(t, attack)
	var out := pose.duplicate()
	for ch: int in gains:
		var g: float = gains[ch]
		# Pivots and knee bends only ever add (no reverse pivot in the load).
		out[ch] += g * (maxf(d, 0.0) if ch in MECH_FORWARD_ONLY else d)
	out[PIVOT] = clampf(out[PIVOT], 0.0, 1.0)
	var kind := _mech_kind(attack.type)
	var joint := _attack_joint(attack.type)
	if d > 0.0 and joint in [J_HAND_F, J_HAND_B]:
		var lead := joint == J_HAND_F
		var high := _hits_high(attack)
		if CombatData.impact_kind(attack.type) == CombatData.ImpactKind.STRAIGHT and kind in [MECH_LEAD, MECH_REAR]:
			out = _aim_arm(out, J_SHOULDER_F if lead else J_SHOULDER_B, UA_F if lead else UA_B,
				LA_F if lead else LA_B, high, d)
		else:
			# Hooks, uppercuts, overhands: keep the arm's bend and swing the
			# whole arm about the shoulder so the glove arrives at the target.
			out = _aim_bent_arm(out, lead, high, CombatData.impact_kind(attack.type), d)
	return out


## The opponent's drawing matches where and which way it is now.
static func _drawing_fresh(ov: FighterVisual) -> bool:
	return ov != null and ov.fighter != null and ov._last_joints.size() >= JOINTS 		and ov._last_facing == ov.fighter.facing and ov._last_root.distance_to(ov.global_position) < 40.0


## The opponent's drawn head (or chin) / chest in local space; frozen while
## this fighter is in hitstop.
func _aim_point(ov: FighterVisual, high: bool, chin: bool) -> Vector2:
	if fighter.hitstop_frames <= 0 or (_aim_head == Vector2.INF):
		var oj := ov._last_joints
		# Drawn joints are anchored to where the opponent is now (they were
		# drawn up to a frame ago).
		var shift := ov.global_position - ov._last_root
		var head := oj[J_HEAD] + shift
		var chest := oj[J_HIP].lerp(oj[J_NECK], 0.55) + shift
		_aim_head = Vector2((head.x - global_position.x) * fighter.facing, head.y - global_position.y)
		_aim_chest = Vector2((chest.x - global_position.x) * fighter.facing, chest.y - global_position.y)
		var down := (oj[J_NECK] - head).normalized() * HEAD_R * 0.7
		_aim_chin_offset = Vector2(down.x * fighter.facing, down.y)
	if not high:
		return _aim_chest
	return _aim_head + (_aim_chin_offset if chin else Vector2.ZERO)


## Rotates a bent arm about its shoulder so the glove points at the target:
## the side of the head (hooks), the chin from below (uppercuts) or the ribs.
func _aim_bent_arm(pose: PackedFloat32Array, lead: bool, high: bool, kind: int, weight: float) -> PackedFloat32Array:
	var opp := fighter.opponent
	if opp == null:
		return pose
	var ov := opp.get_node_or_null("Visual") as FighterVisual
	if not _drawing_fresh(ov):
		return pose
	var target := _aim_point(ov, high, high and kind == CombatData.ImpactKind.RISING)
	var j := _solve_joints(pose)
	var shoulder := j[J_SHOULDER_F if lead else J_SHOULDER_B]
	var glove := j[J_HAND_F if lead else J_HAND_B]
	var from := glove - shoulder
	var to := target - shoulder
	if from.length() < 4.0 or to.x <= 0.0:
		return pose
	# Limb angles are measured from straight down: rotating the glove vector by
	# +x radians (screen) is -x in limb-angle terms for a right-facing body.
	var delta := clampf(wrapf(from.angle() - to.angle(), -PI, PI), -AIM_BENT_MAX, AIM_BENT_MAX) * clampf(weight, 0.0, 1.0)
	var out := pose.duplicate()
	out[UA_F if lead else UA_B] += delta
	out[LA_F if lead else LA_B] += delta
	return out


## Straight punches fire along the line from the shoulder to the target (the
## opponent's head, or the middle of the torso for a body shot) as drawn, so the
## glove meets the face rather than the chest whatever the stance, lean or
## crouch. Blended in by the strike drive.
func _aim_arm(pose: PackedFloat32Array, shoulder_joint: int, ua: int, la: int, high: bool, weight: float) -> PackedFloat32Array:
	var opp := fighter.opponent
	if opp == null:
		return pose
	var opp_visual := opp.get_node_or_null("Visual") as FighterVisual
	if not _drawing_fresh(opp_visual):
		return pose
	var target := _aim_point(opp_visual, high, false)
	var to := target - _solve_joints(pose)[shoulder_joint]
	if to.x <= 0.0:
		return pose
	var angle := clampf(atan2(to.x, to.y), AIM_MIN, AIM_MAX)
	var out := pose.duplicate()
	var w := clampf(weight, 0.0, 1.0)
	out[ua] = lerpf(pose[ua], angle, w)
	out[la] = lerpf(pose[la], angle, w)
	return out


static func _mech_kind(type: CombatData.AttackType) -> int:
	if type in [CombatData.AttackType.UPPERCUT, CombatData.AttackType.RISING_PUNCH, CombatData.AttackType.RISING_PALM,
			CombatData.AttackType.RISING_ELBOW, CombatData.AttackType.POWER_UPPERCUT]:
		return MECH_RISING
	if type in [CombatData.AttackType.LEAD_HOOK, CombatData.AttackType.BODY_HOOK]:
		return MECH_HOOK_LEAD
	if type == CombatData.AttackType.REAR_HOOK:
		return MECH_HOOK_REAR
	if type in [CombatData.AttackType.HIGH_KICK, CombatData.AttackType.BODY_ROUNDHOUSE, CombatData.AttackType.LOW_ROUNDHOUSE]:
		return MECH_ROUNDHOUSE
	match _attack_joint(type):
		J_HAND_F:
			return MECH_LEAD
		J_HAND_B, J_ELBOW_B:
			return MECH_REAR
		J_FOOT_F:
			return MECH_KICK
		J_KNEE_F:
			return MECH_KNEE
	return MECH_NONE


## Samples the move's keyframe timeline at tick time t.
func _attack_keys(t: float) -> PackedFloat32Array:
	var attack := fighter.current_attack
	var rest := _air_pose() if fighter.airborne else _guard
	var keys: Array = _kit_moves.get(_kit, {}).get(attack.type, _moves.get(attack.type, []))
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
	return _blend(prev_pose, rest, _ease(w, EASE_OUT))


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
	# Just launched but not yet off the floor (a launch lands during the hit
	# freeze): still drawn standing, so the body does not pop up at impact.
	var on_floor := fighter.ground_y - fighter.position.y < 1.0
	if not fighter.airborne or fighter.is_down() or on_floor:
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
	torso_len *= 1.0 - 0.22 * _tuck_amount  # a curled back is shorter seen from the side
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
	# Edge-on the body keeps some width (foreshortened, not a line), so a spin
	# reads as a turning body instead of collapsing to a stick.
	var turn := cos(_spin_angle)
	var face := float(fighter.facing) * (-1.0 if fighter.script_flip else 1.0) \
		* (1.0 if turn >= 0.0 else -1.0) * lerpf(SPIN_MIN_WIDTH, 1.0, absf(turn))
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

	# Rolls: the curled body turns about its own centre, which is held one
	# ball radius above the floor (so it rolls without slipping or bobbing).
	var joints := _solve_joints(_pose)
	var pivot := TUCK_PIVOT
	var centre := TUCK_PIVOT
	if _tuck_amount > 0.0:
		var box := Rect2(joints[0], Vector2.ZERO)
		for q in joints:
			box = box.expand(q)
		pivot = box.get_center()
		centre = pivot.lerp(Vector2(pivot.x, -_height - CombatData.BALL_RADIUS) if fighter.airborne else Vector2(pivot.x, -CombatData.BALL_RADIUS), smoothstep(0.0, 1.0, _tuck_amount))
		if fighter.airborne:
			centre = pivot  # tumbling in flight: just spin about the centre
	var body := Transform2D(0.0, Vector2.ONE, 0.0, centre) \
		* Transform2D(_body_rot, Vector2.ONE, 0.0, Vector2.ZERO) \
		* Transform2D(0.0, Vector2.ONE, 0.0, -pivot)
	var xform := mirror * body
	var to_world := get_global_transform() * xform
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
	_last_root = global_position
	_last_facing = fighter.facing
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if fighter.state == Fighter.State.DIZZY:
		_draw_dizzy_stars(to_local(world_joints[J_HEAD]))


## Stars circling above a dizzy fighter's head (fading out in the shake-off).
func _draw_dizzy_stars(head: Vector2) -> void:
	var fade := clampf(float(fighter.dizzy_left) / CombatData.DIZZY_RECOVER_FRAMES, 0.0, 1.0)
	var centre := head + Vector2(0.0, -HEAD_R - 14.0)
	for i in 3:
		var a := _time * TAU * 1.1 + TAU * i / 3.0
		var pos := centre + Vector2(cos(a) * 28.0, sin(a) * 8.0)
		var near := (sin(a) + 1.0) * 0.5  # front of the orbit: bigger, brighter
		var r := lerpf(6.0, 10.0, near)
		var pts := PackedVector2Array()
		for k in 10:
			var ang := -PI / 2.0 + TAU * k / 10.0 + _time * 3.0
			pts.append(pos + Vector2(cos(ang), sin(ang)) * (r if k % 2 == 0 else r * 0.45))
		var c := Color(1.0, 0.86, 0.25, lerpf(0.55, 1.0, near) * fade)
		draw_colored_polygon(pts, c)
		pts.append(pts[0])
		draw_polyline(pts, Color(0.35, 0.2, 0.0, 0.8 * fade), 1.2, true)


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
	var target := Vector2(_toe_point_for(j[J_FOOT_F]), _toe_point_for(j[J_FOOT_B]))
	_foot_point = _foot_point.lerp(target, 1.0 - exp(-FOOT_POINT_RATE * _last_delta))
	var rim := fighter.outline_color
	_shade = _kit == &"boxing" or _kit in OUTFIT_KITS
	_shoe = BOOT_COLOR if _kit == &"boxing" else Color.TRANSPARENT
	if _shade:
		# Characters are drawn with skin, the outfit carries the fighter's colours.
		var skin := SKIN_LIGHT if fighter.body_color.get_luminance() > 0.4 else SKIN_DARK
		_skin = skin
		if fighter.flash_frames > 0:
			skin = skin.lerp(Color.WHITE, 0.6)
		front = skin
		back = skin.darkened(0.18)
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
	if fighter.state == Fighter.State.FINISHER:
		# Finisher aura: the attacker glows in its accent colour.
		var aura := accent
		aura.a = 0.16
		_silhouette(j, forward, back_toe, 10.0, aura, aura)
		aura.a = 0.32
		_silhouette(j, forward, back_toe, 5.5, aura, aura)
	_silhouette(j, forward, back_toe, OUTLINE_WIDTH, rim, rim)
	_silhouette(j, forward, back_toe, 0.0, back, front)
	_shade = false
	_draw_kit(j, accent, forward)


## The body as solid shapes. `pad` grows every shape (outline / glow passes).
## Far-side limbs use `far`, everything else `near`.
func _silhouette(j: PackedVector2Array, forward: Vector2, back_toe: Vector2, pad: float, far: Color, near: Color) -> void:
	_far = true
	_leg(j[J_HIP_B], j[J_KNEE_B], j[J_FOOT_B], back_toe, pad, far, _heel_draw.y * _plant, _foot_point.y)
	_arm(j[J_SHOULDER_B], j[J_ELBOW_B], j[J_HAND_B], pad, far, _glove_color(false, pad))
	_far = false
	_torso(j, forward, pad, near)
	_head(j, forward, pad, near)
	_leg(j[J_HIP_F], j[J_KNEE_F], j[J_FOOT_F], forward, pad, near, _heel_draw.x * _plant, _foot_point.x)
	_arm(j[J_SHOULDER_F], j[J_ELBOW_F], j[J_HAND_F], pad, near, _glove_color(true, pad))


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


## Piecewise-linear half-width of a muscle profile at t.
static func _profile_width(profile: Array[Vector2], t: float) -> float:
	for i in range(1, profile.size()):
		if t <= profile[i].x:
			var a := profile[i - 1]
			var b := profile[i]
			return lerpf(a.y, b.y, (t - a.x) / maxf(b.x - a.x, 0.001))
	return profile[-1].y


## A limb segment shaped by its muscle profiles; `front` picks which side of
## the bone the front profile is drawn on. Rounded at both joints.
func _muscle(a: Vector2, b: Vector2, front: Vector2, front_profile: Array[Vector2], back_profile: Array[Vector2],
		pad: float, color: Color) -> void:
	var fill_pass := pad == 0.0
	pad += _grow
	var d := b - a
	if d.length_squared() < 0.01:
		draw_circle(a, front_profile[0].y + pad, color)
		return
	var n := Vector2(-d.y, d.x).normalized()
	if n.dot(front) < 0.0:
		n = -n
	var front_side := PackedVector2Array()
	var back_side := PackedVector2Array()
	for i in MUSCLE_SAMPLES + 1:
		var t := float(i) / MUSCLE_SAMPLES
		var c := a + d * t
		front_side.append(c + n * (_profile_width(front_profile, t) + pad))
		back_side.append(c - n * (_profile_width(back_profile, t) + pad))
	back_side.reverse()
	draw_colored_polygon(front_side + back_side, color)
	draw_circle(a, (front_profile[0].y + back_profile[0].y) * 0.5 + pad, color, true, -1.0, true)
	draw_circle(b, (front_profile[-1].y + back_profile[-1].y) * 0.5 + pad, color, true, -1.0, true)
	if _shade and fill_pass:
		_shade_limb(a, d, n, front_profile, back_profile, color)


## Cel shading for a limb: the back half in shadow, a soft highlight just
## inside the front edge (light from the front and above).
func _shade_limb(a: Vector2, d: Vector2, n: Vector2, front_profile: Array[Vector2], back_profile: Array[Vector2],
		color: Color) -> void:
	var mid := PackedVector2Array()
	var back_side := PackedVector2Array()
	var hi := PackedVector2Array()
	for i in MUSCLE_SAMPLES + 1:
		var t := float(i) / MUSCLE_SAMPLES
		var c := a + d * t
		var bw := _profile_width(back_profile, t)
		mid.append(c - n * bw * 0.15)
		back_side.append(c - n * (bw - 0.6))
		if t > 0.12 and t < 0.88:
			hi.append(c + n * (_profile_width(front_profile, t) * 0.55))
	back_side.reverse()
	draw_colored_polygon(mid + back_side, color.darkened(SHADE_DARKEN))
	if hi.size() > 1:
		var h := color.lightened(0.35)
		h.a = HIGHLIGHT_ALPHA
		draw_polyline(hi, h, 2.2, true)


## Outside of a joint's bend (where the kneecap / elbow point is); `fallback`
## when the limb is nearly straight.
static func _bend_out(upper: Vector2, joint: Vector2, lower: Vector2, fallback: Vector2) -> Vector2:
	var inner := (upper - joint).normalized() + (lower - joint).normalized()
	if inner.length() < 0.25:
		return fallback
	return -inner.normalized()


## How far a lifted foot points its toes for the current technique (0 on the floor).
func _toe_point_for(foot: Vector2) -> float:
	if _rag_on or fighter.ground_y - foot.y < FOOT_LIFTED:
		return 0.0
	if fighter.state == Fighter.State.ATTACK and fighter.current_attack != null:
		match fighter.current_attack.type:
			CombatData.AttackType.HIGH_KICK, CombatData.AttackType.BODY_ROUNDHOUSE, CombatData.AttackType.LOW_ROUNDHOUSE, \
					CombatData.AttackType.JUMP_ROUNDHOUSE, CombatData.AttackType.TORNADO_540, CombatData.AttackType.KNEE, \
					CombatData.AttackType.FLYING_KNEE, CombatData.AttackType.JUMP_KICK:
				return POINT_ROUNDHOUSE
			CombatData.AttackType.FRONT_KICK:
				return POINT_BALL
			CombatData.AttackType.KICK, CombatData.AttackType.BACK_KICK, CombatData.AttackType.AXE_KICK, \
					CombatData.AttackType.SPIN_HOOK_KICK, CombatData.AttackType.LOW_SIDE_KICK, CombatData.AttackType.SWEEP, \
					CombatData.AttackType.SPIN_COUNTER_KICK, CombatData.AttackType.JUMP_SPIN_KICK:
				return 0.0
	if fighter.state == Fighter.State.FINISHER:
		var pose := String(fighter.script_pose)
		if pose in ["front_extend"]:
			return POINT_BALL
		if pose in ["kick_strike", "back_extend", "axe_chop", "axe_raise", "shook_hit", "lowside_hit", "sweep_extend"]:
			return 0.0
		return POINT_ROUNDHOUSE if pose.ends_with("extend") or pose.contains("rh") or pose.contains("knee") \
			or pose.contains("tornado") or pose == "spin_kick" else POINT_RELAXED
	return POINT_RELAXED


func _leg(hip: Vector2, knee: Vector2, ankle: Vector2, toe_dir: Vector2, pad: float, color: Color, heel_lift: float = 0.0,
		point: float = 0.0) -> void:
	# The kneecap faces the outside of the bend (the toes' way when straight).
	var out := _bend_out(hip, knee, ankle, toe_dir)
	_grow = _pb(P_THIGH)
	_muscle(hip, knee, out, THIGH_FRONT, THIGH_BACK, pad, _pc(P_THIGH, color, pad))
	_grow = _pb(P_SHIN)
	_muscle(knee, ankle, out, SHIN_FRONT, SHIN_BACK, pad, _pc(P_SHIN, color, pad))
	_grow = 0.0
	draw_circle(knee + out * 2.5, 5.0 + pad + _pb(P_SHIN), _pc(P_SHIN, color, pad), true, -1.0, true)  # kneecap
	if pad == 0.0 and _kit in OUTFIT_KITS:
		_leg_extras(hip, knee, ankle)
	# Shoe: square to the shin, toes toward toe_dir, rolled toward pointing
	# along the shin for a pointed (lifted) foot.
	var shin := (ankle - knee).normalized()
	var toe := Vector2(-shin.y, shin.x)
	if toe.dot(toe_dir) < 0.0:
		toe = -toe
	if point > 0.01:
		toe = toe.slerp(shin, clampf(point, 0.0, 1.0) * 0.85)
	var sole := ankle + shin * 2.5
	if heel_lift > 0.05:
		# Heel raised: tilt the shoe so the toes stay down on the floor.
		var tip := sole + Vector2(toe.x * 13.0, heel_lift)
		toe = (tip - sole).normalized()
	if _shoe.a > 0.0 and pad == 0.0:
		# Boxing boots: high-top in white with a dark sole.
		_capsule(knee.lerp(ankle, 0.55), ankle, 6.0, 5.2, _shoe.darkened(0.08 if color.get_luminance() < 0.45 else 0.0))
		_capsule(sole - toe * 3.5, sole + toe * 13.0, 4.8, 3.6, _shoe)
		_capsule(sole - toe * 3.0 + shin * 3.2, sole + toe * 12.5 + shin * 3.2, 1.6, 1.4, SOLE_COLOR)
	else:
		_capsule(sole - toe * 3.5, sole + toe * 13.0, 4.8 + pad, 3.6 + pad, _pc(P_FOOT, color, pad))
		if pad == 0.0 and _kit == &"bangla_maar":
			# Rubber sandal: a thin sole and the toe strap.
			_capsule(sole - toe * 3.0 + shin * 3.4, sole + toe * 13.0 + shin * 3.4, 1.8, 1.6, _ccol("sandal"))
			draw_line(sole + toe * 4.0 + shin * 2.0, sole + toe * 7.0 - shin * 1.5, _ccol("sandal"), 2.0, true)
		if pad == 0.0 and _kit == &"kung_fu":
			# Cloth shoes: a white sole under the black slipper.
			_capsule(sole - toe * 3.0 + shin * 3.2, sole + toe * 12.5 + shin * 3.2, 1.6, 1.4, GI_WHITE.darkened(0.15 if _far else 0.0))


## Boxing glove fill (only on the body fill pass; outlines and glows keep
## their colour). Transparent = draw the hand in the body colour.
func _glove_color(near: bool, pad: float) -> Color:
	if not _kit in GLOVED_KITS or pad != 0.0:
		return Color.TRANSPARENT
	var c := fighter.accent_color
	return c if near else c.darkened(0.25)


func _arm(shoulder: Vector2, elbow: Vector2, hand: Vector2, pad: float, color: Color,
		glove: Color = Color.TRANSPARENT) -> void:
	# Biceps on the inside of the bend, forearm swelling below the elbow and
	# tapering to the wrist.
	var inside := -_bend_out(shoulder, elbow, hand, Vector2.UP)
	_grow = _pb(P_UPPER_ARM)
	_muscle(shoulder, elbow, inside, UPPER_ARM_FRONT, UPPER_ARM_BACK, pad, _pc(P_UPPER_ARM, color, pad))
	_grow = _pb(P_FOREARM)
	_muscle(elbow, hand, inside, FOREARM_FRONT, FOREARM_BACK, pad, _pc(P_FOREARM, color, pad))
	_grow = 0.0
	if pad == 0.0 and _kit in OUTFIT_KITS:
		_arm_extras(shoulder, elbow, hand)
	# Glove: longer than wide along the forearm, so the knuckles visibly lead
	# a punch (a round ball reads as a hammer fist).
	var along := (hand - elbow).normalized() if hand.distance_squared_to(elbow) > 1.0 else Vector2.RIGHT
	var g := GLOVE_SCALE if _kit in GLOVED_KITS else 1.0
	var fill := glove if glove.a > 0.0 else color
	if glove.a > 0.0:
		# Boxing glove cuff at the wrist.
		var across := Vector2(-along.y, along.x)
		var wrist := hand - along * 8.5
		draw_line(wrist - across * 6.5, wrist + across * 6.5, Color(0.95, 0.94, 0.9), 4.0, true)
	if _kit == &"bangla_maar":
		_open_hand(hand, along, inside.normalized(), pad, fill)
		return
	_capsule(hand - along * 1.5 * g, hand + along * 5.5 * g, 7.0 * g + pad, 8.0 * g + pad, fill)
	draw_circle(hand - along * 2.0 * g + inside.normalized() * 4.5 * g, 3.6 * g + pad, fill, true, -1.0, true)  # thumb
	if glove.a > 0.0:
		# Glove shading: a darker palm side and a shine on the knuckles.
		var side := -inside.normalized()
		draw_circle(hand + along * 2.0 * g - side * 3.5, 5.0 * g, fill.darkened(0.25), true, -1.0, true)
		draw_circle(hand + along * 3.0 * g + side * 3.0, 3.2, Color(1.0, 1.0, 1.0, 0.45), true, -1.0, true)


## Open hand (slaps, shoves, pointing): a palm, four short fingers fanned a
## little apart and the thumb off the side. Drawn in every silhouette pass, so
## the outline follows the fingers.
func _open_hand(wrist: Vector2, along: Vector2, side: Vector2, pad: float, fill: Color) -> void:
	var across := Vector2(-along.y, along.x)
	var palm_end := wrist + along * 6.5
	_capsule(wrist - along * 1.0, palm_end, 4.6 + pad, 5.2 + pad, fill)
	for k in 4:
		var off := (k - 1.5) * 2.4
		var base := palm_end + across * off
		var tip := base + (along + across * off * 0.04).normalized() * (6.8 - absf(k - 1.5) * 0.9)
		_capsule(base, tip, 1.6 + pad, 1.4 + pad, fill)
	_capsule(wrist + side * 3.0 + along * 1.5, wrist + side * 5.5 + along * 6.0, 1.9 + pad, 1.6 + pad, fill)  # thumb
	if pad == 0.0:
		for k in 3:  # the gaps between the fingers
			var gap := palm_end + across * (k - 1.0) * 2.4
			draw_line(gap - along * 0.5, gap + along * 4.0, fill.darkened(0.3), 0.8, true)


## Side-profile torso: hips, narrower waist, chest out in front, shoulders.
func _torso(j: PackedVector2Array, forward: Vector2, pad: float, skin_color: Color) -> void:
	var hip := j[J_HIP]
	var neck := j[J_NECK]
	var axis := neck - hip
	var length := axis.length()
	if length < 0.01:
		return
	# The neck is skin; the torso may be clothed (gi, dobok, silk jacket).
	var color := _pc(P_TORSO, skin_color, pad)
	var fill_pass := pad == 0.0
	pad += _pb(P_TORSO)
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
	if _kit == &"bangla_maar":
		draw_circle(hip + axis * length * 0.36 + n * 8.0, 11.5 + pad, color, true, -1.0, true)  # belly
	draw_circle(j[J_SHOULDER_F], 8.5 + pad, color, true, -1.0, true)  # deltoids
	draw_circle(j[J_SHOULDER_B], 8.5 + pad, color, true, -1.0, true)
	_capsule(j[J_HIP_F], j[J_HIP_B], 10.0 + pad, 10.0 + pad, color)  # pelvis
	_capsule(neck, neck + axis * 8.0, 5.0 + pad - _pb(P_TORSO), 4.5 + pad - _pb(P_TORSO), skin_color)  # neck
	if _shade and fill_pass:
		# Back of the torso in shadow, a pec / ab highlight on the chest.
		var shadow := PackedVector2Array()
		var spine := PackedVector2Array()
		for row in TORSO_PROFILE:
			var c := hip + axis * length * row.x
			shadow.append(c - n * (row.z - 0.6))
			spine.append(c - n * row.z * 0.1)
		spine.reverse()
		draw_colored_polygon(shadow + spine, color.darkened(SHADE_DARKEN))
		var h := color.lightened(0.35)
		h.a = HIGHLIGHT_ALPHA
		draw_arc(hip + axis * length * 0.72 + n * 5.0, 7.0, -PI * 0.6, PI * 0.6, 8, h, 2.0, true)
	if fill_pass and _kit in OUTFIT_KITS:
		_torso_extras(j, hip, axis, length, n)


## Head with a jaw / chin profile toward the front.
func _head(j: PackedVector2Array, forward: Vector2, pad: float, color: Color) -> void:
	var head := j[J_HEAD]
	var up := (head - j[J_NECK]).normalized()
	draw_circle(head, HEAD_R + pad, color, true, -1.0, true)
	draw_circle(head + forward * 4.5 - up * 5.5, 8.5 + pad, color, true, -1.0, true)
	if pad == 0.0 and _kit in OUTFIT_KITS:
		_head_extras(head, up, forward)


## Belt with a hanging knot, headband with trailing tails, wrist wraps.
func _draw_kit(j: PackedVector2Array, accent: Color, forward: Vector2) -> void:
	if _kit == &"boxing":
		_draw_boxing_kit(j, accent)
		return
	if _kit in OUTFIT_KITS:
		return  # drawn with the body (_leg / _arm / _torso / _head extras)
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
	# Wrist wraps: bands across the forearm (round dots read as joint markers).
	for pair in [[J_ELBOW_F, J_HAND_F], [J_ELBOW_B, J_HAND_B]]:
		var e: Vector2 = j[pair[0]]
		var h: Vector2 = j[pair[1]]
		if e.distance_squared_to(h) < 1.0:
			continue
		var along := (h - e).normalized()
		var across := Vector2(-along.y, along.x)
		for k in 2:
			var c := e.lerp(h, 0.7 + k * 0.1)
			var half := _profile_width(FOREARM_FRONT, 0.7 + k * 0.1) + 0.6
			draw_line(c - across * half, c + across * half, accent.darkened(0.15), 3.2, true)


## Outfit colours for this fighter's style (light fighters get the light
## version: a white gi, a light-skinned character).
func _build_outfit() -> void:
	_outfit = {}
	_cols = {}
	if not _kit in OUTFIT_KITS:
		return
	var light := fighter.body_color.get_luminance() > 0.4
	var acc := fighter.accent_color
	var gi := GI_WHITE if light else GI_BLACK
	_cols["hair"] = Color(0.2, 0.13, 0.09) if light else Color(0.07, 0.06, 0.06)
	match _kit:
		&"karate", &"taekwondo":
			_cloth([P_TORSO], gi, 1.5)
			_cloth([P_UPPER_ARM, P_FOREARM, P_THIGH, P_SHIN], gi, 2.5)
			_cols["gi"] = gi
			_cols["belt"] = Color(0.07, 0.07, 0.08)  # a black belt, on a white or a black gi
			_cols["belt_edge"] = gi.darkened(0.35) if light else Color(0.42, 0.42, 0.46)
			_cols["lapel"] = gi.darkened(0.3) if _kit == &"karate" else (Color(0.07, 0.07, 0.08) if light else acc)
		&"kung_fu":
			var silk := acc.darkened(0.45)
			_cloth([P_TORSO], silk, 1.5)
			_cloth([P_UPPER_ARM, P_FOREARM], silk, 3.0)
			_cloth([P_THIGH, P_SHIN], Color(0.1, 0.1, 0.12), 3.0)
			_cloth([P_FOOT], Color(0.07, 0.07, 0.08), 0.0)
			_cols["silk"] = silk
			_cols["pants"] = Color(0.1, 0.1, 0.12)
			_cols["sash"] = acc.lightened(0.05)
			_cols["cuff"] = GI_WHITE
			_cols["frog"] = Color(0.96, 0.9, 0.72)
		&"muay_thai":
			_cols["shorts"] = acc
			_cols["trim"] = GI_WHITE
			_cols["support"] = Color(0.92, 0.91, 0.87)
			_cols["mongkol"] = GI_WHITE
		&"bangla_maar":
			# Sando genji vest, checked lungi folded up to the knee, a gamchha over
			# the shoulder, rubber sandals.
			var vest := Color(0.97, 0.96, 0.92)
			_cloth([P_TORSO], vest, 1.0)
			_cols["vest"] = vest
			_cols["lungi"] = acc.darkened(0.25)
			_cols["check"] = acc.lightened(0.35)
			_cols["gamchha"] = Color(0.82, 0.16, 0.13)
			_cols["sandal"] = acc.darkened(0.1)
		&"kickboxing":
			var pants := acc.darkened(0.15)
			_cloth([P_THIGH, P_SHIN], pants, 3.0)
			_cols["pants"] = pants
			_cols["trim"] = GI_WHITE
			_cols["tape"] = Color(0.92, 0.91, 0.87)


func _cloth(parts: Array, color: Color, bulk: float) -> void:
	for p in parts:
		_outfit[p] = [color, color.darkened(CLOTH_FAR_DARKEN), bulk]


## Fill colour of a body part: its cloth (near / far, flashing on a hit) or,
## for bare skin and for outline / glow passes, the colour passed in.
func _pc(part: int, color: Color, pad: float) -> Color:
	if pad != 0.0 or not _outfit.has(part):
		return color
	var c: Color = _outfit[part][1 if _far else 0]
	if fighter.flash_frames > 0:
		c = c.lerp(Color.WHITE, 0.6)
	return c


## Extra thickness of a clothed part (loose sleeves and trousers).
func _pb(part: int) -> float:
	return _outfit[part][2] if _outfit.has(part) else 0.0


func _ccol(role: String) -> Color:
	var c: Color = _cols.get(role, Color.MAGENTA)
	return c.darkened(CLOTH_FAR_DARKEN) if _far else c


static func _across(a: Vector2, b: Vector2) -> Vector2:
	var d := b - a
	return Vector2(-d.y, d.x).normalized() if d.length_squared() > 0.01 else Vector2.RIGHT


## Shorts, jacket skirts, ankle supports, trouser hems: per leg, in the body
## pass (so the far leg's stay behind the body).
func _leg_extras(hip: Vector2, knee: Vector2, ankle: Vector2) -> void:
	match _kit:
		&"muay_thai":
			# Wide, short satin Thai shorts with a contrasting hem; ankle supports.
			var hem := hip.lerp(knee, 0.45)
			_capsule(hip, hem, 13.5, 13.0, _ccol("shorts"))
			_limb_band(hip, knee, 0.45, 12.6, _ccol("trim"), 3.0)
			_capsule(knee.lerp(ankle, 0.72), ankle, 6.6, 6.0, _ccol("support"))
			_limb_band(knee, ankle, 0.74, 6.2, _ccol("support").darkened(0.15), 1.2)
		&"karate", &"taekwondo":
			# The jacket skirt over the top of the thigh; trouser hem at the ankle.
			var skirt := hip.lerp(knee, 0.3)
			_capsule(hip, skirt, 13.5, 13.0, _ccol("gi"))
			_limb_band(hip, knee, 0.3, 12.6, _ccol("gi").darkened(0.18), 1.4)
			_limb_band(knee, ankle, 0.93, _profile_width(SHIN_FRONT, 0.93) + _pb(P_SHIN), _ccol("gi").darkened(0.22), 1.6)
			if not _far:
				_draw_belt()
		&"kung_fu":
			# Loose trousers gathered at the ankle.
			_limb_band(knee, ankle, 0.88, _profile_width(SHIN_FRONT, 0.88) + _pb(P_SHIN) - 0.5, _ccol("pants").lightened(0.15), 3.0)
		&"bangla_maar":
			# Lungi folded up to the knee: a checked tube over the thigh.
			var fold := hip.lerp(knee, 0.9)
			_capsule(hip, fold, 14.0, 12.5, _ccol("lungi"))
			for k in 3:
				_limb_band(hip, fold, 0.25 + k * 0.28, 13.2 - k * 0.5, _ccol("check"), 1.5)
			_ribbon(hip, fold, 1.6, 1.6, _ccol("check"))
			_limb_band(hip, fold, 0.98, 12.4, _ccol("lungi").darkened(0.25), 3.0)
		&"kickboxing":
			# Satin trousers with a side stripe, flared over taped ankles.
			_ribbon(hip.lerp(knee, 0.1), knee, 2.2, 2.0, _ccol("trim"))
			_ribbon(knee, knee.lerp(ankle, 0.85), 2.0, 1.8, _ccol("trim"))
			_limb_band(knee, ankle, 0.9, _profile_width(SHIN_FRONT, 0.9) + _pb(P_SHIN), _ccol("pants").darkened(0.2), 2.0)
			_limb_band(knee, ankle, 0.97, 5.0, _ccol("tape"), 3.0)


## A black belt wrapped round the waist (following the jacket's contour, edged
## so it reads on a black gi too), a knot at the front and two tapered tails.
func _draw_belt() -> void:
	if _belt_at.is_empty():
		return
	var hip: Vector2 = _belt_at[0]
	var axis: Vector2 = _belt_at[1]
	var length: float = _belt_at[2]
	var n: Vector2 = _belt_at[3]
	var sway: float = _belt_at[4]
	_waist_band(hip, axis, length, n, 4.0, 12.0, _cols["belt"], _cols["belt_edge"])
	var edge := _torso_edge(8.0 / length)
	var knot := hip + axis * 8.0 + n * (edge.x + _pb(P_TORSO) + 1.0)
	_capsule(knot - axis * 2.5, knot + axis * 2.5, 4.4, 4.4, _cols["belt_edge"])
	_capsule(knot - axis * 2.0, knot + axis * 2.0, 3.4, 3.4, _cols["belt"])
	for tail in [Vector2(n.x * 2.5, 17.0 + sway), Vector2(n.x * 6.5, 14.0 - sway)]:
		_ribbon(knot, knot + tail, 5.6, 4.2, _cols["belt_edge"])
		_ribbon(knot, knot + tail, 4.2, 2.8, _cols["belt"])


## A band round the waist that follows the torso's own contour (front and back
## edges from TORSO_PROFILE), bowing down a little round the side like a real
## belt. from / to: px above the hip.
func _waist_band(hip: Vector2, axis: Vector2, length: float, n: Vector2, from: float, to: float, color: Color,
		edge_color: Color = Color.TRANSPARENT) -> void:
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var grow := _pb(P_TORSO) + 0.6
	for i in 7:
		var u := float(i) / 6.0
		var sag := sin(PI * u) * 1.6
		top.append(_band_point(hip, axis, length, n, to, sag, grow, u))
		bottom.append(_band_point(hip, axis, length, n, from, sag, grow, u))
	var band := top.duplicate()
	var rev := bottom.duplicate()
	rev.reverse()
	band.append_array(rev)
	draw_colored_polygon(band, color)
	if edge_color.a > 0.0:
		draw_polyline(top, edge_color, 1.4, true)
		draw_polyline(bottom, edge_color, 1.4, true)


## A point across the torso at height h (u: 0 front edge .. 1 back edge).
func _band_point(hip: Vector2, axis: Vector2, length: float, n: Vector2, h: float, sag: float, grow: float, u: float) -> Vector2:
	var e := _torso_edge(h / length)
	return hip + axis * (h - sag) + n * lerpf(e.x + grow, -(e.y + grow), u)


## Front / back half-widths of the torso at t (0 hip .. 1 neck).
func _torso_edge(t: float) -> Vector2:
	for i in range(1, TORSO_PROFILE.size()):
		var a := TORSO_PROFILE[i - 1]
		var b := TORSO_PROFILE[i]
		if t <= b.x:
			var k := clampf((t - a.x) / maxf(b.x - a.x, 0.001), 0.0, 1.0)
			return Vector2(lerpf(a.y, b.y, k), lerpf(a.z, b.z, k))
	return Vector2(TORSO_PROFILE[-1].y, TORSO_PROFILE[-1].z)


## A hem / cuff / band wrapped round a limb at t along a -> b: exactly as wide
## as the limb there (`half`), bowed a little along the limb so it reads as
## going round it, with rounded ends.
func _limb_band(a: Vector2, b: Vector2, t: float, half: float, color: Color, width: float) -> void:
	var d := b - a
	if d.length_squared() < 0.01:
		return
	var along := d.normalized()
	var across := Vector2(-along.y, along.x)
	var c := a.lerp(b, t)
	var pts := PackedVector2Array()
	for i in 5:
		var u := float(i) / 4.0 * 2.0 - 1.0
		pts.append(c + across * half * u + along * (1.0 - u * u) * 1.8)
	draw_polyline(pts, color, width, true)
	draw_circle(pts[0], width * 0.5, color, true, -1.0, true)
	draw_circle(pts[4], width * 0.5, color, true, -1.0, true)


## A tapered strip with rounded ends (lapels, collars, belt tails, ribbons).
func _ribbon(p0: Vector2, p1: Vector2, w0: float, w1: float, color: Color) -> void:
	_capsule(p0, p1, w0 * 0.5, w1 * 0.5, color)


## Armbands, sleeve hems, silk cuffs: per arm, before the hand is drawn.
func _arm_extras(shoulder: Vector2, elbow: Vector2, hand: Vector2) -> void:
	match _kit:
		&"muay_thai":
			# Prajioud: a cloth band tied round the upper arm, a short tail.
			var half := _profile_width(UPPER_ARM_FRONT, 0.45) + 0.8
			_limb_band(shoulder, elbow, 0.45, half, _ccol("shorts"), 4.5)
			var p := shoulder.lerp(elbow, 0.45) + _across(shoulder, elbow) * half
			_ribbon(p, p + (elbow - shoulder).normalized() * 9.0 + _across(shoulder, elbow) * 2.0, 3.0, 1.8, _ccol("shorts"))
		&"karate", &"taekwondo":
			_limb_band(elbow, hand, 0.86, _profile_width(FOREARM_FRONT, 0.86) + _pb(P_FOREARM), _ccol("gi").darkened(0.22), 1.6)
		&"kung_fu":
			# Turned-back white cuffs on the silk sleeves.
			_capsule(elbow.lerp(hand, 0.74), elbow.lerp(hand, 0.95), 8.5, 9.0, _ccol("cuff"))
			_limb_band(elbow, hand, 0.74, 8.3, _ccol("cuff").darkened(0.18), 1.2)


## Lapels, belts, sashes, collars, frog buttons, waistbands.
func _torso_extras(j: PackedVector2Array, hip: Vector2, axis: Vector2, length: float, n: Vector2) -> void:
	var neck_base := hip + axis * length * 0.86
	var sway := sin(_time * 6.0) * 1.5
	var grow := _pb(P_TORSO)
	match _kit:
		&"karate", &"taekwondo":
			# Crossed jacket front: two tapering lapels meeting at the belt (the
			# dobok's is a black V collar). The belt is drawn over the near leg
			# (_draw_belt), so the jacket skirt never hides it.
			var wide := 3.2 if _kit == &"karate" else 6.0
			var low := hip + axis * length * 0.3 + n * (_torso_edge(0.3).x + grow - 1.0)
			_ribbon(neck_base + n * 4.0, low, wide, wide * 0.4, _cols["lapel"])
			_ribbon(neck_base - n * 2.0, hip + axis * length * 0.5 + n * (_torso_edge(0.5).x + grow - 3.0), wide * 0.8, wide * 0.3, _cols["lapel"])
			_belt_at = [hip, axis, length, n, sway]
		&"kung_fu":
			# Mandarin collar, frog buttons down the front, a wide sash tied at the back.
			_ribbon(neck_base - n * 4.0, neck_base + n * 6.0, 5.0, 5.0, _cols["silk"].darkened(0.35))
			for k in 3:
				var t := 0.5 + k * 0.12
				var at := hip + axis * length * t + n * (_torso_edge(t).x + grow - 3.5)
				_ribbon(at - n * 3.0, at + n * 3.0, 2.4, 2.4, _cols["frog"])
				draw_circle(at + n * 3.0, 1.5, _cols["frog"].darkened(0.3), true, -1.0, true)
			_waist_band(hip, axis, length, n, 3.0, 13.0, _cols["sash"], _cols["sash"].darkened(0.25))
			var tie := hip + axis * 8.0 - n * (_torso_edge(0.12).y + grow)
			_ribbon(tie, tie + Vector2(-n.x * 4.0, 22.0 + sway), 5.0, 3.0, _cols["sash"])
			_ribbon(tie, tie + Vector2(-n.x * 9.0, 18.0 - sway), 4.4, 2.6, _cols["sash"].darkened(0.15))
		&"muay_thai":
			# Shorts over the pelvis with a wide contrasting waistband.
			_capsule(j[J_HIP_F], j[J_HIP_B], 12.5, 12.5, _cols["shorts"])
			_waist_band(hip, axis, length, n, 5.0, 12.5, _cols["trim"])
			for k in 3:
				var at := hip + axis * 9.0 + n * (-5.0 + k * 5.0)
				_ribbon(at - axis * 1.2, at + axis * 1.2, 2.0, 2.0, _cols["shorts"].darkened(0.3))
		&"bangla_maar":
			# Vest neckline, the lungi round the waist with its tucked knot, and a
			# gamchha thrown over the near shoulder.
			draw_circle(neck_base + n * 4.0 - axis * 2.0, 6.0, _skin, true, -1.0, true)
			_capsule(j[J_HIP_F], j[J_HIP_B], 13.0, 13.0, _cols["lungi"])
			_waist_band(hip, axis, length, n, 6.0, 14.0, _cols["lungi"].darkened(0.2))
			draw_circle(hip + axis * 10.0 + n * (_torso_edge(0.15).x + grow + 1.5), 5.0, _cols["lungi"].darkened(0.1), true, -1.0, true)
			var towel := [neck_base + n * 5.0, j[J_SHOULDER_F] + axis * 4.0, neck_base - n * 9.0,
				hip + axis * length * 0.42 - n * 12.0]
			for k in 3:
				_ribbon(towel[k], towel[k + 1], 6.5, 6.0 if k < 2 else 5.0, _cols["gamchha"])
			_ribbon(towel[2], towel[3], 1.5, 1.2, Color(0.97, 0.95, 0.9))
		&"kickboxing":
			_capsule(j[J_HIP_F], j[J_HIP_B], 12.5, 12.5, _cols["pants"])
			_waist_band(hip, axis, length, n, 5.0, 12.0, _cols["pants"].lightened(0.3))


## Hair and headwear (the Muay Thai mongkol).
func _head_extras(head: Vector2, up: Vector2, face: Vector2) -> void:
	var cap := PackedVector2Array()
	for dir in [up.slerp(face, 0.4), up.slerp(face, 0.15), up, up.slerp(-face, 0.5), -face, (-face).slerp(-up, 0.3)]:
		cap.append(head + (dir as Vector2).normalized() * (HEAD_R - 2.0))
	draw_polyline(cap, _cols["hair"], 6.0 if _kit != &"muay_thai" else 4.0, true)
	draw_circle(cap[0], 3.0 if _kit != &"muay_thai" else 2.0, _cols["hair"], true, -1.0, true)
	draw_circle(cap[-1], 3.0 if _kit != &"muay_thai" else 2.0, _cols["hair"], true, -1.0, true)
	if _kit == &"kung_fu":
		draw_circle(head + up * (HEAD_R + 1.5) - face * 5.0, 5.0, _cols["hair"], true, -1.0, true)  # topknot
	elif _kit == &"bangla_maar":
		# A thick moustache and an untidy tuft of hair.
		_ribbon(head + face * HEAD_R * 0.45 - up * 4.5, head + face * HEAD_R * 1.05 - up * 3.5, 3.8, 2.4, _cols["hair"])
		_ribbon(head + up * (HEAD_R - 1.0), head + up * (HEAD_R + 4.0) + face * 3.0, 3.2, 1.6, _cols["hair"])
	elif _kit == &"muay_thai":
		# Mongkol: a stiff rope ring round the head with a tail at the back.
		var front := head + face * HEAD_R * 0.9 + up * 5.0
		var back := head - face * HEAD_R * 0.95 + up * 6.0
		_ribbon(front, back, 5.2, 5.2, _cols["mongkol"])
		for k in 4:
			var at := front.lerp(back, 0.15 + k * 0.23)
			_ribbon(at - up * 2.0, at + up * 2.0 + face * 1.5, 1.6, 1.6, _cols["shorts"] if _cols.has("shorts") else Color.RED)
		_ribbon(back, back - face * 12.0 + up * 3.0, 3.8, 2.4, _cols["mongkol"])


## Boxer: trunks with a waistband and boot cuffs (no belt or headband); the
## gloves are coloured in _arm.
func _draw_boxing_kit(j: PackedVector2Array, accent: Color) -> void:
	var hip := j[J_HIP]
	var axis := (j[J_NECK] - hip).normalized()
	var n := Vector2(-axis.y, axis.x)
	var trunks := accent.darkened(0.1)
	var trim := accent.lightened(0.45)
	var forward := Vector2(signf(j[J_HAND_F].x - j[J_SHOULDER_F].x + 0.001), 0.0)
	var nf := n if n.dot(forward) >= 0.0 else -n
	# Tank top in the fighter's base colour, over the chest and stomach.
	var top_col := Color(0.88, 0.88, 0.86) if fighter.body_color.get_luminance() > 0.4 else Color(0.16, 0.15, 0.17)
	var length := (j[J_NECK] - hip).length()
	var front_side := PackedVector2Array()
	var back_side := PackedVector2Array()
	for row in TORSO_PROFILE:
		if row.x < 0.12 or row.x > 0.86:
			continue
		var c := hip + axis * length * row.x
		front_side.append(c + nf * (row.y + 0.6))
		back_side.append(c - nf * (row.z + 0.6))
	back_side.reverse()
	draw_colored_polygon(front_side + back_side, top_col)
	var spine := PackedVector2Array()
	var back_edge := PackedVector2Array()
	for row in TORSO_PROFILE:
		if row.x < 0.12 or row.x > 0.86:
			continue
		var c := hip + axis * length * row.x
		back_edge.append(c - nf * (row.z + 0.6))
		spine.append(c - nf * row.z * 0.1)
	spine.reverse()
	draw_colored_polygon(back_edge + spine, top_col.darkened(SHADE_DARKEN))
	# Straps over the shoulders.
	var neck_base := hip + axis * length * 0.86
	draw_line(neck_base + nf * 4.0, j[J_SHOULDER_F] + axis * 2.0, top_col, 5.0, true)
	draw_line(neck_base - nf * 3.0, j[J_SHOULDER_B] + axis * 2.0, top_col.darkened(SHADE_DARKEN), 5.0, true)
	# Trunks: over the pelvis and the top of both thighs.
	for leg in [[J_HIP_B, J_KNEE_B, trunks.darkened(0.3)], [J_HIP_F, J_KNEE_F, trunks]]:
		var top: Vector2 = j[leg[0]]
		var hem: Vector2 = top.lerp(j[leg[1]], 0.5)
		_capsule(top, hem, 11.2, 9.6, leg[2])
	_capsule(j[J_HIP_F], j[J_HIP_B], 11.0, 11.0, trunks)
	# Shade on the back of the trunks, a stripe down the near leg.
	var back_leg_top: Vector2 = j[J_HIP_F]
	var hem_f: Vector2 = back_leg_top.lerp(j[J_KNEE_F], 0.5)
	var leg_dir := (hem_f - back_leg_top).normalized()
	var leg_n := Vector2(-leg_dir.y, leg_dir.x)
	if leg_n.dot(nf) < 0.0:
		leg_n = -leg_n
	draw_line(back_leg_top - leg_n * 6.0, hem_f - leg_n * 5.0, trunks.darkened(SHADE_DARKEN), 6.0, true)
	draw_line(back_leg_top + leg_n * 9.0 + leg_dir * 2.0, hem_f + leg_n * 7.5, trim, 2.5, true)
	var band := hip + axis * 9.0
	draw_line(band - n * 12.5, band + n * 12.5, trim, 4.0, true)
	# Sock tops above the boots.
	for leg in [[J_KNEE_B, J_FOOT_B], [J_KNEE_F, J_FOOT_F]]:
		var knee: Vector2 = j[leg[0]]
		var ankle: Vector2 = j[leg[1]]
		var cuff := knee.lerp(ankle, 0.55)
		var dir := (ankle - knee).normalized()
		var across := Vector2(-dir.y, dir.x)
		draw_line(cuff - across * 6.2, cuff + across * 6.2, trim, 2.5, true)
	# Headgear: padded cap with a brow bar and cheek pad, in the outfit colour.
	var head := j[J_HEAD]
	var up := (head - j[J_NECK]).normalized()
	var face := nf
	var gear := accent.darkened(0.05)
	# Crown and back of the head covered; the face stays open.
	var cap := PackedVector2Array()
	for dir in [up.slerp(face, 0.45), up.slerp(face, 0.2), up, up.slerp(-face, 0.5), -face, (-face).slerp(-up, 0.35)]:
		cap.append(head + (dir as Vector2).normalized() * (HEAD_R - 1.5))
	draw_polyline(cap, gear, 6.5, true)
	draw_circle(head - face * 7.0 - up * 1.0, 5.0, gear.darkened(0.15), true, -1.0, true)  # ear pad
	draw_line(head - face * 5.0 - up * 5.0, head + face * 4.0 - up * 11.0, gear.darkened(0.3), 1.8, true)  # chin strap
	# Gloves are coloured in the body pass (_arm), so the far glove stays
	# behind the head and torso.


## States where the feet are planted on the floor (legs solved by IK).
func _wants_plant() -> bool:
	if fighter.airborne or _rag_on or _rag_blend > 0.0 or _tuck_amount > 0.0:
		return false
	if absf(_spin_angle) > 0.01 or fighter.script_flip:
		return false
	if fighter.prefight_pose in ONE_LEG_POSES:
		return false
	if fighter.state == Fighter.State.ATTACK:
		# Hand strikes keep the feet planted, so the hips drive over them and a
		# step-in steps front foot then rear (kicks own their legs).
		var attack := fighter.current_attack
		return attack != null and not attack.spin and attack.sequence.is_empty() 			and _mech_kind(attack.type) in [MECH_LEAD, MECH_REAR, MECH_RISING]
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
				CombatData.AttackType.SWEEP, CombatData.AttackType.HIGH_KICK, CombatData.AttackType.AXE_KICK, \
				CombatData.AttackType.JUMP_ROUNDHOUSE, CombatData.AttackType.LOW_ROUNDHOUSE, \
				CombatData.AttackType.BODY_ROUNDHOUSE, CombatData.AttackType.LOW_SIDE_KICK:
			return J_FOOT_F
		CombatData.AttackType.KNEE, CombatData.AttackType.FLYING_KNEE:
			return J_KNEE_F
		CombatData.AttackType.ELBOW, CombatData.AttackType.RISING_ELBOW, CombatData.AttackType.JUMPING_ELBOW, \
				CombatData.AttackType.HEAD_ELBOW:
			return J_ELBOW_B
		CombatData.AttackType.FLYING_KNEE_FACE:
			return J_KNEE_B
		CombatData.AttackType.LEG_FEINT, CombatData.AttackType.FLYING_SIDE_KICK, CombatData.AttackType.LEAPING_ROUNDHOUSE, \
				CombatData.AttackType.FLYING_AXE_KICK, CombatData.AttackType.THRUST_KICK, CombatData.AttackType.PARA_LEG_KICK, \
				CombatData.AttackType.FLYING_CHEST_KICK:
			return J_FOOT_F
		CombatData.AttackType.BELLY_BOMB:
			return J_HIP
		CombatData.AttackType.STOMACH_SHOT:
			return J_HAND_B
		CombatData.AttackType.JUMPING_SPIN_HOOK:
			return J_FOOT_B
		CombatData.AttackType.POWER_UPPERCUT, CombatData.AttackType.SUPERMAN_PUNCH, \
				CombatData.AttackType.JUMPING_REVERSE_PUNCH, CombatData.AttackType.LEAPING_SPIN_BACKFIST:
			return J_HAND_B
		CombatData.AttackType.REVERSE_PUNCH, CombatData.AttackType.PERFECT_GYAKU, CombatData.AttackType.RISING_PUNCH, \
				CombatData.AttackType.RISING_PALM, CombatData.AttackType.DEFLECT_COUNTER, \
				CombatData.AttackType.BODY_STRAIGHT, CombatData.AttackType.BODY_PUNCH:
			return J_HAND_B
		CombatData.AttackType.HEAVY, CombatData.AttackType.UPPERCUT, CombatData.AttackType.REAR_HOOK, \
				CombatData.AttackType.OVERHAND, CombatData.AttackType.SLIP_COUNTER:
			return J_HAND_B
		CombatData.AttackType.BACK_KICK, CombatData.AttackType.SPIN_HOOK_KICK, CombatData.AttackType.JUMP_SPIN_KICK, \
				CombatData.AttackType.TORNADO_540, CombatData.AttackType.SPIN_COUNTER_KICK:
			return J_FOOT_B
	return J_HAND_F


## Pulls a strike pose back toward the stance just enough that its striking
## joint stops at the opponent's body instead of passing through it. Only when
## the limb is at the height of the opponent's body (a high kick over a crouch,
## or a strike through a dodge, still passes freely).
func _limit_reach(pose: PackedFloat32Array) -> PackedFloat32Array:
	var opp := fighter.opponent
	if opp == null or fighter.current_attack == null or fighter.current_attack.no_strike \
			or fighter.current_attack.type == CombatData.AttackType.BELLY_BOMB:
		return pose
	# A knockdown blow still lands on the body: limit while the hit freezes.
	var down := opp.is_down() and opp.hitstop_frames <= 0
	if down or opp.is_evading():
		return pose
	var gap := (opp.position.x - fighter.position.x) * fighter.facing
	if gap <= 0.0:
		return pose
	var idx := _attack_joint(fighter.current_attack.type)
	var limit := gap - BODY_HALF + CONTACT_DEPTH
	var drawn := _drawn_target_x(opp, fighter.current_attack)
	if drawn != INF:
		limit = drawn + CONTACT_DEPTH
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
	if idx in [J_HAND_F, J_HAND_B, J_ELBOW_B]:
		# Punches make room by sitting back from the shoulder; if that is not
		# enough the glove stays on its line to the target and the elbow bends
		# under it (a short punch). Blending the arm toward the guard instead
		# raised the fist into a hammer-fist shape.
		var sit := pose.duplicate()
		sit[HIP_X] -= PUNCH_ROOM_HIP * dir
		sit[TORSO] -= PUNCH_ROOM_LEAN
		if _solve_joints(sit)[idx].x * dir <= limit:
			base = sit
		elif idx != J_ELBOW_B and dir > 0.0:
			return _short_punch(sit, idx, limit)
		else:
			pose = sit
			base = pose.duplicate()
			base[UA_B] = pose[UA_B] - 1.1
	elif idx == J_FOOT_F or idx == J_FOOT_B:
		# Kicks first make room the way a fighter does: hips back and torso
		# leaning away, the leg staying extended. Only if that is not enough
		# does the knee fold (the knee stays at height, so a head kick still
		# lands high) instead of dropping the whole leg.
		var lean := pose.duplicate()
		lean[HIP_X] -= KICK_ROOM_HIP * dir
		lean[TORSO] -= KICK_ROOM_LEAN
		if _solve_joints(lean)[idx].x * dir <= limit:
			base = lean
		else:
			pose = lean
			var th := TH_F if idx == J_FOOT_F else TH_B
			var sh := SH_F if idx == J_FOOT_F else SH_B
			base = pose.duplicate()
			base[sh] = pose[th] - signf(pose[th]) * 1.8
	var lo := 0.0  # 0 = full strike
	var hi := 1.0  # 1 = stance
	for i in REACH_SEARCH_STEPS:
		var mid := (lo + hi) * 0.5
		if _solve_joints(_blend(pose, base, mid))[idx].x * dir > limit:
			lo = mid
		else:
			hi = mid
	return _blend(pose, base, hi)


## A strike aimed at head height, measured from the floor (a leaping strike's
## hitbox is relative to the airborne root).
func _hits_high(attack: CombatData.Attack) -> bool:
	return attack.hitbox.get_center().y + fighter.position.y - fighter.ground_y < -120.0


## Local x (along this fighter's facing) of the near surface of the part of
## the opponent's DRAWN body the strike aims at: the head for high strikes, the
## chest / stomach otherwise. INF when the opponent has not been drawn yet.
## The opponent's root is not where its body is drawn (stance lean, sway,
## reactions), so contact is measured against the drawing.
func _drawn_target_x(opp: Fighter, attack: CombatData.Attack) -> float:
	var ov := opp.get_node_or_null("Visual") as FighterVisual
	if not _drawing_fresh(ov):
		return INF
	var high := _hits_high(attack)
	if high and CombatData.impact_kind(attack.type) == CombatData.ImpactKind.RISING:
		# Uppercuts and knees come up under the chin, not into the face.
		return _aim_point(ov, true, true).x + 2.0
	var surface := HEAD_R if high else BODY_HALF * 0.75
	return _aim_point(ov, high, false).x - surface


## Two-bone arm IK: the glove placed on its current line from the shoulder,
## just far enough to reach `limit`, the elbow bending below that line.
func _short_punch(pose: PackedFloat32Array, idx: int, limit: float) -> PackedFloat32Array:
	var j := _solve_joints(pose)
	var shoulder := j[J_SHOULDER_F if idx == J_HAND_F else J_SHOULDER_B]
	var line := j[idx] - shoulder
	if line.x <= 1.0:
		return pose
	var u := line.normalized()
	var reach := clampf((limit - shoulder.x) / u.x, 14.0, UPPER_ARM + FOREARM - 0.5)
	var fist := shoulder + u * reach
	var cos_a := (UPPER_ARM * UPPER_ARM + reach * reach - FOREARM * FOREARM) / (2.0 * UPPER_ARM * reach)
	var upper := atan2(u.x, u.y) - acos(clampf(cos_a, -1.0, 1.0))
	var elbow := shoulder + _limb_dir(upper) * UPPER_ARM
	var fore := fist - elbow
	var out := pose.duplicate()
	out[UA_F if idx == J_HAND_F else UA_B] = upper
	out[LA_F if idx == J_HAND_F else LA_B] = atan2(fore.x, fore.y)
	return out


func _striking_joint() -> int:
	if fighter.state == Fighter.State.ATTACK and fighter.current_attack != null:
		var f := fighter.state_frame
		var attack := fighter.current_attack
		if f < int(attack.startup * 0.5) or f >= attack.startup + attack.active + 2:
			return -1
		return _attack_joint(attack.type)
	if fighter.state == Fighter.State.FINISHER:
		var pose_name := String(fighter.script_pose)
		if pose_name in ["shook_hit", "back_extend"]:
			return J_FOOT_B
		if pose_name in ["elbow_hit"]:
			return J_ELBOW_B
		if pose_name in ["fknee_hit"]:
			return J_KNEE_F
		if pose_name in ["lowrh_hit", "bodyrh_hit", "lowside_hit", "sweep_extend", "jrh_hit"]:
			return J_FOOT_F
		if pose_name in ["gyaku_hit", "rpalm_hit"]:
			return J_HAND_B
		if pose_name in ["knife_hit"]:
			return J_HAND_F
		if pose_name.contains("kick") or pose_name == "knee" or pose_name.ends_with("_extend") or pose_name == "axe_chop":
			return J_FOOT_F if pose_name != "knee" else J_KNEE_F
		if pose_name in ["rhook_hit", "overhand_hit", "uppercut_strike", "rbody_hit"]:
			return J_HAND_B
		if pose_name in ["lhook_hit", "bhook_hit"]:
			return J_HAND_F
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
