class_name MartialArtStyle
extends Resource
## One martial art: identity, look, legal moveset, combo graph and AI hints.
## Pure data (one .tres per style in res://styles/), registered by
## StyleRegistry. The Fighter is the single gate that enforces it: a fighter
## with a style can only ever start moves listed here (player input, AI
## intents, combos and air attacks alike).
##
## Input slots (keyboard -> slot; the style maps slot -> move id):
##   light J · heavy K · technique L
##   up_light W+J · up_heavy W+K · down_light S+J · down_heavy S+K
##   power_light Space+J · power_heavy Space+K (a chord: either order within
##   CombatData.POWER_CHORD_WINDOW ticks; ground only)
## W / S are read at the moment J / K is pressed. A and D only move and dash:
## they never change which attack a button performs.
## A variant slot with no entry falls back to its base slot (SLOT_FALLBACK).
## `air_map` uses the same slots for attacks started in the air.

const SLOTS: Array[StringName] = [&"light", &"heavy", &"technique",
	&"up_light", &"up_heavy", &"down_light", &"down_heavy", &"power_light", &"power_heavy", &"x_move"]
const POWER_SLOTS: Array[StringName] = [&"power_light", &"power_heavy"]
const SLOT_FALLBACK: Dictionary = {
	&"up_light": &"light", &"down_light": &"light",
	&"up_heavy": &"heavy", &"down_heavy": &"heavy",
}
## Key labels for each slot (move lists in the UI).
const SLOT_KEYS: Dictionary = {
	&"light": "J", &"heavy": "K", &"technique": "L",
	&"up_light": "W+J", &"up_heavy": "W+K", &"down_light": "S+J", &"down_heavy": "S+K",
	&"power_light": "Space+J", &"power_heavy": "Space+K", &"x_move": "X",
}
## Known combat categories (metadata for the roster and future subsystems).
const CATEGORIES: Array[StringName] = [&"striking", &"kicking", &"sweeping", &"clinching",
	&"grappling", &"throwing", &"ground", &"hybrid"]

## Permanent id (never change it once released: saves refer to it).
@export var id: StringName = &""
## Position in the selection roster.
@export var order: int = 0
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: StringName = &"striking"
@export_range(1, 5) var difficulty: int = 2
@export var strengths: PackedStringArray = PackedStringArray()
@export var weaknesses: PackedStringArray = PackedStringArray()
## Guard / idle / footwork: an index into Stances.Kind.
@export var stance: int = 0
## Character outfit (FighterVisual): &"boxing", &"muay_thai", &"karate",
## &"kung_fu", &"taekwondo", &"kickboxing", or the plain &"gi" silhouette
## (belt, headband, wrist wraps). Presentation only.
@export var kit: StringName = &"gi"
## Footwork: scales how far this style's strikes step in (CombatData.STEP_IN).
@export var step_scale: float = 1.0
## Style footwork and voluntary jump travel. These never scale knockback.
@export_range(0.5, 1.6) var movement_scale: float = 1.0
@export_range(0.5, 1.6) var jump_travel_scale: float = 1.0
## Directional voluntary jumps use this style's rolling crossover presentation.
@export var rolling_jump: bool = false
## Rival AI tuning for this style (EnemyAI property -> value), e.g. a boxer's
## pressure and head movement. Applied on top of the AI's defaults.
@export var ai_tuning: Dictionary = {}
## Display names for this style's moves where it calls a shared move something
## else (move id -> name, e.g. karate's jab is its "Straight Punch").
@export var move_names: Dictionary = {}
## slot -> move id, on the ground and in the air.
@export var input_map: Dictionary = {}
@export var air_map: Dictionary = {}
## move id -> Array of move ids it may cancel into (on contact).
@export var chains: Dictionary = {}
## AI: combo plans (arrays of move ids) up close and from range.
@export var ai_close_plans: Array = []
@export var ai_far_plans: Array = []
@export var ai_preferred_range: float = 95.0
## The style's own open-floor finishers (FinisherDirector ids).
@export var finishers: PackedStringArray = PackedStringArray()
## The style's airborne finisher (an airborne or launching kill) and wall
## finisher (victim near the wall behind them), FinisherDirector ids. Empty =
## the shared Air Smash / Wall Crush.
@export var air_finisher: StringName = &""
@export var wall_finisher: StringName = &""
## Wall Crush strikes in this style (5 pose names: windup, entry strike into
## the wall, pinning strike, final windup, final blow). Empty = the shared
## default (flying knee, cross, double palm).
@export var wall_entry: PackedStringArray = PackedStringArray()
## Speech bubbles (presentation): event -> line, or a list of lines said in
## rotation. Events: match_start, slap,
## hurt, block, miss_heavy, low_health, finisher, victory, knocked_out (see
## main.gd SPEECH_*).
## Empty = this style's fighters never speak.
@export var quotes: Dictionary = {}
const QUOTE_EVENTS: Array[String] = ["match_start", "slap", "hurt", "block", "miss_heavy", "low_health", "finisher",
	"victory", "knocked_out"]
