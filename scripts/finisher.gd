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
	PAAYE_LATHI, SUPER_CHOR, SKYLINE_VERDICT, IRON_CORNER,
	FALLING_CROSS, CORNER_COUNT, AIR_BREAKER, CORNER_BREAKER, SKYFALL_AXE, CORNER_CYCLONE,
	DESCENDING_DRAGON_PALM, WALL_OF_PALMS, BANGLA_AIR_SMASH, DEOWAL_DHAKKA,
	RODAS_END, HANDSTAND_HAVOC, SKY_WHEEL, CORNER_CARNIVAL,
	ONE_INCH_ENDING, NO_SECOND_CHANCE, DRAGON_INTERCEPT, END_OF_LINE }

const DISPLAY_NAMES: Dictionary = {
	Kind.PALM_FLURRY: "PALM FLURRY",
	Kind.SPINNING_HEEL: "SPINNING HEEL KICK",
	Kind.AIR_SMASH: "CLASSIC AIR SMASH",
	Kind.WALL_CRUSH: "CLASSIC WALL CRUSH",
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
	Kind.PAAYE_LATHI: "FOOTBALL SHOT",
	Kind.SUPER_CHOR: "SUPER CHOR",
	Kind.SKYLINE_VERDICT: "SKYLINE VERDICT",
	Kind.IRON_CORNER: "IRON CORNER",
	Kind.FALLING_CROSS: "FALLING CROSS",
	Kind.CORNER_COUNT: "THE CORNER COUNT",
	Kind.AIR_BREAKER: "AIR BREAKER",
	Kind.CORNER_BREAKER: "CORNER BREAKER",
	Kind.SKYFALL_AXE: "SKYFALL AXE",
	Kind.CORNER_CYCLONE: "CORNER CYCLONE",
	Kind.DESCENDING_DRAGON_PALM: "DESCENDING DRAGON PALM",
	Kind.WALL_OF_PALMS: "WALL OF PALMS",
	Kind.BANGLA_AIR_SMASH: "AIR SMASH",
	Kind.DEOWAL_DHAKKA: "DEOWAL DHAKKA",
	Kind.RODAS_END: "RODA'S END",
	Kind.HANDSTAND_HAVOC: "HANDSTAND HAVOC",
	Kind.SKY_WHEEL: "SKY WHEEL",
	Kind.CORNER_CARNIVAL: "CORNER CARNIVAL",
	Kind.ONE_INCH_ENDING: "ONE-INCH ENDING",
	Kind.NO_SECOND_CHANCE: "NO SECOND CHANCE",
	Kind.DRAGON_INTERCEPT: "DRAGON INTERCEPT",
	Kind.END_OF_LINE: "END OF THE LINE",
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
	Kind.SKYLINE_VERDICT: &"skyline_verdict", Kind.IRON_CORNER: &"iron_corner",
	Kind.FALLING_CROSS: &"falling_cross", Kind.CORNER_COUNT: &"corner_count",
	Kind.AIR_BREAKER: &"air_breaker", Kind.CORNER_BREAKER: &"corner_breaker",
	Kind.SKYFALL_AXE: &"skyfall_axe", Kind.CORNER_CYCLONE: &"corner_cyclone",
	Kind.DESCENDING_DRAGON_PALM: &"descending_dragon_palm", Kind.WALL_OF_PALMS: &"wall_of_palms",
	Kind.BANGLA_AIR_SMASH: &"bangla_air_smash", Kind.DEOWAL_DHAKKA: &"deowal_dhakka",
	Kind.RODAS_END: &"rodas_end", Kind.HANDSTAND_HAVOC: &"handstand_havoc",
	Kind.SKY_WHEEL: &"sky_wheel", Kind.CORNER_CARNIVAL: &"corner_carnival",
	Kind.ONE_INCH_ENDING: &"one_inch_ending", Kind.NO_SECOND_CHANCE: &"no_second_chance",
	Kind.DRAGON_INTERCEPT: &"dragon_intercept", Kind.END_OF_LINE: &"end_of_line",
}
## Situational finishers: one airborne and one wall finisher per style
## (MartialArtStyle.air_finisher / wall_finisher); Air Smash and Wall Crush are
## the shared ones for a style that sets none.
const AIR_KINDS: Array[Kind] = [Kind.AIR_SMASH, Kind.SKYLINE_VERDICT, Kind.FALLING_CROSS, Kind.AIR_BREAKER,
	Kind.SKYFALL_AXE, Kind.DESCENDING_DRAGON_PALM, Kind.BANGLA_AIR_SMASH, Kind.SKY_WHEEL, Kind.DRAGON_INTERCEPT]

const WALL_KINDS: Array[Kind] = [Kind.WALL_CRUSH, Kind.IRON_CORNER, Kind.CORNER_COUNT, Kind.CORNER_BREAKER,
	Kind.CORNER_CYCLONE, Kind.WALL_OF_PALMS, Kind.DEOWAL_DHAKKA, Kind.CORNER_CARNIVAL, Kind.END_OF_LINE]
const ENVIRONMENTAL: Array[Kind] = [Kind.AIR_SMASH, Kind.SKYLINE_VERDICT, Kind.FALLING_CROSS, Kind.AIR_BREAKER,
	Kind.SKYFALL_AXE, Kind.DESCENDING_DRAGON_PALM, Kind.BANGLA_AIR_SMASH, Kind.WALL_CRUSH, Kind.IRON_CORNER,
	Kind.CORNER_COUNT, Kind.CORNER_BREAKER, Kind.CORNER_CYCLONE, Kind.WALL_OF_PALMS, Kind.DEOWAL_DHAKKA,
	Kind.SKY_WHEEL, Kind.DRAGON_INTERCEPT, Kind.CORNER_CARNIVAL, Kind.END_OF_LINE]
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
	&"cap_armada_hit": CombatData.ImpactKind.HOOK, &"cap_meialua_hit": CombatData.ImpactKind.HOOK,
	&"jkd_hook_hit": CombatData.ImpactKind.HOOK,
	&"uppercut_strike": CombatData.ImpactKind.RISING, &"knee": CombatData.ImpactKind.RISING,
	&"fknee_hit": CombatData.ImpactKind.RISING, &"rpalm_hit": CombatData.ImpactKind.RISING,
	&"axe_chop": CombatData.ImpactKind.DOWNWARD, &"overhand_hit": CombatData.ImpactKind.DOWNWARD,
	&"hammer_strike": CombatData.ImpactKind.DOWNWARD, &"hammer_palm": CombatData.ImpactKind.DOWNWARD, &"rbody_hit": CombatData.ImpactKind.HOOK,
	&"mega_slap_hit": CombatData.ImpactKind.HOOK, &"slap_hit": CombatData.ImpactKind.HOOK,
	&"punt_hit": CombatData.ImpactKind.STRAIGHT, &"hammer_hit": CombatData.ImpactKind.DOWNWARD,
}
## Low strikes: the victim's lead knee buckles.
const LEG_POSES: Array[StringName] = [&"lowrh_hit", &"lowside_hit", &"sweep_extend", &"lkick_hit",
	&"cap_rasteira_hit", &"jkd_stop_hit"]
