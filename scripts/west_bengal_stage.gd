class_name WestBengalStage
extends Node2D
## The Kolkata street stage (WB-01..05): only when the PLAYER fights as Bangla
## Maar (main.gd picks it; a Bangla Maar rival alone does not, training stays
## in the dojo). Drawing only: arena bounds, floor height and collision are
## the dojo's.
##
## Layers, back to front: the painted backdrop (Howrah Bridge or Victoria
## Memorial, picked per match) and the two walls (tea stall left, shopfront
## right: what fighters get pinned against) are drawn by the arena's _draw
## through draw_back(), with the battle-damage decals over them; then this
## node's children: the cheering placard crowds standing BEHIND the parapet
## (only heads, shoulders and placards show over it), the parapet strip
## redrawn over their lower bodies, the rickshaw and the breakable props on
## the street; then the fighters.

const DIR := "res://assets/art/backgrounds/west_bengal_v2/"
const BACKDROPS := {&"howrah": "howrah_backdrop.png", &"victoria": "victoria_backdrop.png"}
## Backdrop street edge (pixel row) per variant, and the uniform scale that
## covers the arena's full camera extent (1680 x 1120 world px).
const EDGE_ROW := {&"howrah": 699.0, &"victoria": 698.0}
const BACKDROP_SCALE: float = 1.09375
const LEFT: float = -200.0
## Visible heights (px) of the stage pieces, measured on their alpha bounds.
const STALL_HEIGHT: float = 330.0
const SHOP_HEIGHT: float = 350.0
const RICKSHAW_HEIGHT: float = 185.0
const CROWD_HEIGHT: float = 145.0
## The parapet: its top edge (backdrop pixel row) and where the crowds stand
## behind it (their feet hidden). A slight dusk haze keeps them in the back.
const PARAPET_TOP_ROW: float = 504.0
const CROWD_FEET_Y: float = 405.0
const CROWD_TINT := Color(0.82, 0.76, 0.74)
## Where the walls sit: each piece's inner edge lines up with the arena bound
## (plus the old pillar's 20 px), so a body pinned there is against it.
const WALL_INSET: float = 20.0
## Props and the rickshaw stand on the paving just in front of the wall
## (slightly below the wall's foot, as real objects would), each with a soft
## contact shadow.
const REAR_Y: float = 572.0
const RICKSHAW_Y: float = 576.0
const SHADOW := Color(0.05, 0.04, 0.04, 0.35)
## Pixels at least this opaque count as the object (soft fringes do not).
const SOLID_ALPHA: float = 0.5
## Crowd groups: [id, centre x, loop durations in ms (from the art manifest)].
const CROWDS: Array = [
	[&"maar_sala", 250.0, [240, 180, 260, 200]],
	[&"jio_pagla", 640.0, [250, 190, 280, 220]],
	[&"khela_hobe", 1030.0, [260, 200, 300, 240]],
]
## Breakable props: id, atlas row, centre x, visible height, the impact
## strength (px/tick of a landing body, or a wall slam) that breaks it, and
## what it stands on (another prop's id, or the floor).
const PROP_ROWS := {&"cups": Rect2i(0, 0, 768, 370), &"crate": Rect2i(0, 370, 768, 305), &"bench": Rect2i(0, 675, 768, 349)}
const PROPS: Array = [
	{"id": &"bench", "x": 320.0, "h": 82.0, "breaks_at": 9.0, "on": &""},
	{"id": &"cups", "x": 312.0, "h": 44.0, "breaks_at": 4.0, "on": &"bench"},
	{"id": &"crate", "x": 165.0, "h": 62.0, "breaks_at": 7.0, "on": &""},
]
## How close (px, horizontally) an impact must be to reach a prop.
const PROP_REACH: float = 60.0
const CLAY := Color(0.72, 0.4, 0.25)
const WOOD := Color(0.48, 0.34, 0.22)
## The sunset light on the fighters per backdrop (FighterVisual.set_scene_light).
const LIGHTS := {
	&"howrah": {"ambient": [1.0, 0.9, 0.86], "key": [1.0, 0.74, 0.58], "key_dir": [-0.3, -0.95], "key_strength": 0.32,
		"shadow": [0.16, 0.1, 0.1, 0.36], "shadow_shift": 6.0, "shadow_stretch": 1.1},
	&"victoria": {"ambient": [1.0, 0.88, 0.8], "key": [1.0, 0.72, 0.5], "key_dir": [-0.8, -0.6], "key_strength": 0.38,
		"shadow": [0.18, 0.1, 0.06, 0.4], "shadow_shift": 14.0, "shadow_stretch": 1.25},
}

