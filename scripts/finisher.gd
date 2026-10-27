class_name FinisherDirector
extends RefCounted
## Scripted KO finishers, played when a hit would knock a fighter out.
##
## Each finisher is a list of beats. A beat lasts `ticks` simulation ticks and
## can set named poses (rendered by FighterVisual), move either fighter along the
## attacker's facing, launch either one vertically, and land a hit. The last hit
## beat is `final`: it knocks the victim out (Fighter.finish_ko). The victim's
## pose name at that moment picks the KO pose ("slumped" = sitting against a wall).
##
## The director only drives fighters through Fighter's scripted_* API; gravity,
## landing and bouncing are still simulated by Fighter.tick(). main.gd advances
## the director once per tick (not during hitstop) and turns the returned hit
## events into feedback (sparks, hitstop, shake, slow motion).

## APPEND-ONLY (style files refer to finishers by the ids in IDS).
enum Kind { PALM_FLURRY, SPINNING_HEEL, AIR_SMASH, WALL_CRUSH, TORNADO_KICK,
	FINAL_BELL, EIGHT_COUNT, CYCLONE_360, HEAVENS_HEEL,
	EIGHT_LIMBS, IRON_KNEE, ONE_INCH_VERDICT, CRIMSON_CRESCENT,
	HUNDRED_PALMS, DRAGONS_DESCENT, LAST_COMBINATION, KNOCKOUT_RHYTHM,
	PAAYE_LATHI, SUPER_CHOR }

const DISPLAY_NAMES: Dictionary = {
	Kind.PALM_FLURRY: "PALM FLURRY",
	Kind.SPINNING_HEEL: "SPINNING HEEL KICK",
	Kind.AIR_SMASH: "AIR SMASH",
	Kind.WALL_CRUSH: "WALL CRUSH",
	Kind.TORNADO_KICK: "TORNADO KICK 360",
	Kind.FINAL_BELL: "THE FINAL BELL",
	Kind.EIGHT_COUNT: "EIGHT-COUNT",
	Kind.CYCLONE_360: "CYCLONE 360",
	Kind.HEAVENS_HEEL: "HEAVEN'S HEEL",
	Kind.EIGHT_LIMBS: "EIGHT LIMBS",
	Kind.IRON_KNEE: "IRON KNEE",
	Kind.ONE_INCH_VERDICT: "ONE-INCH VERDICT",
	Kind.CRIMSON_CRESCENT: "CRIMSON CRESCENT",
	Kind.HUNDRED_PALMS: "HUNDRED PALMS",
	Kind.DRAGONS_DESCENT: "DRAGON'S DESCENT",
	Kind.LAST_COMBINATION: "LAST COMBINATION",
	Kind.KNOCKOUT_RHYTHM: "KNOCKOUT RHYTHM",
	Kind.PAAYE_LATHI: "PAAYE LATHI, MATHAY LATHI",
	Kind.SUPER_CHOR: "SUPER CHOR",
}
## Permanent finisher ids (used by MartialArtStyle.finishers).
const IDS: Dictionary = {
	Kind.PALM_FLURRY: &"palm_flurry", Kind.SPINNING_HEEL: &"spinning_heel", Kind.AIR_SMASH: &"air_smash",
	Kind.WALL_CRUSH: &"wall_crush", Kind.TORNADO_KICK: &"tornado_kick", Kind.FINAL_BELL: &"final_bell",
	Kind.EIGHT_COUNT: &"eight_count", Kind.CYCLONE_360: &"cyclone_360", Kind.HEAVENS_HEEL: &"heavens_heel",
	Kind.EIGHT_LIMBS: &"eight_limbs", Kind.IRON_KNEE: &"iron_knee", Kind.ONE_INCH_VERDICT: &"one_inch_verdict",
	Kind.CRIMSON_CRESCENT: &"crimson_crescent", Kind.HUNDRED_PALMS: &"hundred_palms",
	Kind.DRAGONS_DESCENT: &"dragons_descent", Kind.LAST_COMBINATION: &"last_combination",
	Kind.KNOCKOUT_RHYTHM: &"knockout_rhythm", Kind.PAAYE_LATHI: &"paaye_lathi", Kind.SUPER_CHOR: &"super_chor",
}
## Environmental finishers: shared by every style, chosen by situation.
const ENVIRONMENTAL: Array[Kind] = [Kind.AIR_SMASH, Kind.WALL_CRUSH]
## Open-floor finishers for a fighter with no style (tests).
const OPEN_FLOOR_KINDS: Array[Kind] = [Kind.PALM_FLURRY, Kind.SPINNING_HEEL, Kind.TORNADO_KICK]
## Victim this close to the wall behind them -> Wall Crush.
const WALL_RANGE: float = 170.0
## Chance to use the situational finisher when it applies.
const AIR_SMASH_CHANCE: float = 0.7
const WALL_CRUSH_CHANCE: float = 0.6
## Wall Crush strikes when the attacker's style does not set its own
## (MartialArtStyle.wall_entry): windup, opening strike (into the wall),
## pinning strike, final windup, final blow.
const DEFAULT_WALL_ENTRY: Array[StringName] = [&"knee_windup", &"knee", &"heavy_strike", &"palm_windup", &"palm_strike"]
## The attacker never steps closer than this to the victim.
const MIN_GAP: float = 88.0
## Cinematic playback speed (shared by every finisher; a beat may set its own
## "speed"): set-up beats and strikes near full speed (the hits carry the
## impact), one short hard slow-down on the knockout blow (KO_SLOW_TICKS),
## ticks), the start of the fall, wall impacts, then a smooth return to 1x
## over SETTLE_TICKS after the knockout.
const SPEED_SETUP: float = 1.0
const SPEED_STRIKE: float = 1.0
const SPEED_KO: float = 0.5
const SPEED_WALL: float = 0.8
const KO_SLOW_TICKS: int = 4
## Ticks the knockout blow eases out of its slow motion.
const KO_EASE_TICKS: float = 6.0
## How each striking pose drives the victim (reaction pose and impact direction);
## anything not listed is a straight blow.
const POSE_KIND: Dictionary = {
	&"lhook_hit": CombatData.ImpactKind.HOOK, &"rhook_hit": CombatData.ImpactKind.HOOK,
	&"high_extend": CombatData.ImpactKind.HOOK, &"shook_hit": CombatData.ImpactKind.HOOK,
	&"elbow_hit": CombatData.ImpactKind.HOOK, &"knife_hit": CombatData.ImpactKind.HOOK,
	&"jrh_hit": CombatData.ImpactKind.HOOK, &"spin_kick": CombatData.ImpactKind.HOOK,
	&"tornado_kick": CombatData.ImpactKind.HOOK, &"backhand_strike": CombatData.ImpactKind.HOOK,
	&"uppercut_strike": CombatData.ImpactKind.RISING, &"knee": CombatData.ImpactKind.RISING,
	&"fknee_hit": CombatData.ImpactKind.RISING, &"rpalm_hit": CombatData.ImpactKind.RISING,
	&"axe_chop": CombatData.ImpactKind.DOWNWARD, &"overhand_hit": CombatData.ImpactKind.DOWNWARD,
	&"hammer_strike": CombatData.ImpactKind.DOWNWARD, &"rbody_hit": CombatData.ImpactKind.HOOK,
	&"mega_slap_hit": CombatData.ImpactKind.HOOK, &"slap_hit": CombatData.ImpactKind.HOOK,
	&"punt_hit": CombatData.ImpactKind.STRAIGHT, &"hammer_hit": CombatData.ImpactKind.DOWNWARD,
}
## Low strikes: the victim's lead knee buckles.
const LEG_POSES: Array[StringName] = [&"lowrh_hit", &"lowside_hit", &"sweep_extend", &"lkick_hit"]
## Strike poses thrown with a leg (contact is measured from the feet and knees;
## every other strike pose from the hands and elbows).
const KICK_POSES: Array[StringName] = [&"axe_chop", &"back_extend", &"bodyrh_hit", &"fknee_hit", &"front_extend",
	&"high_extend", &"jrh_hit", &"knee", &"lkick_hit", &"lowrh_hit", &"punt_hit", &"shook_hit", &"spin_kick",
	&"sweep_extend", &"thrust_extend", &"tornado_kick", &"lowside_hit"]