## Strike poses thrown with a leg (contact is measured from the feet and knees;
## every other strike pose from the hands and elbows).
const KICK_POSES: Array[StringName] = [&"axe_chop", &"back_extend", &"back_extend_high", &"bodyrh_hit", &"fknee_hit", &"front_extend", &"flying_side_kick",
	&"high_extend", &"jrh_hit", &"knee", &"lkick_hit", &"lowrh_hit", &"punt_hit", &"shook_hit", &"spin_kick",
	&"sweep_extend", &"thrust_extend", &"tornado_kick", &"lowside_hit", &"cap_armada_hit", &"cap_au_hit",
	&"cap_crescent_hit", &"cap_rasteira_hit", &"cap_meialua_hit", &"cap_scissor_hit", &"jkd_side_hit",
	&"jkd_stop_hit", &"jkd_hook_hit"]

## Documented contact tolerance: a blow counts as landed when its intended
## limb is within CONTACT_SLOP px of the victim's drawn body outline.
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
## Step-in added before a finisher whose first beat is already a strike.
const LEAD_IN_TICKS: int = 6
## How fast (px/tick) the attacker steps back out to MIN_GAP after a lunge.
const RECOVER_STEP: float = 3.0
## Before a blow, the attacker steps in (px/tick) to the root gap at which the
## intended limb, in its authored strike pose, meets the victim's body.
const APPROACH_STEP: float = 5.0
## How far into the victim's body outline the authored strike aims (px).
const APPROACH_DEPTH: float = 4.0
## Airborne finishers: the victim's flight is retimed at the start so their
## chest meets the striking limb this many ticks into the "meet" beat. Their
## relaunch stays within MEET_VY_MIN..MEET_VY_MAX (px/tick, up negative).
const MEET_LEAD: int = 3
const MEET_VY_MIN: float = -15.0
const MEET_VY_MAX: float = 7.0
## Lowest a victim's root may be met at (px above the floor).
const MEET_MIN_ALT: float = 15.0
## Where on the torso the meeting blow aims (0 neck, 1 hip): the upper chest
## (a beat's "meet_at" sets its own).
const MEET_CHEST: float = 0.25
## Fastest the attacker glides (px/tick) toward striking range in the air.
const GLIDE_MAX: float = 9.0
## Most an airborne victim's body is nudged (px/tick, up or down) toward a blow
## that is waiting to connect: the plan above gets it close, this absorbs the
## difference between the planned and the drawn limb.
const AIR_ASSIST: float = 6.0
## A victim this close to the arena bound is against the wall (impacts crack it).
const AT_WALL: float = 30.0

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
## Where on the victim's torso each blow landed: 0 at the neck, 1 at the hip
## (below 0 = the head, above 1 = the legs; NAN when nothing was drawn).
var contact_heights: Array[float] = []
## The joint (FighterVisual.J_*) the pending blow must land with.
var _pending_limb: int = -1
## The reach assist moved the attacker on the last tick.
var _pending_stepped: bool = false
var attacker: Fighter = null
var victim: Fighter = null
var done: bool = false

var _beats: Array[Dictionary] = []
var _index: int = -1
var _beat_tick: int = 0
var _dir: int = 1
var _wall_entry: Array[StringName] = []
## Index of the airborne meeting blow (-1 if none).
var _meet: int = -1
## The victim was stopped by the wall during this beat's push (once per beat).
var _slammed: bool = false


## Finisher by permanent id (-1 if unknown).
static func kind_for_id(fid: StringName) -> int:
	for k in IDS:
		if IDS[k] == fid:
			return k
	return -1


## The attacker style's airborne finisher (Air Smash when it sets none).
static func air_kind_for(style: MartialArtStyle) -> Kind:
	if style != null and style.air_finisher != &"":
		return kind_for_id(style.air_finisher) as Kind
	return Kind.AIR_SMASH


## The attacker style's wall finisher (Wall Crush when it sets none).
static func wall_kind_for(style: MartialArtStyle) -> Kind:
	if style != null and style.wall_finisher != &"":
		return kind_for_id(style.wall_finisher) as Kind
	return Kind.WALL_CRUSH


## Picks the finisher that fits the situation, always from the ATTACKER'S
## style (never another style's): its airborne finisher for an airborne or
## launching kill, else its wall finisher near the wall behind the victim,
## else one of its own open-floor finishers, never repeating the previous
## finisher when there is a choice.
static func choose(atk: Fighter, vic: Fighter, killing_attack: CombatData.Attack, rng: RandomNumberGenerator) -> Kind:
	var picked: Kind
	var wall_x := Fighter.ARENA_MAX_X if atk.facing > 0 else Fighter.ARENA_MIN_X
	var airborne_kill := vic.airborne or (killing_attack != null and killing_attack.launch > 0.0)
	var near_wall := absf(wall_x - vic.position.x) < WALL_RANGE
	var air_kind := air_kind_for(atk.style)
	var wall_kind := wall_kind_for(atk.style)
	# Situational finishers are likely, not guaranteed, so cornered KOs still vary.
	if airborne_kill and _last_played != air_kind and rng.randf() < AIR_SMASH_CHANCE:
		picked = air_kind
	elif near_wall and _last_played != wall_kind and rng.randf() < WALL_CRUSH_CHANCE:
		picked = wall_kind
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
	if _beats[0].get("hit", false):
		# An opening strike gets a short step-in first (there is no beat
		# before it to approach in), so it lands on contact, not on the end
		# of its own beat.
		_beats.push_front({"ticks": LEAD_IN_TICKS, "atk": &"guard"})
	_plan_meet()
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
	if beat.get("glide", false):
		_glide()
	if _pending.is_empty():
		var pushed := float(beat.get("def_move", 0.0))
		if beat.get("slam", false) and not _slammed:
			# Driven all the way into the wall within the beat, however far it is.
			var bound := Fighter.ARENA_MAX_X if _dir > 0 else Fighter.ARENA_MIN_X
			var left := maxi(int(beat["ticks"]) - _beat_tick - 2, 1)
			pushed = maxf(pushed, absf(bound - victim.position.x) / float(left) + 1.0)
		var before := victim.position.x
		_move(victim, pushed, false)
		if beat.get("slam", false):
			# The knee drives on: the attacker travels with the body.
			_move(attacker, absf(victim.position.x - before), true)
		if beat.get("slam", false) and not _slammed and pushed > 0.0 and _at_wall() \
				and absf(victim.position.x - before) < pushed - 0.5 and event.is_empty():
			event = _slam()
		if not _approach_next():
			_recover_spacing(beat)
	if not _pending.is_empty() and event.is_empty():
		event = _try_land()
	_beat_tick += 1
	return event


