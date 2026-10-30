class_name StyleStage
extends Node2D
## Painted style arenas use the same collision plane and bounds as the dojo.
## Art, damage materials and breakable props are presentation data only.

const ART_DIR := "res://assets/art/backgrounds/style_arenas_v1/"
const LAYOUT_FILE := ART_DIR + "layout.json"
const DOJO_PROPS := "res://assets/art/backgrounds/dojo_props_v1/breakable_props.png"
## Props stand on the floor just in front of the wall (px below the floor line).
const PROP_BASE: float = 8.0
const VIEW := Rect2(-200, -200, 1680, 1120)
const PROFILES := {
	&"boxing": {"name": "boxing_gym", "floor": &"rubber", "wall": &"plaster"},
	&"muay_thai": {"name": "thai_training_camp", "floor": &"wood", "wall": &"wood"},
	&"karate": {"name": "dojo", "floor": &"wood", "wall": &"wood"},
	&"kung_fu": {"name": "kung_fu_courtyard", "floor": &"stone", "wall": &"plaster"},
	&"taekwondo": {"name": "korean_dojang", "floor": &"rubber", "wall": &"plaster"},
	&"kickboxing": {"name": "kickboxing_gym", "floor": &"rubber", "wall": &"plaster"},
	&"capoeira": {"name": "capoeira_roda", "floor": &"stone", "wall": &"plaster"},
	&"jeet_kune_do": {"name": "hong_kong_rooftop", "floor": &"concrete", "wall": &"concrete"},
}
const DECAL_DIRS := {
	&"wood": "res://assets/art/decals/dojo_wood_v2",
	&"rubber": "res://assets/art/decals/gym_rubber_v1",
	&"stone": "res://assets/art/decals/courtyard_stone_v1",
	&"concrete": "res://assets/art/decals/rooftop_concrete_v1",
}
const COLORS := {
	&"wood": [Color(0.54, 0.37, 0.20), Color(0.28, 0.18, 0.10)],
	&"rubber": [Color(0.24, 0.27, 0.29), Color(0.10, 0.12, 0.14)],
	&"stone": [Color(0.57, 0.53, 0.46), Color(0.30, 0.28, 0.25)],
	&"concrete": [Color(0.56, 0.56, 0.53), Color(0.28, 0.29, 0.28)],
	&"plaster": [Color(0.75, 0.67, 0.53), Color(0.36, 0.30, 0.24)],
}

var style_id: StringName = &"karate"
var props: Array[Dictionary] = []
var on_prop_broken: Callable = Callable()
var _floor_y := 560.0
var _backdrop: Texture2D
var _backdrop_rect := VIEW
var _props_texture: Texture2D
var _front: Node2D
var _layout: Dictionary = {}
var _cutout_texture: Texture2D
var _cutouts: Array[Dictionary] = []
static var _prop_region_cache: Dictionary = {}
static var _cutout_region_cache: Dictionary = {}

func setup(which: StringName, floor_y: float = 560.0) -> void:
	style_id = which if PROFILES.has(which) else &"karate"
	_floor_y = floor_y
	if FileAccess.file_exists(LAYOUT_FILE):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_FILE))
		if data is Dictionary: _layout = data.get(String(style_id), {})
	var path := ART_DIR + String(style_id) + "_backdrop.png"
	if not is_dojo() and ResourceLoader.exists(path):
		_backdrop = load(path)
		var size := _backdrop.get_size()
		var edge := clampf(float(_layout.get("floor_edge_row", 699.0)), 1, size.y - 1)
		# Fit each side of the floor anchor independently; a width-only scale
		# can expose an unpainted strip during the finisher camera zoom-out.
		var scale := maxf(VIEW.size.x / size.x, maxf((_floor_y - VIEW.position.y) / edge, (VIEW.end.y - _floor_y) / (size.y - edge)))
		_backdrop_rect = Rect2(Vector2(640 - size.x * scale * 0.5, _floor_y - edge * scale), size * scale)
	_build_cutouts()
	_build_props()
	if _front == null:
		_front = Node2D.new()
		_front.name = "BreakableProps"
		_front.draw.connect(_draw_props)
		add_child(_front)
	_front.queue_redraw()