## A blow lands when the striking limb is this close to the victim's drawn body
## (px past the body outline), or at its closest approach, and at the latest
## IMPACT_MAX_WAIT ticks after its beat starts.
const CONTACT_SLOP: float = 6.0
const IMPACT_MAX_WAIT: int = 6
const IMPACT_MAX_WAIT_SWEEP: int = 12
const BODY_RADIUS: float = 16.0
const HEAD_RADIUS: float = 13.0
const LIMB_RADIUS: float = 6.0
## Most the attacker carries forward per tick to make a blow reach, and the
## closest its root may come to the victim's while doing so.
const REACH_ASSIST: float = 7.0
const REACH_MIN_GAP: float = 40.0
## How fast (px/tick) the attacker steps back out to MIN_GAP after a lunge.
const RECOVER_STEP: float = 3.0

## Last finisher played. Static, so it survives scene reloads (restarts) and the
## same finisher is never chosen twice in a row.
static var _last_played: int = -1

var kind: Kind = Kind.PALM_FLURRY
## A hit beat waiting for its limb to arrive (the beat), ticks waited, and the
## last measured gap.
var _pending: Dictionary = {}
var _pending_ticks: int = 0
var _pending_gap: float = INF
## Ticks since the finisher began, and the tick the knockout blow landed (-1).
var _clock: int = 0
var _ko_clock: int = -1
## The gap (px) at which each blow landed, for tests and tuning.
var contact_gaps: Array[float] = []
var attacker: Fighter = null
var victim: Fighter = null
var done: bool = false

var _beats: Array[Dictionary] = []
var _index: int = -1
var _beat_tick: int = 0
var _dir: int = 1
var _wall_entry: Array[StringName] = []


## Finisher by permanent id (-1 if unknown).
static func kind_for_id(fid: StringName) -> int:
	for k in IDS:
		if IDS[k] == fid:
			return k
	return -1


## Picks the finisher that fits the situation: Air Smash for an airborne or
## launching kill, else Wall Crush near the wall behind the victim, else one of
## the ATTACKER'S STYLE's own finishers (never another style's), never repeating
## the previous finisher when there is a choice.
static func choose(atk: Fighter, vic: Fighter, killing_attack: CombatData.Attack, rng: RandomNumberGenerator) -> Kind:
	var picked: Kind
	var wall_x := Fighter.ARENA_MAX_X if atk.facing > 0 else Fighter.ARENA_MIN_X
	var airborne_kill := vic.airborne or (killing_attack != null and killing_attack.launch > 0.0)
	var near_wall := absf(wall_x - vic.position.x) < WALL_RANGE
	# Situational finishers are likely, not guaranteed, so cornered KOs still vary.
	if airborne_kill and _last_played != Kind.AIR_SMASH and rng.randf() < AIR_SMASH_CHANCE:
		picked = Kind.AIR_SMASH
	elif near_wall and _last_played != Kind.WALL_CRUSH and rng.randf() < WALL_CRUSH_CHANCE:
		picked = Kind.WALL_CRUSH
	else:
		var own: Array[Kind] = []
		if atk.style != null and not atk.style.finishers.is_empty():
			for fid in atk.style.finishers:
				own.append(kind_for_id(fid))
		else:
			own = OPEN_FLOOR_KINDS.duplicate()
		var pool: Array[Kind] = []
		for k in own:
			if k != _last_played:
				pool.append(k)
		if pool.is_empty():
			pool = own
		picked = pool[rng.randi_range(0, pool.size() - 1)]
	_last_played = picked
	return picked