## Airborne finishers: retimes the victim's flight (a relaunch on the first
## beat) so that MEET_LEAD ticks into the "meet" beat their chest is at the
## height the attacker's striking limb will be at, on the attacker's own
## predicted jump arc. Both arcs use Fighter's shared gravity.
func _plan_meet() -> void:
	for i in _beats.size():
		if _beats[i].get("meet", false):
			_meet = i
			break
	if _meet < 0:
		return
	var t_meet := _sum_ticks(0, _meet) + MEET_LEAD
	# The attacker's launches, by the tick (1-based) of the beat that sets them.
	var launches := {}
	var start := 1
	for i in _meet + 1:
		if float(_beats[i].get("atk_vy", 0.0)) != 0.0:
			launches[start] = float(_beats[i]["atk_vy"])
		start += int(_beats[i]["ticks"])
	var atk_y: float = _predict(attacker.position.y, attacker.velocity_y, attacker.airborne, attacker.ground_y, launches, t_meet)[0]
	# Limb and chest heights above each root, from the authored poses.
	var limb_y := -100.0
	var chest_y := -110.0
	var meet_beat := _beats[_meet]
	var av := attacker.get_node_or_null("Visual") as FighterVisual
	var vv := victim.get_node_or_null("Visual") as FighterVisual
	if av != null:
		var pose: PackedFloat32Array = av._pose_library.get(StringName(meet_beat.get("atk", &"")), PackedFloat32Array())
		if pose.size() >= FighterVisual.CHANNELS:
			var j := av._solve_joints(pose)
			limb_y = j[_intended_limb(meet_beat, j)].y
	if vv != null:
		var vname := StringName(meet_beat.get("def_pre", _beats[0].get("def", &"knock_fly")))
		var vpose: PackedFloat32Array = vv._pose_library.get(vname, PackedFloat32Array())
		if vpose.size() >= FighterVisual.CHANNELS:
			var vj := vv._solve_joints(vpose)
			chest_y = lerpf(vj[FighterVisual.J_NECK].y, vj[FighterVisual.J_HIP].y, float(meet_beat.get("meet_at", MEET_CHEST)))
	var want := minf(atk_y + limb_y - chest_y, victim.ground_y - MEET_MIN_ALT)
	# The relaunch that puts the victim there, falling if it can.
	var best_vy := 0.0
	var best_score := INF
	var vy := MEET_VY_MIN
	while vy <= MEET_VY_MAX:
		var sim := _predict(victim.position.y, vy, true, victim.ground_y, {}, t_meet)
		if sim[2]:  # still in the air at the meeting
			var score := absf(float(sim[0]) - want) + (12.0 if float(sim[1]) < 0.0 else 0.0)
			if score < best_score:
				best_score = score
				best_vy = vy
		vy += 0.1
	if best_score < INF:
		_beats[0]["def_vy"] = best_vy


## [y, velocity, still airborne] after `ticks` director ticks: each tick a
## launch scheduled for it applies first, then gravity (Fighter._apply_motion).
static func _predict(y: float, vy: float, air: bool, ground: float, launches: Dictionary, ticks: int) -> Array:
	for t in range(1, ticks + 1):
		if launches.has(t):
			vy = launches[t]
			air = true
		if air:
			vy += CombatData.GRAVITY_RISE if vy < 0.0 else CombatData.GRAVITY_FALL
			y += vy
			if y >= ground:
				y = ground
				air = false
	return [y, vy, air]


## A "glide" beat: in the air, the attacker drifts toward the root gap at which
## the meeting blow's limb reaches the victim, arriving as it lands.
func _glide() -> void:
	if _meet < 0 or _index >= _meet:
		return
	var left := int(_beats[_index]["ticks"]) - _beat_tick + _sum_ticks(_index + 1, _meet) + MEET_LEAD
	var want := _authored_reach(_beats[_meet])
	if want <= 0.0:
		return
	var gap := (victim.position.x - attacker.position.x) * _dir
	var step := clampf((gap - want) / maxf(float(left), 1.0), -GLIDE_MAX, GLIDE_MAX)
	var limit := victim.position.x - REACH_MIN_GAP * _dir
	var x := attacker.position.x + step * _dir
	attacker.position.x = minf(x, limit) if _dir > 0 else maxf(x, limit)
	attacker.clamp_to_arena()


## The victim is up against the arena wall behind them.
func _at_wall() -> bool:
	var bound := Fighter.ARENA_MAX_X if _dir > 0 else Fighter.ARENA_MIN_X
	return absf(bound - victim.position.x) < AT_WALL


## A body driven into the wall by a push (no blow): the wall takes the impact.
func _slam() -> Dictionary:
	_slammed = true
	var at := victim.position + Vector2(0.0, -110.0)
	return {"pos": at, "power": 2, "final": false, "wall": true, "slam": true, "dir": _dir,
		"kind": CombatData.ImpactKind.STRAIGHT, "high": false, "style": &""}


## During the beat before a grounded blow: step in until the intended limb's
## authored strike would reach the victim's body. True while stepping in.
func _approach_next() -> bool:
	if _index + 1 >= _beats.size() or attacker.airborne or victim.is_down():
		return false
	var next := _beats[_index + 1]
	if not next.get("hit", false) or float(next.get("atk_vy", 0.0)) != 0.0:
		return false
	var want := _authored_reach(next)
	if want <= 0.0:
		return false
	var gap := (victim.position.x - attacker.position.x) * _dir
	if gap <= want + 0.5:
		return false
	attacker.position.x += minf(gap - want, APPROACH_STEP) * _dir
	attacker.clamp_to_arena()
	return true


## Root gap at which a beat's intended limb, in its authored strike pose,
## reaches APPROACH_DEPTH into the victim's body (0 if unknown).
func _authored_reach(beat: Dictionary) -> float:
	if beat.has("reach"):
		return float(beat["reach"])
	var av := attacker.get_node_or_null("Visual") as FighterVisual
	if av == null:
		return 0.0
	var pose: PackedFloat32Array = av._pose_library.get(StringName(beat.get("atk", &"")), PackedFloat32Array())
	if pose.size() < FighterVisual.CHANNELS:
		return 0.0
	var joints := av._solve_joints(pose)
	var limb := _intended_limb(beat, joints)
	var front := FighterVisual.BODY_HALF if beat.get("high", true) else FighterVisual.BODY_HALF + 2.0
	return maxf(absf(joints[limb].x) + front - APPROACH_DEPTH, REACH_MIN_GAP)