var variant: StringName = &"howrah"
var _backdrop: Texture2D = null
var _stall: Texture2D = null
var _shop_sheet: Texture2D = null
var _props_tex: Texture2D = null
## Visible (alpha) source regions of the cut-outs.
var _stall_src := Rect2()
var _shop_src := Rect2()
var _rickshaw_src := Rect2()
## Per prop: {id, intact: Rect2 source, broken: Rect2 source, rect: Rect2
## world (intact), broken_rect: Rect2 world, broken: bool}.
var props: Array[Dictionary] = []
var _crowds: Array[Dictionary] = []
## Draws the parapet strip, rickshaw and props over the crowds.
var _front: Node2D = null
var _floor_y: float = 560.0
var _time_ms: float = 0.0
## Set by the arena: called when a prop breaks (redraw, debris, sound).
var on_prop_broken: Callable = Callable()


func setup(which: StringName, floor_y: float = 560.0) -> void:
	_floor_y = floor_y
	variant = which if BACKDROPS.has(which) else &"howrah"
	_backdrop = load(DIR + BACKDROPS[variant])
	_stall = load(DIR + "tea_stall.png")
	_shop_sheet = load(DIR + "shopfront_rickshaw.png")
	_props_tex = load(DIR + "breakable_props.png")
	_stall_src = _visible(_stall, Rect2i(0, 0, _stall.get_width(), _stall.get_height()))
	_shop_src = _visible(_shop_sheet, Rect2i(0, 0, 910, _shop_sheet.get_height()))
	_rickshaw_src = _visible(_shop_sheet, Rect2i(910, 0, _shop_sheet.get_width() - 910, _shop_sheet.get_height()))
	_build_props()
	_build_crowds()
	if _front == null:
		_front = Node2D.new()
		_front.name = "Front"
		_front.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_front.draw.connect(_draw_front)
		add_child(_front)
	move_child(_front, -1)
	_front.queue_redraw()


## The solid part of a texture region: the bounds of its pixels at least
## SOLID_ALPHA opaque (faint fringes and glows would leave legs floating).
static func _visible(tex: Texture2D, region: Rect2i) -> Rect2:
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var sub := img.get_region(region)
	var lo := Vector2i(sub.get_width(), sub.get_height())
	var hi := Vector2i(-1, -1)
	for y in range(0, sub.get_height(), 2):
		for x in range(0, sub.get_width(), 2):
			if sub.get_pixel(x, y).a >= SOLID_ALPHA:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x + 1), maxi(hi.y, y + 1))
	if hi.x < 0:
		return Rect2(Vector2(region.position), Vector2(region.size))
	return Rect2(Vector2(region.position + lo), Vector2(hi - lo))


func _build_props() -> void:
	props.clear()
	var tops := {}
	for p: Dictionary in PROPS:
		var row: Rect2i = PROP_ROWS[p["id"]]
		var intact := _visible(_props_tex, row)
		var broken := _visible(_props_tex, Rect2i(row.position.x + 768, row.position.y, 768, row.size.y))
		var k: float = float(p["h"]) / intact.size.y
		var base_y: float = tops.get(p["on"], REAR_Y)
		var rect := Rect2(float(p["x"]) - intact.size.x * k * 0.5, base_y - intact.size.y * k, intact.size.x * k, intact.size.y * k)
		# The broken pile shares the intact one's scale and baseline.
		var broken_rect := Rect2(float(p["x"]) - broken.size.x * k * 0.5, base_y - broken.size.y * k, broken.size.x * k, broken.size.y * k)
		# What can stand on it: the bench's seat (below its backrest), else its top.
		tops[p["id"]] = rect.position.y + rect.size.y * (0.58 if p["id"] == &"bench" else 0.06)
		props.append({"id": p["id"], "intact": intact, "broken_src": broken, "rect": rect, "broken_rect": broken_rect,
			"breaks_at": p["breaks_at"], "on": p["on"], "broken": false})


func _build_crowds() -> void:
	for c in _crowds:
		(c["sprite"] as Sprite2D).queue_free()
	_crowds.clear()
	for spec in CROWDS:
		var tex: Texture2D = load(DIR + "audience/animation_v2/%s_sheet.png" % spec[0])
		var s := Sprite2D.new()
		s.texture = tex
		s.hframes = 4
		s.centered = false
		# Foot anchor (256, 480) of a 512 px frame; a group is ~420 px tall
		# with its placard.
		var k := CROWD_HEIGHT / 420.0
		s.scale = Vector2(k, k)
		s.position = Vector2(float(spec[1]) - 256.0 * k, CROWD_FEET_Y - 480.0 * k)
		s.modulate = CROWD_TINT
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(s)
		var durations: Array = spec[2]
		var total := 0
		for d in durations:
			total += int(d)
		_crowds.append({"sprite": s, "durations": durations, "total": total})


func _process(delta: float) -> void:
	_time_ms += delta * 1000.0
	for c in _crowds:
		var t := fmod(_time_ms, float(c["total"]))
		var frame := 0
		for d in c["durations"]:
			if t < float(d):
				break
			t -= float(d)
			frame += 1
		(c["sprite"] as Sprite2D).frame = mini(frame, 3)


