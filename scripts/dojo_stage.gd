class_name DojoStage
extends RefCounted
## The training dojo backdrop (drawing only; no collision): distant courtyard
## glimpsed through shoji paper, the rear wall, low-contrast corner props, the
## floor and a restrained foreground. Drawn in world space by the arena's
## _draw, oversized to the camera's full zoom/shake/result extents
## (main.VIEW_MIN..VIEW_MAX) so no edge ever shows.
##
## Readability rules (BG-01): the band behind the fighters' heads and bodies
## (MID_TOP..floor) is a plain warm mid-tone with no strong lines, so dark
## (navy/slate/black) and white costumes both stand out; the strongest
## contrast and saturation stay on the fighters. The floor line (FLOOR_Y)
## never moves.

const LEFT: float = -200.0
const WIDTH: float = 1680.0
const TOP: float = -200.0
const BOTTOM: float = 920.0
## Ceiling beam, shoji window band, rail and the plain mid-wall below it.
const BEAM_Y: float = 96.0
const SHOJI_TOP: float = 128.0
const SHOJI_BOTTOM: float = 318.0
const RAIL_Y: float = 326.0
const MID_TOP: float = 340.0
const SKIRT_Y: float = 544.0
## Window bays: posts every BAY px; the middle bay holds the banner.
const BAY: float = 320.0
const POST_W: float = 16.0

const CEILING := Color(0.11, 0.09, 0.08)
const BEAM := Color(0.15, 0.115, 0.095)
const UPPER_WALL := Color(0.27, 0.22, 0.18)
const POST := Color(0.2, 0.155, 0.125)
const PAPER := Color(0.45, 0.39, 0.31)
const LATTICE := Color(0.3, 0.24, 0.19)
const BAMBOO := Color(0.25, 0.27, 0.2)
## Plain plaster behind the fighters (luminance ~0.36: between the dark
## costumes and the white gi).
const PLASTER := Color(0.44, 0.37, 0.29)
const SKIRT := Color(0.3, 0.235, 0.18)
const FLOOR := Color(0.4, 0.31, 0.22)
const MAT := Color(0.46, 0.37, 0.27)
const FLOOR_EDGE := Color(0.62, 0.5, 0.37)
const LIGHT := Color(1.0, 0.85, 0.6)
const PROP := Color(0.3, 0.235, 0.18)
const FOREGROUND := Color(0.06, 0.045, 0.04)


static func draw(c: CanvasItem, floor_y: float) -> void:
	_wall(c, floor_y)
	_props(c, floor_y)
	_floor(c, floor_y)
	_foreground(c)


static func _wall(c: CanvasItem, floor_y: float) -> void:
	c.draw_rect(Rect2(LEFT, TOP, WIDTH, BOTTOM - TOP), UPPER_WALL)
	c.draw_rect(Rect2(LEFT, TOP, WIDTH, BEAM_Y - TOP), CEILING)
	c.draw_rect(Rect2(LEFT, BEAM_Y, WIDTH, 18.0), BEAM)
	# Shoji bays, lit from the left: wide paper panes with a sparse lattice
	# and the courtyard's bamboo as soft shadows on the paper.
	var x := 640.0 - BAY * 3.5
	while x < LEFT + WIDTH:
		var pane := Rect2(x + POST_W, SHOJI_TOP, BAY - POST_W, SHOJI_BOTTOM - SHOJI_TOP)
		var lit := clampf(1.1 - (pane.get_center().x / 1280.0) * 0.25, 0.82, 1.1)
		c.draw_rect(pane, Color(PAPER.r * lit, PAPER.g * lit, PAPER.b * lit))
		for k in 5:
			var bx := pane.position.x + fposmod(pane.position.x * 0.37 + k * 61.0, pane.size.x)
			c.draw_line(Vector2(bx, pane.position.y), Vector2(bx + 6.0, pane.end.y), Color(BAMBOO, 0.18), 5.0, true)
			c.draw_line(Vector2(bx - 2.0, pane.position.y + 40.0 + k * 23.0), Vector2(bx + 22.0, pane.position.y + 30.0 + k * 23.0),
				Color(BAMBOO, 0.14), 3.0, true)
		for i in range(1, 3):
			var gx := pane.position.x + pane.size.x * i / 3.0
			c.draw_line(Vector2(gx, pane.position.y), Vector2(gx, pane.end.y), LATTICE, 3.0)
		var gy := pane.position.y + pane.size.y * 0.5
		c.draw_line(Vector2(pane.position.x, gy), Vector2(pane.end.x, gy), LATTICE, 3.0)
		c.draw_rect(pane, LATTICE, false, 4.0)
		c.draw_rect(Rect2(x, BEAM_Y + 18.0, POST_W, RAIL_Y - BEAM_Y - 18.0), POST)
		x += BAY
	c.draw_rect(Rect2(LEFT, SHOJI_BOTTOM, WIDTH, RAIL_Y - SHOJI_BOTTOM), BEAM)
	c.draw_rect(Rect2(LEFT, RAIL_Y, WIDTH, MID_TOP - RAIL_Y), POST)
	# The plain band behind the fighters, a warm light pool in the middle and
	# the side light falling off toward the right.
	c.draw_rect(Rect2(LEFT, MID_TOP, WIDTH, floor_y - MID_TOP), PLASTER)
	_glow(c, Vector2(600.0, 450.0), Vector2(620.0, 150.0), 0.16)
	c.draw_rect(Rect2(900.0, MID_TOP, LEFT + WIDTH - 900.0, floor_y - MID_TOP), Color(0.0, 0.0, 0.0, 0.05))
	c.draw_rect(Rect2(1150.0, MID_TOP, LEFT + WIDTH - 1150.0, floor_y - MID_TOP), Color(0.0, 0.0, 0.0, 0.05))
	c.draw_rect(Rect2(LEFT, SKIRT_Y, WIDTH, floor_y - SKIRT_Y), SKIRT)