## The limb a blow is thrown with: the beat's "limb" (a FighterVisual.J_*
## joint), else whichever candidate (feet and knees for kicks, hands and
## elbows otherwise) the authored strike pose extends furthest from the body.
func _intended_limb(beat: Dictionary, joints: PackedVector2Array) -> int:
	if beat.has("limb"):
		return int(beat["limb"])
	var cands: Array[int] = [FighterVisual.J_HAND_F, FighterVisual.J_HAND_B, FighterVisual.J_ELBOW_F, FighterVisual.J_ELBOW_B]
	if StringName(beat.get("atk", &"")) in KICK_POSES:
		cands = [FighterVisual.J_FOOT_F, FighterVisual.J_FOOT_B, FighterVisual.J_KNEE_F, FighterVisual.J_KNEE_B]
	var best := cands[0]
	for c in cands:
		# Absolute reach: spinning kicks strike with a leg thrown out behind
		# the authored (unturned) pose.
		if absf(joints[c].x) > absf(joints[best].x):
			best = c
	return best


## After a lunge into a blow, the attacker steps back out to striking distance
## (a recoil step, never a snap) unless this beat drives forward on purpose.
func _recover_spacing(beat: Dictionary) -> void:
	if beat.get("hold_spacing", false) or float(beat.get("atk_move", 0.0)) > 0.0 or attacker.airborne or victim.is_down():
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
	var stepped := _pending_stepped
	_pending_stepped = false
	if g > CONTACT_SLOP:
		# Out of reach: the attacker carries forward into the blow (a lunge),
		# never through the victim's body; a limb that has already passed the
		# body (a victim leaning or doubled over toward the attacker) draws the
		# attacker back instead.
		var step := minf(g - CONTACT_SLOP * 0.5, REACH_ASSIST)
		var g_in: float = _strike_gap(_pending, step)[0]
		var g_out: float = _strike_gap(_pending, -step)[0]
		if g_out < g_in:
			step = -step
		if minf(g_in, g_out) >= g:
			step = 0.0
		_pending_stepped = step != 0.0
		if victim.airborne and victim.state == Fighter.State.FINISHED:
			# The falling body drifts into the blow (never through the floor).
			var dy := minf(g - CONTACT_SLOP * 0.5, AIR_ASSIST)
			var g_up: float = _strike_gap(_pending, 0.0, -dy)[0]
			var g_down: float = _strike_gap(_pending, 0.0, dy)[0]
			if minf(g_up, g_down) < g:
				var move := -dy if g_up < g_down else dy
				victim.position.y = minf(victim.position.y + move, victim.ground_y - 1.0)
				_pending_stepped = true
		var limit := victim.position.x - REACH_MIN_GAP * _dir
		var x := attacker.position.x + step * _dir
		attacker.position.x = minf(x, limit) if _dir > 0 else maxf(x, limit)
		attacker.clamp_to_arena()
	var arrived := g <= CONTACT_SLOP
	# Spinning and airborne blows swing away before they come round (or drop
	# from above), so they get longer to arrive and no closest-approach rule.
	# Inverted transitions can also momentarily recede while the supporting
	# palm settles. Their authored settle_contact beats use the same bound.
	var sweeping: bool = float(_pending.get("atk_spin", 0.0)) > 0.0 or _pending.get("atk_spin_hold", false) or _pending.get("settle_contact", false) or attacker.airborne
	# (A gap that grew only because the attacker was just repositioned is not
	# the limb going past.)
	var receding: bool = not sweeping and not stepped and _pending_ticks > 1 and g > _pending_gap + 0.5
	var wait := mini(IMPACT_MAX_WAIT_SWEEP, int(_pending["ticks"]) - 2) if sweeping else IMPACT_MAX_WAIT
	_pending_gap = minf(_pending_gap, g)
	# A thrust (strike_delay) only connects once extended, not as the limb
	# swings up past the body on its way out.
	if _pending_ticks <= int(_pending.get("strike_delay", 0)):
		return {}
	if arrived or receding or _pending_ticks >= wait:
		return _land(_pending)
	return {}


## Closest the attacker's striking limbs are to the victim's drawn body:
## [gap px past the outline (negative = overlapping), contact point, limb
## position]. Falls back
## to the space between the bodies before either has been drawn.
func _strike_gap(beat: Dictionary, shift: float = 0.0, vshift: float = 0.0) -> Array:
	var high: bool = beat.get("high", true)
	var fallback := (attacker.position + victim.position) * 0.5 + Vector2(0.0, -135.0 if high else -95.0)
	var av := attacker.get_node_or_null("Visual") as FighterVisual
	var vv := victim.get_node_or_null("Visual") as FighterVisual
	if av == null or vv == null or av._last_joints.size() < FighterVisual.JOINTS or vv._last_joints.size() < FighterVisual.JOINTS:
		# Not drawn yet: no drawn contact to measure (NAN, recorded as such in
		# contact_gaps); the blow resolves at the space between the bodies on
		# its timeout.
		return [NAN, fallback, fallback]
	var a := av._last_joints
	var v := vv._last_joints
	if vshift != 0.0:
		v = v.duplicate()
		for j in v.size():
			v[j].y += vshift
	var limbs: Array[Vector2] = []
	if _pending_limb >= 0:
		limbs = [a[_pending_limb] + Vector2(shift * _dir, 0.0)]
	elif StringName(beat.get("atk", &"")) in KICK_POSES:
		limbs = [a[FighterVisual.J_FOOT_F], a[FighterVisual.J_FOOT_B], a[FighterVisual.J_KNEE_F], a[FighterVisual.J_KNEE_B]]
	else:
		limbs = [a[FighterVisual.J_HAND_F], a[FighterVisual.J_HAND_B], a[FighterVisual.J_ELBOW_F], a[FighterVisual.J_ELBOW_B]]
	# Victim body as capsules: [from, to, radius]. "contact" narrows the target:
	# &"head" the head alone, &"body" the torso alone.
	var zone: StringName = beat.get("contact", &"")
	var parts: Array = []
	if zone != &"body":
		parts.append([v[FighterVisual.J_HEAD], v[FighterVisual.J_HEAD], HEAD_RADIUS])
	if zone != &"head":
		parts.append([v[FighterVisual.J_NECK], v[FighterVisual.J_HIP], BODY_RADIUS])
		if not high and zone != &"body":
			for leg in [[FighterVisual.J_KNEE_F, FighterVisual.J_FOOT_F], [FighterVisual.J_KNEE_B, FighterVisual.J_FOOT_B]]:
				parts.append([v[FighterVisual.J_HIP], v[leg[0]], 9.0])
				parts.append([v[leg[0]], v[leg[1]], 7.0])
	var best := INF
	var point := fallback
	var at := fallback
	for limb in limbs:
		for part in parts:
			var c := Geometry2D.get_closest_point_to_segment(limb, part[0], part[1])
			var d := limb.distance_to(c) - float(part[2]) - LIMB_RADIUS
			if d < best:
				best = d
				# On the body's surface, facing the limb.
				var out := (limb - c).normalized() if limb.distance_squared_to(c) > 0.01 else Vector2(-_dir, 0.0)
				point = c + out * float(part[2])
				at = limb
	return [best, point, at]