func _init(finisher_kind: Kind, atk: Fighter, vic: Fighter) -> void:
	kind = finisher_kind
	attacker = atk
	victim = vic
	_dir = 1 if vic.position.x >= atk.position.x else -1
	attacker.begin_scripted(false)
	victim.begin_scripted(true)
	attacker.facing = _dir
	victim.facing = -_dir
	_wall_entry = DEFAULT_WALL_ENTRY.duplicate()
	if atk.style != null and atk.style.wall_entry.size() == 5:
		_wall_entry.clear()
		for pose in atk.style.wall_entry:
			_wall_entry.append(StringName(pose))
	_beats = _build(kind)
	# Room to strike: the bodies start at least MIN_GAP apart (the victim is
	# shoved back, or the attacker steps back when the victim is at the wall).
	var gap := (vic.position.x - atk.position.x) * _dir
	if gap < MIN_GAP:
		vic.position.x += (MIN_GAP - gap) * _dir
		vic.clamp_to_arena()
		atk.position.x = vic.position.x - maxf(MIN_GAP, absf(vic.position.x - atk.position.x)) * _dir
		atk.clamp_to_arena()


## How far through the build-up (0 at the start, 1 at the knockout blow).
func progress() -> float:
	var final_index := _beats.size() - 1
	for i in _beats.size():
		if _beats[i].get("final", false):
			final_index = i
			break
	return clampf(float(maxi(_index, 0)) / maxf(float(final_index), 1.0), 0.0, 1.0)


## Ticks since the knockout blow landed (-1 before it).
func ticks_since_ko() -> int:
	return -1 if _ko_clock < 0 else _clock - _ko_clock


func _sum_ticks(from: int, to: int) -> int:
	var t := 0
	for k in range(from, to):
		t += int(_beats[k]["ticks"])
	return t


## Playback speed for the current tick (1.0 when done).
func playback_speed() -> float:
	if done or _index < 0 or _index >= _beats.size():
		return 1.0
	var beat := _beats[_index]
	if beat.has("speed"):
		return beat["speed"]
	if beat.get("final", false):
		var since := ticks_since_ko()
		if since < 0:
			return SPEED_STRIKE  # the knockout blow on its way in
		if since < KO_SLOW_TICKS:
			return SPEED_KO
		var u := float(since - KO_SLOW_TICKS) / KO_EASE_TICKS
		return lerpf(SPEED_KO, 1.0, smoothstep(0.0, 1.0, u))
	if _index > 0 and _beats[_index - 1].get("final", false):
		return 1.0
	if beat.get("hit", false):
		return SPEED_WALL if beat.get("wall", false) else SPEED_STRIKE
	return SPEED_SETUP


func get_display_name() -> String:
	return DISPLAY_NAMES[kind]


## Advances one tick. Returns {} or a hit event:
## {"pos": Vector2, "power": int, "final": bool}
func tick() -> Dictionary:
	if done:
		return {}
	var event: Dictionary = {}
	_clock += 1
	if _index < 0 or _beat_tick >= int(_beats[_index]["ticks"]):
		if not _pending.is_empty():
			event = _land(_pending)  # never skip a blow
		_index += 1
		_beat_tick = 0
		if _index >= _beats.size():
			done = true
			attacker.end_scripted()
			return event
		_start_beat(_beats[_index])
	var beat := _beats[_index]
	_move(attacker, beat.get("atk_move", 0.0), true)
	if _pending.is_empty():
		_move(victim, beat.get("def_move", 0.0), false)
		_recover_spacing(beat)
	if not _pending.is_empty() and event.is_empty():
		event = _try_land()
	_beat_tick += 1
	return event


## After a lunge into a blow, the attacker steps back out to striking distance
## (a recoil step, never a snap) unless this beat drives forward on purpose.
func _recover_spacing(beat: Dictionary) -> void:
	if float(beat.get("atk_move", 0.0)) > 0.0 or attacker.airborne or victim.is_down():
		return
	var gap := (victim.position.x - attacker.position.x) * _dir
	if gap < MIN_GAP:
		attacker.position.x -= minf(MIN_GAP - gap, RECOVER_STEP) * _dir
		attacker.clamp_to_arena()


## The pending blow lands once the striking limb meets the victim's drawn body,
## or when it has passed its closest approach, or after IMPACT_MAX_WAIT ticks.
func _try_land() -> Dictionary:
	var gap := _strike_gap(_pending)
	var g: float = gap[0]
	_pending_ticks += 1
	if g > CONTACT_SLOP:
		# Out of reach: the attacker carries forward into the blow (a lunge),
		# never through the victim's body.
		var step := minf(g - CONTACT_SLOP * 0.5, REACH_ASSIST)
		var limit := victim.position.x - REACH_MIN_GAP * _dir
		var x := attacker.position.x + step * _dir
		attacker.position.x = minf(x, limit) if _dir > 0 else maxf(x, limit)
		attacker.clamp_to_arena()
	var arrived := g <= CONTACT_SLOP
	# Spinning and airborne blows swing away before they come round (or drop
	# from above), so they get longer to arrive and no closest-approach rule.
	var sweeping: bool = float(_pending.get("atk_spin", 0.0)) > 0.0 or _pending.get("atk_spin_hold", false) 		or attacker.airborne
	var receding: bool = not sweeping and _pending_ticks > 1 and g > _pending_gap + 0.5
	var wait := mini(IMPACT_MAX_WAIT_SWEEP, int(_pending["ticks"]) - 2) if sweeping else IMPACT_MAX_WAIT
	_pending_gap = minf(_pending_gap, g)
	if arrived or receding or _pending_ticks >= wait:
		return _land(_pending)
	return {}


