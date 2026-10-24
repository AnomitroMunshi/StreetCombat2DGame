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

enum Kind { PALM_FLURRY, SPINNING_HEEL, AIR_SMASH, WALL_CRUSH, TORNADO_KICK }

const DISPLAY_NAMES: Dictionary = {
	Kind.PALM_FLURRY: "PALM FLURRY",
	Kind.SPINNING_HEEL: "SPINNING HEEL KICK",
	Kind.AIR_SMASH: "AIR SMASH",
	Kind.WALL_CRUSH: "WALL CRUSH",
	Kind.TORNADO_KICK: "TORNADO KICK 360",
}
## Finishers picked at random on open floor.
const OPEN_FLOOR_KINDS: Array[Kind] = [Kind.PALM_FLURRY, Kind.SPINNING_HEEL, Kind.TORNADO_KICK]
## Victim this close to the wall behind them -> Wall Crush.
const WALL_RANGE: float = 170.0
## Chance to use the situational finisher when it applies.
const AIR_SMASH_CHANCE: float = 0.7
const WALL_CRUSH_CHANCE: float = 0.6
## The attacker never steps closer than this to the victim.
const MIN_GAP: float = 50.0

## Last finisher played. Static, so it survives scene reloads (restarts) and the
## same finisher is never chosen twice in a row.
static var _last_played: int = -1

var kind: Kind = Kind.PALM_FLURRY
var attacker: Fighter = null
var victim: Fighter = null
var done: bool = false

var _beats: Array[Dictionary] = []
var _index: int = -1
var _beat_tick: int = 0
var _dir: int = 1


## Picks the finisher that fits the situation, otherwise a random one, never
## repeating the previous finisher.
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
		var pool: Array[Kind] = []
		for k in OPEN_FLOOR_KINDS:
			if k != _last_played:
				pool.append(k)
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
	_beats = _build(kind)


func get_display_name() -> String:
	return DISPLAY_NAMES[kind]


## Advances one tick. Returns {} or a hit event:
## {"pos": Vector2, "power": int, "final": bool}
func tick() -> Dictionary:
	if done:
		return {}
	var event: Dictionary = {}
	if _index < 0 or _beat_tick >= int(_beats[_index]["ticks"]):
		_index += 1
		_beat_tick = 0
		if _index >= _beats.size():
			done = true
			attacker.end_scripted()
			return {}
		event = _start_beat(_beats[_index])
	var beat := _beats[_index]
	_move(attacker, beat.get("atk_move", 0.0), true)
	_move(victim, beat.get("def_move", 0.0), false)
	_beat_tick += 1
	return event


func _start_beat(beat: Dictionary) -> Dictionary:
	if beat.has("atk"):
		attacker.script_pose = beat["atk"]
	attacker.script_flip = beat.get("atk_flip", false)
	# atk_spin = full turns about the vertical axis spread over this beat.
	attacker.script_spin_rate = float(beat.get("atk_spin", 0.0)) / maxf(float(beat["ticks"]), 1.0)
	if beat.has("def"):
		victim.script_pose = beat["def"]
	if beat.has("atk_vy"):
		attacker.scripted_launch(beat["atk_vy"])
	if beat.has("def_vy"):
		victim.scripted_launch(beat["def_vy"])
	if not beat.get("hit", false):
		return {}
	var high: bool = beat.get("high", true)
	var contact := (attacker.position + victim.position) * 0.5 + Vector2(0.0, -135.0 if high else -95.0)
	var final: bool = beat.get("final", false)
	if final:
		victim.finish_ko(_dir, beat["ko_vy"], beat["ko_drift"], beat.get("ko_rolls", 0), beat.get("ko_tumble", false))
	else:
		victim.scripted_hit(high)
	return {"pos": contact, "power": beat.get("power", 1), "final": final, "wall": beat.get("wall", false),
		"dir": _dir}


func _move(fighter: Fighter, speed: float, is_attacker: bool) -> void:
	if is_zero_approx(speed):
		return
	var x := fighter.position.x + speed * _dir
	if is_attacker:
		# Close in, but never step into or through the victim.
		var limit := victim.position.x - MIN_GAP * _dir
		x = minf(x, limit) if _dir > 0 else maxf(x, limit)
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
			# Flying knee into the wall, cross to pin, double palm strike; the
			# wall cracks and the victim slumps against it.
			return [
				{"ticks": 8, "atk": &"knee_windup", "def": &"stagger"},
				{"ticks": 8, "atk": &"knee", "def": &"stagger", "atk_vy": -5.0, "atk_move": 7.0},
				{"ticks": 8, "atk": &"knee", "def": &"hitstun_body", "hit": true, "high": false, "power": 2, "def_move": 9.0, "atk_move": 5.0, "wall": true},
				{"ticks": 9, "atk": &"heavy_strike", "def": &"hitstun", "hit": true, "power": 2, "atk_move": 1.0, "wall": true},
				{"ticks": 10, "atk": &"palm_windup", "def": &"stagger"},
				{"ticks": 20, "atk": &"palm_strike", "def": &"slumped", "hit": true, "power": 3, "final": true, "ko_vy": -2.0, "ko_drift": 0.0, "wall": true},
				{"ticks": 45, "atk": &"guard", "def": &"slumped"},
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
			"ko_vy": -10.0, "ko_drift": 16.0, "ko_rolls": 2, "ko_tumble": true},
		{"ticks": 55, "atk": &"guard", "def": &"knock_fly"},
	]