## The arena's back layers (called from its _draw, under the decals): the
## backdrop, the walls (stall and shopfront), the rickshaw and the props.
func draw_back(c: CanvasItem, floor_y: float) -> void:
	var top := floor_y - float(EDGE_ROW[variant]) * BACKDROP_SCALE
	c.draw_texture_rect(_backdrop, Rect2(LEFT, top, _backdrop.get_width() * BACKDROP_SCALE,
		_backdrop.get_height() * BACKDROP_SCALE), false)
	var walls := wall_rects(floor_y)
	c.draw_texture_rect_region(_stall, walls[0], _stall_src)
	c.draw_texture_rect_region(_shop_sheet, walls[1], _shop_src)


## Over the crowds: the parapet strip (from the backdrop itself, between the
## two walls) hiding their lower bodies, then the rickshaw and the props.
func _draw_front() -> void:
	var c := _front
	var top := _floor_y - float(EDGE_ROW[variant]) * BACKDROP_SCALE
	var walls := wall_rects(_floor_y)
	var x0 := walls[0].end.x - 4.0
	var x1 := walls[1].position.x + 4.0
	var y0 := top + PARAPET_TOP_ROW * BACKDROP_SCALE
	var src := Rect2((x0 - LEFT) / BACKDROP_SCALE, PARAPET_TOP_ROW, (x1 - x0) / BACKDROP_SCALE,
		float(EDGE_ROW[variant]) - PARAPET_TOP_ROW)
	c.draw_texture_rect_region(_backdrop, Rect2(x0, y0, x1 - x0, _floor_y - y0), src)
	# Rickshaw parked on the street beside the shop, about a person's height.
	var rk := RICKSHAW_HEIGHT / _rickshaw_src.size.y
	var rsize := _rickshaw_src.size * rk
	var rrect := Rect2(Vector2(walls[1].position.x - 8.0 - rsize.x, RICKSHAW_Y - rsize.y), rsize)
	_shadow(c, Vector2(rrect.get_center().x, RICKSHAW_Y - 1.0), rsize.x * 0.48)
	c.draw_texture_rect_region(_shop_sheet, rrect, _rickshaw_src)
	for p in props:
		if p["on"] == &"":
			var pr: Rect2 = p["broken_rect"] if p["broken"] else p["rect"]
			_shadow(c, Vector2(pr.get_center().x, pr.end.y - 1.0), pr.size.x * 0.52)
	for p in props:
		if p["broken"]:
			c.draw_texture_rect_region(_props_tex, p["broken_rect"], p["broken_src"])
		else:
			c.draw_texture_rect_region(_props_tex, p["rect"], p["intact"])


## A soft contact shadow on the paving (a flattened, layered ellipse).
static func _shadow(c: CanvasItem, at: Vector2, half_width: float) -> void:
	for i in 4:
		var k := 1.0 - i * 0.2
		var pts := PackedVector2Array()
		for j in 24:
			var a := TAU * j / 24.0
			pts.append(at + Vector2(cos(a) * half_width * k, sin(a) * 6.0 * k))
		c.draw_colored_polygon(pts, Color(SHADOW, SHADOW.a * 0.3))


func fighter_light() -> Dictionary:
	return LIGHTS.get(variant, {})


## World rects of the two walls: [tea stall (left), shopfront (right)].
func wall_rects(floor_y: float) -> Array[Rect2]:
	var sk := STALL_HEIGHT / _stall_src.size.y
	var stall_size := _stall_src.size * sk
	var left_edge := Fighter.ARENA_MIN_X - WALL_INSET
	var hk := SHOP_HEIGHT / _shop_src.size.y
	var shop_size := _shop_src.size * hk
	var right_edge := Fighter.ARENA_MAX_X + WALL_INSET
	return [Rect2(Vector2(left_edge - stall_size.x, floor_y + 6.0 - stall_size.y), stall_size),
		Rect2(Vector2(right_edge, floor_y + 6.0 - shop_size.y), shop_size)]


## An impact at `x` (a body landing at `strength` px/tick, or a wall slam):
## nearby props that are strong enough to break, break (once each). Returns
## the props broken.
func impact(x: float, strength: float) -> Array[Dictionary]:
	var hit: Array[Dictionary] = []
	for p in props:
		if p["broken"] or strength < float(p["breaks_at"]):
			continue
		var r: Rect2 = p["rect"]
		if absf(r.get_center().x - x) > PROP_REACH + r.size.x * 0.5:
			continue
		p["broken"] = true
		hit.append(p)
		# What stood on it falls with it.
		for q in props:
			if q["on"] == p["id"] and not q["broken"]:
				q["broken"] = true
				hit.append(q)
	for p in hit:
		if on_prop_broken.is_valid():
			on_prop_broken.call(p)
	if not hit.is_empty() and _front != null:
		_front.queue_redraw()
	return hit


## Fresh props (a new match; rounds keep their battle damage).
func reset_props() -> void:
	for p in props:
		p["broken"] = false
	if _front != null:
		_front.queue_redraw()


## Debris colour for a prop's material.
static func prop_color(id: StringName) -> Color:
	return CLAY if id == &"cups" else WOOD