## Closest the attacker's striking limbs are to the victim's drawn body:
## [gap px past the outline (negative = overlapping), contact point]. Falls back
## to the space between the bodies before either has been drawn.
func _strike_gap(beat: Dictionary) -> Array:
	var high: bool = beat.get("high", true)
	var fallback := (attacker.position + victim.position) * 0.5 + Vector2(0.0, -135.0 if high else -95.0)
	var av := attacker.get_node_or_null("Visual") as FighterVisual
	var vv := victim.get_node_or_null("Visual") as FighterVisual
	if av == null or vv == null or av._last_joints.size() < FighterVisual.JOINTS or vv._last_joints.size() < FighterVisual.JOINTS:
		return [0.0, fallback]
	var a := av._last_joints
	var v := vv._last_joints
	var limbs: Array[Vector2] = []
	if StringName(beat.get("atk", &"")) in KICK_POSES:
		limbs = [a[FighterVisual.J_FOOT_F], a[FighterVisual.J_FOOT_B], a[FighterVisual.J_KNEE_F], a[FighterVisual.J_KNEE_B]]
	else:
		limbs = [a[FighterVisual.J_HAND_F], a[FighterVisual.J_HAND_B], a[FighterVisual.J_ELBOW_F], a[FighterVisual.J_ELBOW_B]]
	# Victim body as capsules: [from, to, radius].
	var parts: Array = [[v[FighterVisual.J_HEAD], v[FighterVisual.J_HEAD], HEAD_RADIUS]]
	if beat.get("contact", &"") != &"head":
		parts.append([v[FighterVisual.J_NECK], v[FighterVisual.J_HIP], BODY_RADIUS])
		if not high:
			for leg in [[FighterVisual.J_KNEE_F, FighterVisual.J_FOOT_F], [FighterVisual.J_KNEE_B, FighterVisual.J_FOOT_B]]:
				parts.append([v[FighterVisual.J_HIP], v[leg[0]], 9.0])
				parts.append([v[leg[0]], v[leg[1]], 7.0])
	var best := INF
	var point := fallback
	for limb in limbs:
		for part in parts:
			var c := Geometry2D.get_closest_point_to_segment(limb, part[0], part[1])
			var d := limb.distance_to(c) - float(part[2]) - LIMB_RADIUS
			if d < best:
				best = d
				# On the body's surface, facing the limb.
				var out := (limb - c).normalized() if limb.distance_squared_to(c) > 0.01 else Vector2(-_dir, 0.0)
				point = c + out * float(part[2])
	return [best, point]


## Resolves a blow: the victim reacts (or is knocked out) and the hit event goes
## out with the real contact point.
func _land(beat: Dictionary) -> Dictionary:
	var gap := _strike_gap(beat)
	_pending = {}
	contact_gaps.append(gap[0])
	return _resolve_hit(beat, gap[1])


func _start_beat(beat: Dictionary) -> Dictionary:
	if beat.has("atk"):
		attacker.script_pose = beat["atk"]
	attacker.script_flip = beat.get("atk_flip", false)
	# atk_spin = full turns about the vertical axis spread over this beat.
	attacker.script_spin_rate = float(beat.get("atk_spin", 0.0)) / maxf(float(beat["ticks"]), 1.0)
	# atk_spin_hold: keep the turn reached so far (a back kick thrown with the
	# back to the target) instead of settling round to face again.
	attacker.script_spin_hold = beat.get("atk_spin_hold", false)
	if beat.has("atk_vy") and beat["atk_vy"] != 0.0:
		attacker.scripted_launch(beat["atk_vy"])
	if not beat.get("hit", false):
		_victim_reacts(beat)
		return {}
	# The blow lands when the limb gets there (see _try_land), not on this tick.
	_pending = beat
	_pending_ticks = 0
	_pending_gap = INF
	return {}


## The victim's side of a beat: its pose, turn and launch (on a hit beat, at
## the moment of impact, never before the blow arrives).
func _victim_reacts(beat: Dictionary) -> void:
	if beat.has("def"):
		victim.script_pose = beat["def"]
	if beat.has("def_flip"):
		victim.script_flip = beat["def_flip"]  # turned round (and stays so once down)
	if beat.has("def_vy"):
		victim.scripted_launch(beat["def_vy"])


func _resolve_hit(beat: Dictionary, contact: Vector2) -> Dictionary:
	var high: bool = beat.get("high", true)
	var final: bool = beat.get("final", false)
	_victim_reacts(beat)
	if final:
		_ko_clock = _clock
	var strike_kind: int = POSE_KIND.get(attacker.script_pose, CombatData.ImpactKind.STRAIGHT)
	if final:
		victim.finish_ko(_dir, beat["ko_vy"], beat["ko_drift"], beat.get("ko_rolls", 0), beat.get("ko_tumble", false))
	else:
		victim.scripted_hit(high, strike_kind)
		# The victim reacts the way the blow travelled (head) or buckles (legs).
		if attacker.script_pose in LEG_POSES:
			victim.script_pose = &"hitstun_leg"
		elif high and victim.script_pose == &"hitstun":
			match strike_kind:
				CombatData.ImpactKind.HOOK:
					victim.script_pose = &"hitstun_hook"
				CombatData.ImpactKind.RISING:
					victim.script_pose = &"hitstun_up"
				CombatData.ImpactKind.DOWNWARD:
					victim.script_pose = &"hitstun_down"
				_:
					victim.script_pose = &"hitstun_heavy" if victim.hit_counter % 2 == 0 else &"hitstun"
	return {"pos": contact, "power": beat.get("power", 1), "final": final, "wall": beat.get("wall", false),
		"dir": _dir, "kind": strike_kind, "high": high, "style": beat.get("style", &"")}


func _move(fighter: Fighter, speed: float, is_attacker: bool) -> void:
	if is_zero_approx(speed):
		return
	var x := fighter.position.x + speed * _dir
	if is_attacker:
		# Close in, but never step into or through the victim.
		# (Only stops further advance: a lunge that already closed in stays.)
		var limit := victim.position.x - MIN_GAP * _dir
		x = minf(x, maxf(limit, fighter.position.x)) if _dir > 0 else maxf(x, minf(limit, fighter.position.x))
	fighter.position.x = x
	fighter.clamp_to_arena()