func is_dojo() -> bool:
	return style_id == &"karate"

func get_stage_name() -> String:
	return PROFILES[style_id]["name"]

func floor_material() -> StringName:
	return StringName(_layout.get("floor_material", PROFILES[style_id]["floor"]))

func wall_material() -> StringName:
	return StringName(_layout.get("wall_material", PROFILES[style_id]["wall"]))

func decal_directory() -> String:
	return DECAL_DIRS.get(floor_material(), DECAL_DIRS[&"wood"])

func floor_main() -> Color:
	return COLORS[floor_material()][0]

func floor_second() -> Color:
	return COLORS[floor_material()][1]

func wall_light() -> Color:
	return COLORS[wall_material()][0]

func wall_dark() -> Color:
	return COLORS[wall_material()][1]

func backdrop_rect() -> Rect2:
	return _backdrop_rect

func has_backdrop() -> bool:
	return _backdrop != null

## Independent left/right object layers, rather than scenery baked into the
## backdrop. The returned rectangles use the same inner faces as the arena.
func cutout_layers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for layer in _cutouts:
		out.append({"side": layer["side"], "source": layer["source"], "rect": _cutout_rect(layer, _floor_y)})
	return out

func _build_cutouts() -> void:
	_cutouts.clear()
	_cutout_texture = null
	if is_dojo(): return
	var path := String(_layout.get("cutouts", String(style_id) + "_cutouts.png"))
	if not path.begins_with("res://"): path = ART_DIR + path
	if not ResourceLoader.exists(path): return
	_cutout_texture = load(path)
	var size := _cutout_texture.get_size()
	var split := clampi(int(_layout.get("cutout_split_x", size.x * 0.5)), 1, int(size.x) - 1)
	var cache_key := "%s:%d" % [path, split]
	if not _cutout_region_cache.has(cache_key):
		var image := _cutout_texture.get_image()
		if image.is_compressed(): image.decompress()
		_cutout_region_cache[cache_key] = [
			_alpha_bounds(image, Rect2i(0, 0, split, int(size.y))),
			_alpha_bounds(image, Rect2i(split, 0, int(size.x) - split, int(size.y))),
		]
	var regions: Array = _cutout_region_cache[cache_key]
	var heights: Array = _layout.get("cutout_heights", [300.0, 320.0])
	for index in 2:
		_cutouts.append({"side": -1 if index == 0 else 1, "source": regions[index], "height": maxf(float(heights[index]), 1.0)})

func _cutout_rect(layer: Dictionary, floor_y: float) -> Rect2:
	var source: Rect2 = layer["source"]
	var scale: float = float(layer["height"]) / maxf(source.size.y, 1.0)
	var size := source.size * scale
	var x := Fighter.ARENA_MIN_X - 20.0 - size.x if int(layer["side"]) < 0 else Fighter.ARENA_MAX_X + 20.0
	return Rect2(Vector2(x, floor_y + 6.0 - size.y), size)

func draw_back(c: CanvasItem, floor_y: float) -> void:
	if _backdrop != null:
		c.draw_texture_rect(_backdrop, _backdrop_rect, false)
	else:
		DojoStage.draw(c, floor_y)
	if _cutouts.size() == 2:
		for layer in _cutouts:
			c.draw_texture_rect_region(_cutout_texture, _cutout_rect(layer, floor_y), layer["source"])
	else:
		# Safe development fallback while cutout artwork is being imported.
		for rect in wall_rects(floor_y):
			c.draw_rect(rect, wall_dark())
			c.draw_rect(Rect2(rect.position, Vector2(4, rect.size.y)), wall_light().darkened(0.2))

func wall_rects(floor_y: float) -> Array[Rect2]:
	if _cutouts.size() == 2:
		return [_cutout_rect(_cutouts[0], floor_y), _cutout_rect(_cutouts[1], floor_y)]
	return [Rect2(Fighter.ARENA_MIN_X - 66, 96, 46, floor_y - 90), Rect2(Fighter.ARENA_MAX_X + 20, 96, 46, floor_y - 90)]