## Height of a point along the victim's drawn torso (0 neck, 1 hip).
func _torso_height(at: Vector2) -> float:
	var vv := victim.get_node_or_null("Visual") as FighterVisual
	if vv == null or vv._last_joints.size() < FighterVisual.JOINTS:
		return NAN
	var neck := vv._last_joints[FighterVisual.J_NECK]
	var hip := vv._last_joints[FighterVisual.J_HIP]
	var axis := hip - neck
	return (at - neck).dot(axis) / maxf(axis.length_squared(), 1.0)


## Resolves a blow: the victim reacts (or is knocked out) and the hit event goes
## out with the real contact point.
func _land(beat: Dictionary) -> Dictionary:
	var gap := _strike_gap(beat)
	_pending = {}
	contact_gaps.append(gap[0])
	contact_heights.append(_torso_height(gap[1]))
	return _resolve_hit(beat, gap[1])


func _start_beat(beat: Dictionary) -> Dictionary:
	_slammed = false
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
	if beat.has("def_pre"):
		victim.script_pose = beat["def_pre"]  # how they move as the blow comes in
	# The blow lands when the limb gets there (see _try_land), not on this tick.
	_pending = beat
	_pending_ticks = 0
	_pending_gap = INF
	_pending_limb = -1
	var av := attacker.get_node_or_null("Visual") as FighterVisual
	if av != null:
		var pose: PackedFloat32Array = av._pose_library.get(StringName(beat.get("atk", &"")), PackedFloat32Array())
		if pose.size() >= FighterVisual.CHANNELS:
			_pending_limb = _intended_limb(beat, av._solve_joints(pose))
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
	# A wall impact needs the body actually against the wall (Wall Crush keeps
	# its own timing).
	var wall: bool = beat.get("wall", false) and (_at_wall() or kind == Kind.WALL_CRUSH)
	return {"pos": contact, "power": beat.get("power", 1), "final": final, "wall": wall,
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
# the air), wall (impact is against the arena wall), atk_spin (turns this beat),
# atk_spin_hold (keep the turn), limb (FighterVisual.J_* the blow lands with;
# default: the authored pose's furthest-reaching hand/elbow or foot/knee),
# def_pre (victim pose as a blow comes in, before it lands), contact (&"head"
# or &"body": the only part of the victim the blow may land on),
# reach (root gap px for the step-in before a blow, where the authored pose
# misleads, e.g. a kick thrown mid-spin), meet (the airborne victim's flight is
# timed to meet this blow), glide (the attacker drifts in the air toward the
# meeting blow's range), slam (this beat's push drives the victim into the
# wall: an impact when they reach it), meet_at (where on the torso the meeting
# blow aims, 0 neck .. 1 hip; default MEET_CHEST), strike_delay (ticks into a
# strike before it can connect: a thrust lands extended, not on the way out).

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
				{"ticks": 18, "atk": &"kt_verdict_load", "def": &"stagger"},
				{"ticks": 18, "atk": &"kt_verdict_hit", "def": &"knock_fly", "hit": true, "power": 3, "final": true,
					"contact": &"body", "high": false, "limb": FighterVisual.J_HAND_B,
					"ko_vy": -8.0, "ko_drift": 18.0, "ko_rolls": 1, "ko_tumble": false},
				{"ticks": 12, "atk": &"kt_verdict_follow", "def": &"knock_fly"},
				{"ticks": 38, "atk": &"guard", "def": &"knock_fly"},
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
				{"ticks": 6, "atk": &"uppercut_strike", "def": &"hitstun_up", "def_pre": &"stagger", "hit": true, "power": 2,
					"atk_move": 0.5, "def_move": 1.0},
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
				{"ticks": 8, "atk": &"shook_hit", "def": &"hitstun", "hit": true, "power": 2, "atk_move": 1.0, "def_move": 1.2, "atk_spin": 0.6,
					"reach": 58.0},
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
		Kind.SKYLINE_VERDICT:
			# Karate: sink, push off into a high knee chamber turning side-on,
			# then the flying side kick, heel first, into the chest of the
			# falling victim (timed to meet it), rear knee tucked; the victim
			# is driven diagonally into the floor. Retract, land in the
			# knife-hand ready stance.
			return [
				{"ticks": 8, "atk": &"jump_squat", "def": &"air_tumble"},
				{"ticks": 11, "atk": &"flying_chamber", "def": &"air_tumble", "atk_vy": -15.0, "glide": true},
				{"ticks": 12, "atk": &"flying_side_kick", "def": &"knock_fly", "hit": true, "meet": true, "power": 3,
					"final": true, "meet_at": 0.33, "limb": FighterVisual.J_FOOT_F, "ko_vy": 9.0, "ko_drift": 12.0, "ko_rolls": 1},
				{"ticks": 8, "atk": &"flying_chamber", "def": &"knock_fly"},
				{"ticks": 45, "atk": &"kt_ready", "def": &"knock_fly"},
			]
		Kind.IRON_CORNER:
			# Muay Thai: plant, a driving body knee shoves the victim back into
			# the corner (the wall cracks as their back hits it), a rising knee
			# into the folded body, the elbow loads, and a horizontal elbow across
			# the jaw drops them down the wall. Step back, knee-up stance.
			return [
				{"ticks": 8, "atk": &"elbow_load", "def": &"stagger"},
				{"ticks": 12, "atk": &"fknee_hit", "def": &"hitstun_body", "hit": true, "high": false, "contact": &"body", "power": 2,
					"atk_move": 4.0, "def_move": 10.0, "slam": true},
				{"ticks": 8, "atk": &"knee", "def": &"hitstun_body", "hit": true, "high": false, "power": 2, "wall": true},
				{"ticks": 7, "atk": &"elbow_load", "def": &"hitstun_body"},
				{"ticks": 18, "atk": &"elbow_hit", "def": &"slumped", "hit": true, "power": 3, "final": true, "contact": &"head", "limb": FighterVisual.J_ELBOW_B,
					"ko_vy": -2.0, "ko_drift": 0.0, "wall": true},
				{"ticks": 22, "atk": &"guard", "def": &"slumped", "atk_move": -3.2},
				{"ticks": 30, "atk": &"mt_ready", "def": &"slumped"},
			]
		Kind.FALLING_CROSS:
			# Boxing (hands only): sink under the falling victim, a rising
			# uppercut into the body as they drop into range (timed to meet
			# it), then a step in and a short overhand cross down onto the
			# falling upper body drives them diagonally into the floor.
			return [
				{"ticks": 10, "atk": &"heavy_windup", "def": &"air_tumble"},
				{"ticks": 9, "atk": &"uppercut_strike", "def": &"hitstun_body", "hit": true, "meet": true, "high": false,
					"contact": &"body", "power": 2, "meet_at": 0.6},
				{"ticks": 18, "atk": &"overhand_hit", "def": &"knock_fly", "hit": true, "power": 3, "final": true,
					"atk_move": 1.5, "ko_vy": 9.0, "ko_drift": 10.0, "ko_rolls": 1},
				{"ticks": 45, "atk": &"guard", "def": &"knock_fly"},
			]
		Kind.CORNER_COUNT:
			# Boxing (hands only): a body hook drives the victim back into the
			# corner (the wall cracks as their back hits it), a lead hook turns
			# the head, a dip to load the right hand, then the straight right
			# through the chin; they slide down the wall. A composed step back.
			return [
				{"ticks": 8, "atk": &"rbody_load", "def": &"stagger"},
				{"ticks": 12, "atk": &"rbody_hit", "def": &"hitstun_body", "hit": true, "high": false, "contact": &"body",
					"power": 2, "atk_move": 3.0, "def_move": 9.0, "slam": true},
				{"ticks": 8, "atk": &"lhook_hit", "def": &"hitstun_hook", "hit": true, "contact": &"head", "power": 2, "wall": true},
				{"ticks": 7, "atk": &"heavy_windup", "def": &"hitstun_hook"},
				{"ticks": 18, "atk": &"heavy_strike", "def": &"slumped", "hit": true, "power": 3, "final": true,
					"ko_vy": -2.0, "ko_drift": 0.0, "wall": true},
				{"ticks": 22, "atk": &"guard", "def": &"slumped", "atk_move": -3.2},
				{"ticks": 30, "atk": &"guard", "def": &"slumped"},
			]
		Kind.AIR_BREAKER:
			# Kickboxing: jump in, a straight jumping punch to the falling
			# victim's head (timed to meet it), then, still airborne, a compact
			# roundhouse, shin to the ribs, knocks them sideways and down. Land
			# balanced in guard.
			return [
				{"ticks": 6, "atk": &"jump_squat", "def": &"air_tumble"},
				{"ticks": 9, "atk": &"air_punch_load", "def": &"air_tumble", "atk_vy": -14.0, "glide": true},
				{"ticks": 8, "atk": &"air_punch", "def": &"hitstun", "hit": true, "meet": true, "power": 2, "meet_at": 0.0,
					"def_vy": -3.0},
				{"ticks": 16, "atk": &"jrh_hit", "def": &"knock_fly", "hit": true, "power": 3, "final": true, "contact": &"body",
					"high": false, "ko_vy": 6.0, "ko_drift": 13.0, "ko_rolls": 1},
				{"ticks": 10, "atk": &"land_crouch", "def": &"knock_fly"},
				{"ticks": 35, "atk": &"guard", "def": &"knock_fly"},
			]
		Kind.CORNER_BREAKER:
			# Kickboxing: jab and cross to the body pin the victim to the wall
			# (it cracks as their back hits it), a low kick buckles the lead
			# leg so the head drops, then a high roundhouse to the dropped head;
			# they collapse down the wall. Punch-to-kick weight transfer.
			return [
				{"ticks": 7, "atk": &"jab_strike", "def": &"hitstun_body", "hit": true, "high": false, "contact": &"body",
					"atk_move": 3.0, "def_move": 9.0, "slam": true},
				{"ticks": 7, "atk": &"heavy_strike", "def": &"hitstun_body", "hit": true, "high": false, "contact": &"body",
					"power": 2, "wall": true},
				{"ticks": 9, "atk": &"lowrh_hit", "def": &"hitstun_leg", "hit": true, "high": false, "power": 2},
				{"ticks": 7, "atk": &"knee_windup", "def": &"hitstun_leg", "atk_move": -6.0},
				{"ticks": 18, "atk": &"high_extend", "def": &"slumped", "hit": true, "power": 3, "final": true,
					"strike_delay": 4, "reach": 110.0, "ko_vy": -2.0, "ko_drift": 0.0, "wall": true},
				{"ticks": 22, "atk": &"guard", "def": &"slumped", "atk_move": -3.2},
				{"ticks": 30, "atk": &"guard", "def": &"slumped"},
			]
		Kind.SKYFALL_AXE:
			# Taekwondo: hop, the straight leg swings up past the head as the
			# victim falls into range, then the heel chops straight down onto
			# the shoulder (timed to meet it) and spikes them into the floor.
			return [
				{"ticks": 6, "atk": &"jump_squat", "def": &"air_tumble"},
				{"ticks": 10, "atk": &"axe_raise", "def": &"air_tumble", "atk_vy": -11.0, "glide": true},
				{"ticks": 18, "atk": &"axe_chop", "def": &"knock_fly", "hit": true, "meet": true, "power": 3, "final": true,
					"contact": &"body", "meet_at": 0.0, "limb": FighterVisual.J_FOOT_F, "ko_vy": 14.0, "ko_drift": 3.0, "ko_rolls": 0},
				{"ticks": 12, "atk": &"land_crouch", "def": &"knock_fly"},
				{"ticks": 38, "atk": &"guard", "def": &"knock_fly"},
			]
		Kind.CORNER_CYCLONE:
			# Taekwondo: chamber, a body roundhouse drives the victim into the wall (it
			# cracks as their back hits it), recoil and turn on the planted
			# foot, the knee chambered over the shoulder, then the spinning
			# back kick, heel to the sternum; they slump down the wall. Turn
			# back round to face, re-chambered, feet re-planted.
			return [
				{"ticks": 6, "atk": &"knee_windup", "def": &"stagger"},
				{"ticks": 12, "atk": &"bodyrh_hit", "def": &"hitstun_body", "hit": true, "high": false, "contact": &"body",
					"power": 2, "atk_move": 3.0, "def_move": 9.0, "slam": true},
				{"ticks": 10, "atk": &"spin_windup", "def": &"hitstun", "atk_spin": 0.5},
				{"ticks": 4, "atk": &"back_chamber", "def": &"hitstun", "atk_spin_hold": true},
				{"ticks": 18, "atk": &"back_extend_high", "def": &"slumped", "hit": true, "power": 3, "final": true,
					"contact": &"body", "limb": FighterVisual.J_FOOT_B, "strike_delay": 3, "ko_vy": -2.0, "ko_drift": 0.0, "wall": true, "atk_spin_hold": true},
				{"ticks": 12, "atk": &"back_chamber", "def": &"slumped", "atk_spin": 0.5},
				{"ticks": 34, "atk": &"guard", "def": &"slumped", "atk_move": -2.0},
			]
		Kind.DESCENDING_DRAGON_PALM:
			# Kung Fu: the weight flows back with a circular wind-up, a rising
			# palm under the falling victim's chest (timed to meet it) lifts
			# them, then a leap and a downward hammer-palm onto the chest
			# drives them flat into the floor. Land on one leg, into the crane.
			return [
				{"ticks": 10, "atk": &"palm_windup", "def": &"air_tumble"},
				{"ticks": 9, "atk": &"palm_lead", "def": &"knock_fly", "hit": true, "meet": true, "power": 2, "contact": &"body",
					"meet_at": 0.4, "def_vy": -7.0},
				{"ticks": 8, "atk": &"jump_rise", "def": &"knock_fly", "atk_vy": -11.0, "atk_move": 2.0},
				{"ticks": 18, "atk": &"hammer_palm", "def": &"knock_fly", "hit": true, "power": 3, "final": true,
					"contact": &"body", "ko_vy": 14.0, "ko_drift": 2.0, "ko_rolls": 0},
				{"ticks": 12, "atk": &"land_crouch", "def": &"knock_fly"},
				{"ticks": 40, "atk": &"kf_crane", "def": &"knock_fly"},
			]
		Kind.WALL_OF_PALMS:
			# Kung Fu: three short alternating palms flowing into each other,
			# the first driving the victim back into the wall (it cracks as
			# their back hits it), a sink with both palms drawn to the hip,
			# then the double palm to the chest; they slide down the wall.
			# Close with the fist-in-palm salute.
			return [
				{"ticks": 6, "atk": &"palm_windup", "def": &"stagger"},
				{"ticks": 10, "atk": &"palm_lead", "def": &"hitstun_body", "hit": true, "contact": &"body", "power": 1,
					"atk_move": 3.0, "def_move": 9.0, "slam": true},
				{"ticks": 6, "atk": &"palm_rear", "def": &"hitstun_body", "hit": true, "contact": &"body", "power": 1, "wall": true},
				{"ticks": 6, "atk": &"palm_lead", "def": &"hitstun", "hit": true, "power": 2, "wall": true},
				{"ticks": 10, "atk": &"palm_windup", "def": &"stagger"},
				{"ticks": 18, "atk": &"palm_strike", "def": &"slumped", "hit": true, "power": 3, "final": true,
					"contact": &"body", "ko_vy": -2.0, "ko_drift": 0.0, "wall": true},
				{"ticks": 20, "atk": &"guard", "def": &"slumped", "atk_move": -3.0},
				{"ticks": 30, "atk": &"salute", "def": &"slumped"},
			]
		Kind.BANGLA_AIR_SMASH:
			# Bangla Maar (strikes only, no grab): a messy run-up and an
			# overconfident leap, both fists locked overhead, a reckless
			# double-hand hammer onto the falling victim (timed to meet it)
			# spikes them into the floor; the attacker lands heavily,
			# stumbles, then recovers.
			return [
				{"ticks": 8, "atk": &"hammer_windup", "def": &"air_tumble", "atk_move": 2.5},
				{"ticks": 10, "atk": &"hammer_raise", "def": &"air_tumble", "atk_vy": -13.0, "glide": true},
				{"ticks": 18, "atk": &"hammer_hit", "def": &"knock_fly", "hit": true, "meet": true, "power": 3, "final": true,
					"meet_at": 0.0, "ko_vy": 15.0, "ko_drift": 3.0, "ko_rolls": 0},
				{"ticks": 10, "atk": &"land_crouch", "def": &"knock_fly"},
				{"ticks": 14, "atk": &"stagger", "def": &"knock_fly", "atk_move": 1.0},
				{"ticks": 30, "atk": &"guard", "def": &"knock_fly"},
			]
		Kind.DEOWAL_DHAKKA:
			# Bangla Maar: brace, the Jor Dhakka shoulder charge slams the
			# victim into the wall (it cracks as their back hits it) and the
			# attacker staggers off the impact, a huge wind-up, then the giant
			# open-hand slap; the head spins along the wall and they drop.
			# A gloating glare to finish.
			return [
				{"ticks": 8, "atk": &"jd_brace", "def": &"stagger"},
				{"ticks": 12, "atk": &"jd_drive", "def": &"hitstun_body", "hit": true, "contact": &"body", "power": 2,
					"atk_move": 5.0, "def_move": 10.0, "slam": true},
				{"ticks": 8, "atk": &"jd_follow", "def": &"hitstun_body", "atk_move": -2.0},
				{"ticks": 9, "atk": &"mega_slap_wind", "def": &"stagger", "atk_move": -7.0},
				{"ticks": 18, "atk": &"mega_slap_hit", "def": &"slumped", "hit": true, "power": 3, "final": true,
					"contact": &"head", "ko_vy": -2.0, "ko_drift": 0.0, "wall": true},
				{"ticks": 16, "atk": &"mega_slap_follow", "def": &"slumped"},
				{"ticks": 34, "atk": &"glare", "def": &"slumped", "atk_move": -2.0},
			]
		Kind.RODAS_END:
			return [
				{"ticks": 8, "atk": &"cap_rasteira_load", "def": &"stagger"},
				{"ticks": 8, "atk": &"cap_rasteira_hit", "def": &"hitstun_leg", "hit": true, "high": false, "power": 2},
				{"ticks": 8, "atk": &"cap_armada_load", "def": &"stagger", "atk_spin": 0.5},
				{"ticks": 4, "atk": &"cap_armada_hit", "def": &"stagger", "atk_spin": 0.5},
				{"ticks": 18, "atk": &"cap_armada_hit", "def": &"knock_fly", "hit": true, "power": 3, "final": true,
					"contact": &"head", "ko_vy": -10.0, "ko_drift": 15.0, "ko_rolls": 1, "ko_tumble": true},
				{"ticks": 46, "atk": &"guard", "def": &"knock_fly"},
			]
		Kind.HANDSTAND_HAVOC:
			return [
				{"ticks": 10, "atk": &"cap_au_entry", "def": &"stagger"},
				{"ticks": 8, "atk": &"cap_au_support", "def": &"stagger"},
				{"ticks": 8, "atk": &"cap_au_hit", "def": &"hitstun_body", "hit": true, "high": false, "power": 2},
				# Shift the hands back a little: from where the first kick leaves the
				# body the second one swung over the back of the head and only met
				# it on its timeout (up to 10 px off at 30 / 120 fps).
				{"ticks": 8, "atk": &"cap_au_support", "def": &"stagger", "atk_move": -2.0},
				{"ticks": 8, "atk": &"cap_au_hit", "def": &"hitstun", "hit": true, "power": 2},
				{"ticks": 8, "atk": &"cap_au_support", "def": &"stagger"},
				{"ticks": 5, "atk": &"cap_au_hit", "def": &"stagger"},
				{"ticks": 18, "atk": &"cap_au_hit", "def": &"knock_fly", "hit": true, "power": 3, "final": true,
					"contact": &"body", "high": false, "ko_vy": -11.0, "ko_drift": 14.0, "ko_rolls": 1, "ko_tumble": true},
				{"ticks": 12, "atk": &"cap_au_exit", "def": &"knock_fly"},
				{"ticks": 38, "atk": &"guard", "def": &"knock_fly"},
			]
		Kind.SKY_WHEEL:
			return [
				{"ticks": 8, "atk": &"cap_au_entry", "def": &"air_tumble", "atk_move": 1.5},
				{"ticks": 9, "atk": &"cap_au_support", "def": &"air_tumble", "glide": true},
				{"ticks": 18, "atk": &"cap_au_hit", "def": &"knock_fly", "hit": true, "meet": true, "power": 3, "final": true,
					"meet_at": 0.25, "ko_vy": 7.0, "ko_drift": 13.0, "ko_rolls": 1},
				{"ticks": 12, "atk": &"cap_au_exit", "def": &"knock_fly"},
				{"ticks": 36, "atk": &"guard", "def": &"knock_fly"},
			]
		Kind.CORNER_CARNIVAL:
			return [
				{"ticks": 8, "atk": &"cap_crescent_hit", "def": &"hitstun_body", "hit": true, "high": false,
					"contact": &"body", "power": 2, "atk_move": 3.0, "def_move": 9.0, "slam": true},
				{"ticks": 9, "atk": &"cap_au_entry", "def": &"stagger"},
				{"ticks": 8, "atk": &"cap_au_support", "def": &"stagger"},
				{"ticks": 14, "atk": &"cap_au_hit", "def": &"hitstun", "hit": true, "power": 2, "wall": true,
					"settle_contact": true},
				{"ticks": 9, "atk": &"cap_armada_load", "def": &"stagger", "atk_spin": 0.5},
				{"ticks": 7, "atk": &"cap_armada_hit", "def": &"stagger", "atk_spin": 0.5},
				{"ticks": 18, "atk": &"cap_armada_hit", "def": &"slumped", "hit": true, "power": 3, "final": true,
					"contact": &"head", "ko_vy": -2.0, "ko_drift": 0.0, "wall": true},
				{"ticks": 22, "atk": &"guard", "def": &"slumped", "atk_move": -3.0},
				{"ticks": 30, "atk": &"guard", "def": &"slumped"},
			]
		Kind.ONE_INCH_ENDING:
			return [
				{"ticks": 8, "atk": &"jkd_lead_hit", "def": &"hitstun_body", "hit": true, "high": false, "power": 2},
				{"ticks": 10, "atk": &"jkd_inch_set", "def": &"stagger", "hold_spacing": true},
				{"ticks": 18, "atk": &"jkd_inch_load", "def": &"stagger", "hold_spacing": true},
				{"ticks": 18, "atk": &"jkd_inch_hit", "def": &"knock_fly", "hit": true, "power": 3, "final": true,
					"contact": &"body", "high": false, "hold_spacing": true, "limb": FighterVisual.J_HAND_F,
					"ko_vy": -6.5, "ko_drift": 19.0, "ko_rolls": 1, "ko_tumble": false},
				{"ticks": 12, "atk": &"jkd_inch_follow", "def": &"knock_fly", "hold_spacing": true},
				{"ticks": 36, "atk": &"guard", "def": &"knock_fly"},
			]
		Kind.NO_SECOND_CHANCE:
			return [
				{"ticks": 8, "atk": &"jkd_stop_hit", "def": &"hitstun_leg", "hit": true, "high": false},
				{"ticks": 7, "atk": &"deflect", "def": &"stagger"},
				{"ticks": 7, "atk": &"jkd_lead_hit", "def": &"hitstun", "hit": true, "power": 2},
				{"ticks": 9, "atk": &"jkd_side_load", "def": &"stagger"},
				{"ticks": 18, "atk": &"jkd_side_hit", "def": &"knock_fly", "hit": true, "power": 3, "final": true,
					"contact": &"body", "high": false, "ko_vy": -9.0, "ko_drift": 16.0, "ko_rolls": 1, "ko_tumble": true},
				{"ticks": 46, "atk": &"guard", "def": &"knock_fly"},
			]
		Kind.DRAGON_INTERCEPT:
			return [
				{"ticks": 7, "atk": &"jump_squat", "def": &"air_tumble"},
				{"ticks": 10, "atk": &"jkd_side_load", "def": &"air_tumble", "atk_vy": -12.0, "glide": true},
				{"ticks": 18, "atk": &"jkd_side_hit", "def": &"knock_fly", "hit": true, "meet": true, "power": 3, "final": true,
					"contact": &"body", "high": false, "meet_at": 0.3, "ko_vy": 7.0, "ko_drift": 13.0, "ko_rolls": 1},
				{"ticks": 12, "atk": &"land_crouch", "def": &"knock_fly"},
				{"ticks": 36, "atk": &"guard", "def": &"knock_fly"},
			]
		Kind.END_OF_LINE:
			return [
				{"ticks": 7, "atk": &"jkd_lead_hit", "def": &"hitstun_body", "hit": true, "high": false,
					"contact": &"body", "atk_move": 3.0, "def_move": 9.0, "slam": true},
				{"ticks": 7, "atk": &"jkd_cross_hit", "def": &"hitstun_body", "hit": true, "high": false, "power": 2, "wall": true},
				{"ticks": 7, "atk": &"deflect", "def": &"stagger"},
				{"ticks": 9, "atk": &"jkd_side_load", "def": &"stagger"},
				{"ticks": 18, "atk": &"jkd_side_hit", "def": &"slumped", "hit": true, "power": 3, "final": true,
					"contact": &"body", "high": false, "ko_vy": -2.0, "ko_drift": 0.0, "wall": true},
				{"ticks": 22, "atk": &"guard", "def": &"slumped", "atk_move": -3.0},
				{"ticks": 30, "atk": &"guard", "def": &"slumped"},
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