## Low-contrast rear-plane props at the corners (future prop anchors): a
## weapon rack on the left, a taiko drum on the right. Kept dim so they never
## compete with the fighters standing in front of them.
static func _props(c: CanvasItem, floor_y: float) -> void:
	var rack := Rect2(150.0, 380.0, 92.0, floor_y - 380.0)
	c.draw_rect(Rect2(rack.position.x, rack.position.y + 22.0, rack.size.x, 7.0), Color(PROP, 0.75))
	c.draw_rect(Rect2(rack.position.x, rack.position.y + 92.0, rack.size.x, 7.0), Color(PROP, 0.75))
	for i in 2:
		c.draw_rect(Rect2(rack.position.x + i * (rack.size.x - 8.0), rack.position.y, 8.0, rack.size.y), Color(PROP, 0.8))
	for i in 4:
		var sx := rack.position.x + 18.0 + i * 18.0
		c.draw_line(Vector2(sx, rack.position.y - 18.0 + i * 4.0), Vector2(sx + 2.0, floor_y - 6.0), Color(PROP, 0.65), 4.0, true)
	# Taiko drum seen side-on: a barrel body on a low stand.
	var drum := Vector2(1080.0, floor_y - 70.0)
	c.draw_line(drum + Vector2(-34.0, 26.0), drum + Vector2(-42.0, 70.0), Color(PROP, 0.8), 6.0, true)
	c.draw_line(drum + Vector2(34.0, 26.0), drum + Vector2(42.0, 70.0), Color(PROP, 0.8), 6.0, true)
	var body := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		body.append(drum + Vector2(-46.0 + t * 92.0, -34.0 - sin(t * PI) * 6.0))
	for i in 13:
		var t := float(i) / 12.0
		body.append(drum + Vector2(46.0 - t * 92.0, 34.0 + sin(t * PI) * 6.0))
	c.draw_colored_polygon(body, Color(PROP, 0.85))
	c.draw_rect(Rect2(drum + Vector2(-50.0, -36.0), Vector2(6.0, 72.0)), Color(0.55, 0.47, 0.36, 0.6))
	c.draw_rect(Rect2(drum + Vector2(44.0, -36.0), Vector2(6.0, 72.0)), Color(0.55, 0.47, 0.36, 0.6))
	c.draw_line(drum + Vector2(-44.0, 0.0), drum + Vector2(44.0, 0.0), Color(0.0, 0.0, 0.0, 0.2), 3.0, true)


static func _floor(c: CanvasItem, floor_y: float) -> void:
	c.draw_rect(Rect2(LEFT, floor_y, WIDTH, BOTTOM - floor_y), FLOOR)
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(150.0, floor_y), Vector2(1130.0, floor_y), Vector2(1250.0, 780.0), Vector2(30.0, 780.0)]), MAT)
	# Boards run toward the back wall (converging), seams widen toward us.
	var vanish := Vector2(640.0, floor_y - 260.0)
	var bx := -1000.0
	while bx <= 2280.0:
		var top := Vector2(640.0 + (bx - 640.0) * 0.45, floor_y)
		var dir := (top - vanish).normalized()
		c.draw_line(top, top + dir * ((BOTTOM - floor_y) / maxf(dir.y, 0.2)), Color(0.0, 0.0, 0.0, 0.1), 2.0, true)
		bx += 120.0
	var seam := floor_y + 12.0
	var gap := 12.0
	while seam < BOTTOM:
		c.draw_line(Vector2(LEFT, seam), Vector2(LEFT + WIDTH, seam), Color(0.0, 0.0, 0.0, 0.12), 2.0)
		gap *= 1.45
		seam += gap
	_glow(c, Vector2(620.0, floor_y + 70.0), Vector2(520.0, 70.0), 0.14)
	c.draw_line(Vector2(LEFT, floor_y), Vector2(LEFT + WIDTH, floor_y), FLOOR_EDGE, 3.0)


## Out-of-focus shapes in the very bottom corners, well below the feet: depth
## without hiding any part of a fighter.
static func _foreground(c: CanvasItem) -> void:
	_ellipse(c, Vector2(-120.0, 860.0), Vector2(260.0, 120.0), Color(FOREGROUND, 0.55))
	_ellipse(c, Vector2(1400.0, 870.0), Vector2(270.0, 125.0), Color(FOREGROUND, 0.55))


## A soft round light: many faint concentric layers (no visible steps).
static func _glow(c: CanvasItem, centre: Vector2, radii: Vector2, strength: float) -> void:
	var steps := 14
	for i in steps:
		var r := 1.0 - float(i) / steps
		_ellipse(c, centre, radii * r, Color(LIGHT, strength / steps))


static func _ellipse(c: CanvasItem, centre: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		pts.append(centre + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	c.draw_colored_polygon(pts, color)