func _build_props() -> void:
	props.clear()
	# Each atlas is independent of the backdrop, with intact/broken pairs.
	var path := String(_layout.get("props", DOJO_PROPS if is_dojo() else ""))
	if path == "" or not ResourceLoader.exists(path): return
	_props_texture = load(path)
	var size := _props_texture.get_size()
	var cuts: Array = _layout.get("props_rows", [0, 380, 690, 1024] if path == DOJO_PROPS and size.y == 1024 else [0, int(size.y / 3), int(size.y * 2 / 3), int(size.y)])
	var cache_key := path + str(cuts)
	if not _prop_region_cache.has(cache_key):
		var image := _props_texture.get_image()
		if image.is_compressed(): image.decompress()
		var regions: Array = []
		var width := image.get_width() / 2
		for row in 3:
			var y0 := int(cuts[row])
			var height := int(cuts[row + 1]) - y0
			regions.append([_alpha_bounds(image, Rect2i(0, y0, width, height)), _alpha_bounds(image, Rect2i(width, y0, width, height))])
		_prop_region_cache[cache_key] = regions
	var sources: Array = _prop_region_cache[cache_key]
	# [id, centre x, visible height, impact that breaks it, debris colour]: spread
	# along the back wall, clear of each other, the pot in the left corner and
	# the boards and bench apart on the right.
	var specs := [[&"pot", 170.0, 58.0, 8.0, Color(0.55, 0.32, 0.16)], [&"boards", 900.0, 54.0, 10.0, Color(0.60, 0.40, 0.20)], [&"bench", 1100.0, 64.0, 12.0, Color(0.48, 0.31, 0.17)]]
	for row in 3:
		var intact: Rect2 = sources[row][0]
		var broken: Rect2 = sources[row][1]
		var k: float = float(specs[row][2]) / intact.size.y
		var base := _floor_y + PROP_BASE
		var x: float = specs[row][1]
		props.append({"id": specs[row][0], "intact": intact, "broken_src": broken,
			"rect": Rect2(Vector2(x - intact.size.x * k * 0.5, base - intact.size.y * k), intact.size * k),
			"broken_rect": Rect2(Vector2(x - broken.size.x * k * 0.5, base - broken.size.y * k), broken.size * k),
			"broken": false, "breaks_at": specs[row][3], "color": specs[row][4]})

static func _alpha_bounds(image: Image, region: Rect2i) -> Rect2:
	var lo := region.end
	var hi := region.position
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if image.get_pixel(x, y).a >= 0.15:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x + 1), maxi(hi.y, y + 1))
	return Rect2(Vector2(lo), Vector2(hi - lo)) if hi.x > lo.x and hi.y > lo.y else Rect2(region)

func _draw_props() -> void:
	for p in props:
		# A soft contact shadow on the floor grounds each prop.
		var pr: Rect2 = p["broken_rect"] if p["broken"] else p["rect"]
		for i in 4:
			var k := 1.0 - i * 0.2
			var pts := PackedVector2Array()
			for j in 24:
				var a := TAU * j / 24.0
				pts.append(Vector2(pr.get_center().x + cos(a) * pr.size.x * 0.52 * k, pr.end.y - 1.0 + sin(a) * 6.0 * k))
			_front.draw_colored_polygon(pts, Color(0.05, 0.04, 0.04, 0.1))
	for p in props:
		_front.draw_texture_rect_region(_props_texture, p["broken_rect"] if p["broken"] else p["rect"], p["broken_src"] if p["broken"] else p["intact"])

func impact(x: float, strength: float) -> Array[Dictionary]:
	var hit: Array[Dictionary] = []
	for p in props:
		var rect: Rect2 = p["rect"]
		if p["broken"] or strength < float(p["breaks_at"]) or absf(rect.get_center().x - x) > 42 + rect.size.x * 0.5: continue
		p["broken"] = true
		hit.append(p)
		if on_prop_broken.is_valid(): on_prop_broken.call(p)
	if not hit.is_empty(): _front.queue_redraw()
	return hit

func reset_props() -> void:
	for p in props: p["broken"] = false
	if _front != null: _front.queue_redraw()