# --- Choreography ---------------------------------------------------------------
# Beat keys: ticks, atk/def (pose names), atk_flip, atk_move/def_move (px per tick
# along the attacker's facing), atk_vy/def_vy (vertical launch at beat start),
# hit, high, power (1-3), final, ko_vy, ko_drift, ko_rolls, ko_tumble (spin in
# the air), wall (impact is against the arena wall), atk_spin (turns this beat).

func _build(k: Kind) -> Array[Dictionary]:
	# Every finisher ends with a short final-blow hold and then a follow-through
	# beat, so the attacker recovers naturally while the victim is still flying.
	match k:
		Kind.EIGHT_LIMBS:
			# Muay Thai: elbow, knee, elbow, knee, then a high roundhouse.
			return [
				{"ticks": 6, "atk": &"elbow_load", "def": &"stagger"},
				{"ticks": 6, "atk": &"elbow_hit", "def": &"hitstun", "hit": true, "atk_move": 1.0, "def_move": 0.8},
				{"ticks": 7, "atk": &"knee", "def": &"hitstun_body", "hit": true, "high": false, "atk_move": 0.8, "def_move": 0.8},
				{"ticks": 6, "atk": &"elbow_hit", "def": &"hitstun", "hit": true, "atk_move": 0.8, "def_move": 0.8},
				{"ticks": 7, "atk": &"knee", "def": &"hitstun_body", "hit": true, "high": false, "power": 2, "atk_move": 0.8, "def_move": 1.2},
				{"ticks": 10, "atk": &"knee_windup", "def": &"stagger"},
				{"ticks": 18, "atk": &"high_extend", "def": &"knock_fly", "hit": true, "power": 3, "final": true,
					"ko_vy": -11.0, "ko_drift": 14.0, "ko_rolls": 1, "ko_tumble": true},
				{"ticks": 50, "atk": &"guard", "def": &"knock_fly"},
			]
		Kind.IRON_KNEE:
			# Muay Thai: step in, two knees to the body, then a jumping knee.
			return [
				{"ticks": 8, "atk": &"guard", "def": &"stagger", "atk_move": 2.5},
				{"ticks": 7, "atk": &"knee", "def": &"hitstun_body", "hit": true, "high": false, "power": 2, "def_move": 1.0},
				{"ticks": 6, "atk": &"knee_windup", "def": &"hitstun_body"},
				{"ticks": 7, "atk": &"knee", "def": &"hitstun_body", "hit": true, "high": false, "power": 2, "def_move": 1.0},
				{"ticks": 8, "atk": &"jump_rise", "def": &"stagger", "atk_vy": -11.0, "atk_move": 2.0},
				{"ticks": 16, "atk": &"fknee_hit", "def": &"knock_fly", "hit": true, "power": 3, "final": true,
					"ko_vy": -12.0, "ko_drift": 11.0, "ko_rolls": 0, "ko_tumble": false},
				{"ticks": 55, "atk": &"land_crouch", "def": &"knock_fly"},
			]
		Kind.ONE_INCH_VERDICT:
			# Karate: deflect, reverse punch, a held breath, then one explosive
			# close-range punch.
			return [
				{"ticks": 8, "atk": &"deflect", "def": &"stagger"},
				{"ticks": 8, "atk": &"gyaku_hit", "def": &"hitstun_body", "hit": true, "power": 2, "atk_move": 1.5, "def_move": 0.5},
				{"ticks": 18, "atk": &"gyaku_load", "def": &"stagger"},
				{"ticks": 18, "atk": &"gyaku_hit", "def": &"knock_fly", "hit": true, "power": 3, "final": true,
					"ko_vy": -8.0, "ko_drift": 17.0, "ko_rolls": 2, "ko_tumble": true},
				{"ticks": 50, "atk": &"guard", "def": &"knock_fly"},
			]
		Kind.CRIMSON_CRESCENT:
			# Karate: front kick, advancing reverse punch, spinning high kick.
			return [
				{"ticks": 7, "atk": &"front_extend", "def": &"hitstun_body", "hit": true, "high": false, "atk_move": 1.0, "def_move": 1.5},
				{"ticks": 8, "atk": &"gyaku_hit", "def": &"hitstun", "hit": true, "power": 2, "atk_move": 2.0, "def_move": 0.8},
				{"ticks": 10, "atk": &"spin_windup", "def": &"stagger", "atk_spin": 0.5},
				{"ticks": 4, "atk": &"spin_kick", "def": &"stagger", "atk_spin": 0.5},
				{"ticks": 18, "atk": &"spin_kick", "def": &"knock_fly", "hit": true, "power": 3, "final": true,
					"ko_vy": -13.0, "ko_drift": 13.0, "ko_rolls": 2, "ko_tumble": true},
				{"ticks": 50, "atk": &"guard", "def": &"knock_fly"},
			]
		Kind.HUNDRED_PALMS:
			# Kung Fu: a storm of palms, a stagger, then the double palm.
			var beats: Array[Dictionary] = [{"ticks": 6, "atk": &"palm_windup", "def": &"stagger"}]
			for i in 6:
				beats.append({"ticks": 4, "atk": &"palm_lead" if i % 2 == 0 else &"palm_rear",
					"def": &"hitstun" if i % 2 == 0 else &"hitstun_body", "hit": true, "high": i % 2 == 0,
					"atk_move": 0.8, "def_move": 0.8})
			beats.append({"ticks": 10, "atk": &"palm_windup", "def": &"stagger"})
			beats.append({"ticks": 20, "atk": &"palm_strike", "def": &"knock_fly", "hit": true, "power": 3, "final": true,
				"ko_vy": -10.0, "ko_drift": 17.0, "ko_rolls": 0, "ko_tumble": true})
			beats.append({"ticks": 55, "atk": &"guard", "def": &"knock_fly"})
			return beats
		Kind.DRAGONS_DESCENT:
			# Kung Fu: sweep the legs, a rising palm lifts them, leap after
			# them and drive them down into the floor.
			return [
				{"ticks": 9, "atk": &"sweep_load", "def": &"stagger"},
				{"ticks": 7, "atk": &"sweep_extend", "def": &"knock_fly", "hit": true, "high": false, "def_vy": -6.0},
				{"ticks": 8, "atk": &"rpalm_hit", "def": &"knock_fly", "hit": true, "power": 2, "def_vy": -10.0},
				{"ticks": 9, "atk": &"jump_rise", "def": &"knock_fly", "atk_vy": -13.0, "atk_move": 1.0},
				{"ticks": 16, "atk": &"hammer_strike", "def": &"knock_fly", "hit": true, "power": 3, "final": true,
					"ko_vy": 16.0, "ko_drift": 6.0, "ko_rolls": 0, "ko_tumble": false},
				{"ticks": 55, "atk": &"land_crouch", "def": &"knock_fly"},
			]
		Kind.LAST_COMBINATION:
			# Kickboxing: jab, cross, body kick, head kick, spinning back kick.
			return [
				{"ticks": 5, "atk": &"jab_strike", "def": &"hitstun", "hit": true, "atk_move": 1.0, "def_move": 0.8},
				{"ticks": 6, "atk": &"heavy_strike", "def": &"hitstun", "hit": true, "power": 2, "atk_move": 1.0, "def_move": 0.8},
				{"ticks": 7, "atk": &"bodyrh_hit", "def": &"hitstun_body", "hit": true, "high": false, "def_move": 1.0},
				{"ticks": 8, "atk": &"high_extend", "def": &"hitstun", "hit": true, "power": 2, "def_move": 1.0},
				# Spinning back kick: turn the back to them, look over the
				# shoulder with the knee chambered, thrust the heel straight
				# back, and only then turn round to face again.
				{"ticks": 10, "atk": &"spin_windup", "def": &"hitstun_hook", "atk_spin": 0.5},
				{"ticks": 4, "atk": &"back_chamber", "def": &"hitstun_hook", "atk_spin_hold": true},
				{"ticks": 18, "atk": &"back_extend", "def": &"knock_fly", "hit": true, "power": 3, "final": true,
					"ko_vy": -10.0, "ko_drift": 17.0, "ko_rolls": 2, "ko_tumble": true, "atk_spin_hold": true},
				{"ticks": 12, "atk": &"back_chamber", "def": &"knock_fly", "atk_spin": 0.5},
				{"ticks": 38, "atk": &"guard", "def": &"knock_fly"},
			]
		Kind.KNOCKOUT_RHYTHM:
			# Kickboxing: punch, kick, punch, kick, then a jumping roundhouse.
			return [
				{"ticks": 5, "atk": &"jab_strike", "def": &"hitstun", "hit": true, "atk_move": 1.0, "def_move": 0.8},
				{"ticks": 7, "atk": &"lowrh_hit", "def": &"hitstun_body", "hit": true, "high": false, "def_move": 0.8},
				{"ticks": 5, "atk": &"heavy_strike", "def": &"hitstun", "hit": true, "atk_move": 1.0, "def_move": 0.8},
				{"ticks": 7, "atk": &"bodyrh_hit", "def": &"hitstun_body", "hit": true, "high": false, "power": 2, "def_move": 1.0},
				{"ticks": 8, "atk": &"jump_rise", "def": &"stagger", "atk_vy": -11.0, "atk_move": 2.0},
				{"ticks": 16, "atk": &"jrh_hit", "def": &"knock_fly", "hit": true, "power": 3, "final": true,
					"ko_vy": -12.0, "ko_drift": 14.0, "ko_rolls": 1, "ko_tumble": true},
				{"ticks": 55, "atk": &"land_crouch", "def": &"knock_fly"},
			]
		Kind.FINAL_BELL:
			# Boxing: a lead body hook folds them, a rear body hook (other arm,
			# harder) doubles them over, then a deep crouch and a rising uppercut
			# lifts them up and back onto their back.
			return [
				{"ticks": 8, "atk": &"bhook_load", "def": &"stagger"},
				{"ticks": 8, "atk": &"bhook_hit", "def": &"hitstun_body", "hit": true, "high": false, "power": 2, "atk_move": 1.5, "def_move": 1.0},
				{"ticks": 7, "atk": &"rbody_load", "def": &"hitstun_body"},
				{"ticks": 9, "atk": &"rbody_hit", "def": &"hitstun_body", "hit": true, "high": false, "power": 2, "atk_move": 1.0, "def_move": 1.8},
				{"ticks": 12, "atk": &"upper_load_deep", "def": &"hitstun_body"},
				{"ticks": 26, "atk": &"uppercut_strike", "def": &"knock_fly", "hit": true, "power": 3, "final": true,
					"ko_vy": -14.0, "ko_drift": 5.0, "ko_rolls": 0, "ko_tumble": false},
				{"ticks": 55, "atk": &"guard", "def": &"knock_fly"},
			]
		Kind.EIGHT_COUNT:
			# Boxing: slip under, six punches alternating arms and heights (lead
			# hook, rear hook, jab, lead body hook, rear body hook, uppercut),
			# then a loaded power cross that sends them flying sideways, twisting.
			return [
				{"ticks": 8, "atk": &"slip_dip", "def": &"stagger"},
				{"ticks": 5, "atk": &"lhook_hit", "def": &"hitstun", "hit": true, "atk_move": 0.8, "def_move": 0.8},
				{"ticks": 5, "atk": &"rhook_hit", "def": &"hitstun", "hit": true, "atk_move": 0.8, "def_move": 0.8},
				{"ticks": 5, "atk": &"jab_strike", "def": &"hitstun", "hit": true, "atk_move": 0.8, "def_move": 0.8},
				{"ticks": 5, "atk": &"bhook_hit", "def": &"hitstun_body", "hit": true, "high": false, "atk_move": 0.8, "def_move": 0.8},
				{"ticks": 5, "atk": &"rbody_hit", "def": &"hitstun_body", "hit": true, "high": false, "atk_move": 0.8, "def_move": 1.0},
				{"ticks": 6, "atk": &"uppercut_strike", "def": &"hitstun", "hit": true, "power": 2, "atk_move": 0.5, "def_move": 1.0},
				{"ticks": 12, "atk": &"heavy_windup", "def": &"stagger"},
				{"ticks": 26, "atk": &"heavy_strike", "def": &"knock_fly", "hit": true, "power": 3, "final": true,
					"ko_vy": -6.0, "ko_drift": 17.0, "ko_rolls": 0, "ko_tumble": true},
				{"ticks": 55, "atk": &"guard", "def": &"knock_fly"},
			]
		Kind.PAAYE_LATHI:
			# Bangla Maar ("a kick to the leg, a kick to the head"): a hard kick to
			# the leg spins them round and drops them on their back with the head
			# towards the attacker; a stroll in, a run-up and a football punt to
			# the head sends the body sliding away along the floor.
			return [
				{"ticks": 8, "atk": &"lkick_load", "def": &"stagger"},
				{"ticks": 8, "atk": &"lkick_hit", "def": &"hitstun_leg", "hit": true, "high": false, "power": 2,
					"atk_move": 0.8, "def_move": 0.8},
				{"ticks": 12, "atk": &"guard", "def": &"knock_fly", "def_vy": -5.0, "def_flip": true, "def_move": 3.0},
				{"ticks": 12, "atk": &"guard", "def": &"ko_lie", "def_flip": true},
				{"ticks": 14, "atk": &"guard", "def": &"ko_lie", "atk_move": 1.0},
				{"ticks": 14, "atk": &"punt_load", "def": &"ko_lie", "atk_move": 0.5},
				{"ticks": 4, "atk": &"punt_hit", "def": &"ko_lie", "speed": 1.0},
				{"ticks": 9, "atk": &"punt_hit", "def": &"ko_lie", "hit": true, "high": false, "power": 3, "final": true,
					"style": &"punt", "contact": &"head",
					"ko_vy": -1.5, "ko_drift": 15.0, "ko_rolls": 0, "ko_tumble": false},
				{"ticks": 16, "atk": &"punt_follow", "def": &"ko_lie"},
				{"ticks": 45, "atk": &"guard", "def": &"ko_lie"},
			]
		Kind.SUPER_CHOR:
			# Bangla Maar: a front thrust kick to the stomach folds them over, an
			# enormous wind-up, and an open-palm slap right across the face that
			# sends them flying and skidding; then shake the stinging hand.
			return [
				{"ticks": 8, "atk": &"thrust_chamber", "def": &"stagger"},
				{"ticks": 10, "atk": &"thrust_extend", "def": &"hitstun_body", "hit": true, "high": false, "power": 2,
					"atk_move": 0.8, "def_move": 0.8},
				# The wind-up: they stagger back upright (the slap needs the full arm).
				{"ticks": 22, "atk": &"mega_slap_wind", "def": &"stagger", "def_move": 1.4, "speed": 0.8},
				# The swing: the open palm whips round and arrives at the cheek first.
				{"ticks": 7, "atk": &"mega_slap_hit", "def": &"stagger", "speed": 1.0},
				{"ticks": 8, "atk": &"mega_slap_hit", "def": &"knock_fly", "hit": true, "power": 3, "final": true,
					"style": &"slap", "contact": &"head",
					"ko_vy": -9.0, "ko_drift": 18.0, "ko_rolls": 0, "ko_tumble": true},
				{"ticks": 16, "atk": &"mega_slap_follow", "def": &"knock_fly"},
				{"ticks": 5, "atk": &"hand_shake_a", "def": &"knock_fly"},
				{"ticks": 5, "atk": &"hand_shake_b", "def": &"knock_fly"},
				{"ticks": 5, "atk": &"hand_shake_a", "def": &"knock_fly"},
				{"ticks": 5, "atk": &"hand_shake_b", "def": &"knock_fly"},
				{"ticks": 40, "atk": &"guard", "def": &"knock_fly"},
			]
		Kind.CYCLONE_360:
			# Taekwondo: a double kick (front, then high), coil, jump into a full
			# spin and a head-height roundhouse.
			return [
				{"ticks": 7, "atk": &"front_extend", "def": &"hitstun_body", "hit": true, "high": false, "atk_move": 1.0, "def_move": 1.5},
				{"ticks": 8, "atk": &"high_extend", "def": &"hitstun", "hit": true, "power": 2, "atk_move": 1.0, "def_move": 1.5},
				{"ticks": 12, "atk": &"tornado_windup", "def": &"stagger", "atk_spin": 0.25},
				{"ticks": 14, "atk": &"tornado_chamber", "def": &"stagger", "atk_vy": -10.0, "atk_move": 2.5, "atk_spin": 0.75},
				{"ticks": 16, "atk": &"tornado_kick", "def": &"knock_fly", "hit": true, "power": 3, "final": true,
					"ko_vy": -13.0, "ko_drift": 15.0, "ko_rolls": 2, "ko_tumble": true},
				{"ticks": 55, "atk": &"land_crouch", "def": &"knock_fly"},
			]
		Kind.HEAVENS_HEEL:
			# Taekwondo: spinning hook kick, leap, and a descending axe kick that
			# drives them into the floor.
			return [
				{"ticks": 10, "atk": &"shook_load", "def": &"stagger", "atk_spin": 0.4},
				{"ticks": 8, "atk": &"shook_hit", "def": &"hitstun", "hit": true, "power": 2, "atk_move": 1.0, "def_move": 1.2, "atk_spin": 0.6},
				{"ticks": 10, "atk": &"jump_rise", "def": &"stagger", "atk_vy": -13.0, "atk_move": 1.5},
				{"ticks": 6, "atk": &"axe_raise", "def": &"stagger"},
				{"ticks": 16, "atk": &"axe_chop", "def": &"knock_fly", "hit": true, "power": 3, "final": true,
					"ko_vy": 16.0, "ko_drift": 6.0, "ko_rolls": 0, "ko_tumble": false},
				{"ticks": 55, "atk": &"land_crouch", "def": &"knock_fly"},
			]
		Kind.SPINNING_HEEL:
			# Jab, cross, spin with the back turned, head-high spinning heel kick.
			return [
				{"ticks": 6, "atk": &"jab_strike", "def": &"hitstun", "hit": true, "atk_move": 1.0, "def_move": 1.0},
				{"ticks": 8, "atk": &"heavy_strike", "def": &"hitstun_body", "hit": true, "high": false, "power": 2, "atk_move": 1.5, "def_move": 1.5},
				{"ticks": 10, "atk": &"spin_windup", "def": &"stagger", "atk_spin": 0.5},
				{"ticks": 4, "atk": &"spin_kick", "def": &"stagger", "atk_spin": 0.5},
				{"ticks": 18, "atk": &"spin_kick", "def": &"knock_fly", "hit": true, "power": 3, "final": true,
					"ko_vy": -14.0, "ko_drift": 13.0, "ko_rolls": 2, "ko_tumble": true},
				{"ticks": 50, "atk": &"guard", "def": &"knock_fly"},
			]
		Kind.TORNADO_KICK:
			# Jab, cross, coil and load, jump into a full 360, high tornado kick,
			# land in a low follow-through.
			return [
				{"ticks": 6, "atk": &"jab_strike", "def": &"hitstun", "hit": true, "atk_move": 1.0, "def_move": 1.0},
				{"ticks": 8, "atk": &"heavy_strike", "def": &"hitstun_body", "hit": true, "high": false, "power": 2, "atk_move": 1.5, "def_move": 1.5},
				{"ticks": 12, "atk": &"tornado_windup", "def": &"stagger", "atk_spin": 0.25},
				{"ticks": 14, "atk": &"tornado_chamber", "def": &"stagger", "atk_vy": -10.0, "atk_move": 2.5, "atk_spin": 0.75},
				{"ticks": 16, "atk": &"tornado_kick", "def": &"knock_fly", "hit": true, "power": 3, "final": true,
					"ko_vy": -13.0, "ko_drift": 15.0, "ko_rolls": 2, "ko_tumble": true},
				{"ticks": 55, "atk": &"land_crouch", "def": &"knock_fly"},
			]
		Kind.AIR_SMASH:
			# Leap together, reach and grab, overhead hammer-fist, spike into the
			# floor (crater and shockwave on landing), land in a crouch.
			return [
				{"ticks": 9, "atk": &"jump_rise", "def": &"knock_fly", "atk_vy": -14.0, "def_vy": -11.0, "atk_move": 3.0, "def_move": 0.5},
				{"ticks": 5, "atk": &"grab", "def": &"knock_fly", "atk_move": 1.5},
				{"ticks": 4, "atk": &"hammer_windup", "def": &"knock_fly"},
				{"ticks": 16, "atk": &"hammer_strike", "def": &"knock_fly", "hit": true, "power": 3, "final": true,
					"ko_vy": 18.0, "ko_drift": 4.0, "ko_rolls": 1, "ko_tumble": true},
				{"ticks": 55, "atk": &"land_crouch", "def": &"knock_fly"},
			]
		Kind.WALL_CRUSH:
			# Driving entry into the wall, a pinning strike, then the big final
			# blow; the wall cracks and the victim slumps against it. The strikes
			# come from the attacker's style (default: the flying knee, cross
			# and double palm); only the knee entry leaves the ground.
			var leap := -5.0 if _wall_entry[1] == &"knee" else 0.0
			return [
				{"ticks": 8, "atk": _wall_entry[0], "def": &"stagger"},
				{"ticks": 8, "atk": _wall_entry[1], "def": &"stagger", "atk_vy": leap, "atk_move": 7.0},
				{"ticks": 8, "atk": _wall_entry[1], "def": &"hitstun_body", "hit": true, "high": false, "power": 2, "def_move": 9.0, "atk_move": 5.0, "wall": true},
				{"ticks": 9, "atk": _wall_entry[2], "def": &"hitstun", "hit": true, "power": 2, "atk_move": 1.0, "wall": true},
				{"ticks": 10, "atk": _wall_entry[3], "def": &"stagger"},
				{"ticks": 20, "atk": _wall_entry[4], "def": &"slumped", "hit": true, "power": 3, "final": true, "ko_vy": -2.0, "ko_drift": 0.0, "wall": true},
				# Step back out of the slumped body's legs, then hold the guard.
				{"ticks": 22, "atk": &"guard", "def": &"slumped", "atk_move": -3.2},
				{"ticks": 30, "atk": &"guard", "def": &"slumped"},
			]
	# PALM_FLURRY (default): four fast alternating palm strikes, then a heavy
	# double palm that blasts the victim across the arena.
	return [
		{"ticks": 6, "atk": &"palm_windup", "def": &"stagger"},
		{"ticks": 5, "atk": &"palm_lead", "def": &"hitstun", "hit": true, "atk_move": 1.5, "def_move": 1.2},
		{"ticks": 5, "atk": &"palm_rear", "def": &"hitstun_body", "hit": true, "high": false, "atk_move": 1.5, "def_move": 1.2},
		{"ticks": 5, "atk": &"palm_lead", "def": &"hitstun", "hit": true, "atk_move": 1.5, "def_move": 1.2},
		{"ticks": 6, "atk": &"palm_rear", "def": &"hitstun_body", "hit": true, "high": false, "power": 2, "atk_move": 1.5, "def_move": 1.5},
		{"ticks": 10, "atk": &"palm_windup", "def": &"stagger"},
		{"ticks": 20, "atk": &"palm_strike", "def": &"knock_fly", "hit": true, "power": 3, "final": true,
			"ko_vy": -10.0, "ko_drift": 16.0, "ko_rolls": 0, "ko_tumble": true},
		{"ticks": 55, "atk": &"guard", "def": &"knock_fly"},
	]
