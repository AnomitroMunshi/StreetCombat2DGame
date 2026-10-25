class_name StyleRegistry
extends RefCounted
## All martial-art styles, loaded from res://styles/*.tres and validated.
## Adding a style = adding a .tres (plus any new moves it uses); nothing in the
## match code switches on style names.
##
## The player's chosen style and whether the next scene load is a rematch
## (skip the selection screen) live here as statics, so they survive the scene
## reload that restarts a match.

const STYLE_DIR := "res://styles/"
const DEFAULT_ID := &"kickboxing"

static var player_choice: StringName = &""
## Next load goes straight to PRE_MATCH with the same style (REMATCH / R).
static var skip_selection: bool = false

static var _styles: Array[MartialArtStyle] = []
static var _rejected: PackedStringArray = PackedStringArray()
static var _loaded: bool = false


## Every valid style, in roster order.
static func all() -> Array[MartialArtStyle]:
	if not _loaded:
		_load()
	return _styles


static func by_id(style_id: StringName) -> MartialArtStyle:
	for s in all():
		if s.id == style_id:
			return s
	return null


static func count() -> int:
	return all().size()


## Kickboxing (the all-rounder) when registered, otherwise the first style.
static func default_style() -> MartialArtStyle:
	var s := by_id(DEFAULT_ID)
	return s if s != null else all()[0]


static func player_style() -> MartialArtStyle:
	var s := by_id(player_choice)
	return s if s != null else default_style()


## A style for the rival: never the player's, when there is a choice.
static func random_except(excluded: StringName, rng: RandomNumberGenerator) -> MartialArtStyle:
	var options: Array[MartialArtStyle] = []
	for s in all():
		if s.id != excluded:
			options.append(s)
	if options.is_empty():
		return by_id(excluded)
	return options[rng.randi_range(0, options.size() - 1)]


## Files that failed validation (with reasons), for tests and debugging.
static func rejected() -> PackedStringArray:
	if not _loaded:
		_load()
	return _rejected


static func _load() -> void:
	_loaded = true
	_styles.clear()
	_rejected.clear()
	var dir := DirAccess.open(STYLE_DIR)
	if dir == null:
		push_error("StyleRegistry: no %s directory" % STYLE_DIR)
		return
	var ids := {}
	for file in dir.get_files():
		# Exported builds list converted resources as *.tres.remap.
		var name := file.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var res := load(STYLE_DIR + name)
		var style := res as MartialArtStyle
		if style == null:
			_rejected.append("%s: not a MartialArtStyle" % name)
			continue
		var errors := style.validate()
		if ids.has(style.id):
			errors.append("duplicate id %s" % style.id)
		if not errors.is_empty():
			_rejected.append("%s: %s" % [name, ", ".join(errors)])
			push_warning("StyleRegistry: rejected %s (%s)" % [name, ", ".join(errors)])
			continue
		ids[style.id] = true
		_styles.append(style)
	_styles.sort_custom(func(a: MartialArtStyle, b: MartialArtStyle) -> bool: return a.order < b.order)