## Pre-fight gesture (a FighterVisual pose name) held before the guard goes up.
## Empty = the shared salute (player) / glare (rival).
@export var intro_pose: StringName = &""
## Signature technique (move id of a "signature" attack): F at full Focus.
@export var signature: StringName = &""

var _allowed: Dictionary = {}


## The move a slot performs for this style (NONE if the style has none).
func resolve(slot: StringName, in_air: bool) -> CombatData.AttackType:
	var table := air_map if in_air else input_map
	var move_id: StringName = table.get(slot, &"")
	if move_id == &"" and SLOT_FALLBACK.has(slot):
		move_id = table.get(SLOT_FALLBACK[slot], &"")
	return CombatData.type_for_id(move_id) if move_id != &"" else CombatData.AttackType.NONE


## Every move this style can perform.
func allows(type: CombatData.AttackType) -> bool:
	if _allowed.is_empty():
		for m in moves():
			_allowed[CombatData.type_for_id(m)] = true
		if signature != &"":
			_allowed[CombatData.type_for_id(signature)] = true
		# A mapped sequence's own strikes (only ever started by that sequence).
		for t in _allowed.keys():
			for sub in CombatData.get_attack(t).sequence:
				_allowed[CombatData.type_for_id(sub)] = true
	return _allowed.has(type)


func moves() -> Array[StringName]:
	var out: Array[StringName] = []
	for table in [input_map, air_map]:
		for m in table.values():
			if not out.has(m):
				out.append(m)
	return out


func can_chain(from: CombatData.AttackType, to: CombatData.AttackType) -> bool:
	var from_id := CombatData.id_for_type(from)
	var next: Array = chains.get(from_id, [])
	# A mapped automatic combination exposes its cancel routes from its last
	# strike, while plans and move lists refer to the mapped parent.
	if next.is_empty():
		for parent_id in moves():
			var sequence := CombatData.get_attack(CombatData.type_for_id(parent_id)).sequence
			if not sequence.is_empty() and sequence.back() == from_id:
				next = chains.get(parent_id, [])
				break
	return CombatData.id_for_type(to) in next


## AI plans as move types (illegal ids are dropped, validate() reports them).
func plans(close: bool) -> Array:
	var out: Array = []
	for plan in (ai_close_plans if close else ai_far_plans):
		var types: Array = []
		for m in plan:
			var t := CombatData.type_for_id(m)
			if allows(t):
				types.append(t)
		if not types.is_empty():
			out.append(types)
	return out


## Problems with this definition (empty = valid). Malformed styles are refused
## by StyleRegistry, so bad data can never reach a match.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"":
		errors.append("missing id")
	if display_name == "":
		errors.append("missing display_name")
	if not category in CATEGORIES:
		errors.append("unknown category %s" % category)
	if stance < 0 or stance >= Stances.count():
		errors.append("stance %d out of range" % stance)
	if input_map.is_empty():
		errors.append("empty input_map")
	for table in [input_map, air_map]:
		for slot in table:
			if not slot in SLOTS:
				errors.append("unknown slot %s" % slot)
			if CombatData.type_for_id(table[slot]) == CombatData.AttackType.NONE:
				errors.append("unknown move %s" % table[slot])
			elif CombatData.get_attack(CombatData.type_for_id(table[slot])).x_strike:
				errors.append("sequence child %s cannot be mapped to a key" % table[slot])
	for slot in air_map:
		if slot in POWER_SLOTS:
			errors.append("power slot %s is a ground chord, not an air slot" % slot)
		var t := CombatData.type_for_id(air_map[slot])
		if t != CombatData.AttackType.NONE and not CombatData.get_attack(t).air_only:
			errors.append("air move %s is not an air attack" % air_map[slot])
	for slot in input_map:
		var t := CombatData.type_for_id(input_map[slot])
		if t != CombatData.AttackType.NONE and CombatData.get_attack(t).air_only:
			errors.append("ground slot %s maps to air-only move %s" % [slot, input_map[slot]])
	var mine := moves()
	for from in chains:
		if not from in mine:
			errors.append("chain from %s, not in the moveset" % from)
		for to in chains[from]:
			if not to in mine:
				errors.append("chain %s -> %s leaves the moveset" % [from, to])
	if signature != &"":
		var st := CombatData.type_for_id(signature)
		if st == CombatData.AttackType.NONE or not CombatData.get_attack(st).signature:
			errors.append("signature %s is not a signature technique" % signature)
		else:
			for sub in CombatData.get_attack(st).sequence:
				if CombatData.type_for_id(sub) == CombatData.AttackType.NONE:
					errors.append("signature sequence uses unknown move %s" % sub)
	for m in moves():
		var mt := CombatData.type_for_id(m)
		if mt != CombatData.AttackType.NONE and CombatData.get_attack(mt).signature:
			errors.append("signature %s must not be mapped to a key" % m)
		if mt != CombatData.AttackType.NONE:
			for sub in CombatData.get_attack(mt).sequence:
				if CombatData.type_for_id(sub) == CombatData.AttackType.NONE:
					errors.append("sequence %s uses unknown move %s" % [m, sub])
	for event in quotes:
		if not String(event) in QUOTE_EVENTS:
			errors.append("unknown speech event %s" % event)
		var line: Variant = quotes[event]
		if not (line is String or (line is Array and not (line as Array).is_empty())):
			errors.append("speech event %s needs a line or a list of lines" % event)
	if not wall_entry.is_empty() and wall_entry.size() != 5:
		errors.append("wall_entry needs 5 poses (got %d)" % wall_entry.size())
	for fid in finishers:
		var fk := FinisherDirector.kind_for_id(fid)
		if fk < 0:
			errors.append("unknown finisher %s" % fid)
		elif fk in FinisherDirector.ENVIRONMENTAL:
			errors.append("finisher %s is environmental (shared), not a style finisher" % fid)
	if air_finisher != &"" and not FinisherDirector.kind_for_id(air_finisher) in FinisherDirector.AIR_KINDS:
		errors.append("air_finisher %s is not an airborne finisher" % air_finisher)
	if wall_finisher != &"" and not FinisherDirector.kind_for_id(wall_finisher) in FinisherDirector.WALL_KINDS:
		errors.append("wall_finisher %s is not a wall finisher" % wall_finisher)
	for plan in ai_close_plans + ai_far_plans:
		for i in plan.size():
			if not plan[i] in mine:
				errors.append("AI plan uses %s, not in the moveset" % plan[i])
			elif i > 0 and not plan[i] in chains.get(plan[i - 1], []):
				errors.append("AI plan %s -> %s is not a chain" % [plan[i - 1], plan[i]])
	return errors


## This style has Space + J / Space + K power moves.
func has_power() -> bool:
	for slot in POWER_SLOTS:
		if input_map.has(slot):
			return true
	return false


## A move's name in this style (its own name for a shared move, if it has one).
func move_name(move_id: StringName) -> String:
	if move_names.has(move_id):
		return move_names[move_id]
	return CombatData.get_attack(CombatData.type_for_id(move_id)).display_name


## Move list for the UI: [key label, move name] per mapped slot.
func move_list() -> Array:
	var out: Array = []
	for slot in SLOTS:
		if input_map.has(slot):
			out.append([SLOT_KEYS[slot], move_name(input_map[slot])])
	# Air moves grouped by move: "air J/K/L" -> Jump Punch.
	var air_keys: Dictionary = {}
	for slot in SLOTS:
		if air_map.has(slot):
			var label := move_name(air_map[slot])
			if not air_keys.has(label):
				air_keys[label] = []
			air_keys[label].append(SLOT_KEYS[slot])
	for label in air_keys:
		out.append(["air " + "/".join(air_keys[label]), label])
	return out
