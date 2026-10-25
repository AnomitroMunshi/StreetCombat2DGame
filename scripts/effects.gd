class_name FxLayer
extends Node2D
## World-space visual effects: hit sparks, particles, shockwave rings, speed-line
## bursts, dust and persistent crack decals. Presentation only; nothing here
## affects combat. Effects age once per physics tick, so they keep animating
## during hitstop and slow down with slow motion.
##
## Decals (cracks, craters) are drawn by the arena (main.gd) beneath the
## fighters via draw_decals(); everything else draws on this layer above them.
##
## Destruction kit (all visual, never collision):
##   crack()      branching cracks that grow outward from the impact point
##   wall_crack() a dented impact crater on a pillar with tapered, bevelled
##                cracks running along it, clipped to the pillar
##   crater()     floor crater outline (dark bowl + lit rim), grows in
##   debris()     chips with gravity that bounce on the floor and settle;
##                pooled and capped (MAX_DEBRIS) for mobile
##   dust_cloud() billowing dust that rises and spreads
##   jolt_wall()  short shake of an arena pillar (read by main.gd's drawing)
## Decals persist until the scene is reloaded (restart). Randomness is seeded.

signal decals_changed

const DEFAULT_LIFE: int = 14
const PARTICLE_GRAVITY: float = 0.45
## Caps (oldest removed first) so long matches never pile up effects.
const MAX_DEBRIS: int = 90
const MAX_DECALS: int = 140
const DEBRIS_LIFE: int = 150
const CRACK_GROW_TICKS: int = 14
const CRACK_COLOR := Color(0.06, 0.045, 0.04, 0.85)
const CRACK_LIGHT := Color(0.6, 0.48, 0.36, 0.35)
## Exposed raw wood inside pillar damage (much lighter than the painted pillar).
const RAW_WOOD := Color(0.62, 0.48, 0.33, 0.85)

## Floor height for debris to land on (set by main.gd).
var floor_y: float = 560.0
## Pillar shake per side (-1 left, +1 right), decays every tick.
var wall_jolt: Dictionary = {-1: 0.0, 1: 0.0}

var _effects: Array[Dictionary] = []
## {kind: "crack" | "crater", pts / pos, size, age, grow}
var _decals: Array[Dictionary] = []
var _debris: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 4242


## Reproducible effects for tests and captures.
func set_seed(value: int) -> void:
	_rng.seed = value


func get_decal_count() -> int:
	return _decals.size()


func get_debris_count() -> int:
	return _debris.size()


## 0..1: how far the newest decal has grown.
func get_newest_decal_growth() -> float:
	if _decals.is_empty():
		return 0.0
	var d: Dictionary = _decals[-1]
	return clampf(float(d["age"]) / float(d["grow"]), 0.0, 1.0)


func _physics_process(_delta: float) -> void:
	_tick_destruction()
	for i in range(_effects.size() - 1, -1, -1):
		var e := _effects[i]
		e["age"] += 1
		if e["kind"] == "cloud":
			e["pos"] = (e["pos"] as Vector2) + (e["vel"] as Vector2)
			e["vel"] = (e["vel"] as Vector2) * 0.96
		elif e["kind"] == "particle" or e["kind"] == "shard":
			var vel: Vector2 = e["vel"]
			vel.y += e["gravity"]
			vel *= 0.97
			e["vel"] = vel
			e["pos"] = (e["pos"] as Vector2) + vel
		if e["age"] >= e["life"]:
			_effects.remove_at(i)
	queue_redraw()


# --- Spawning -----------------------------------------------------------------

## A full hit: spark + shockwave ring + flying particles (+ speed lines at power 3).
func impact(pos: Vector2, power: int, color: Color) -> void:
	spark(pos, color, 14.0 + power * 8.0)
	ring(pos, color, 18.0 + power * 14.0, 10 + power * 3)
	particles(pos, color, 4 + power * 4, 3.0 + power * 1.8, 10 + power * 4)
	if power >= 3:
		burst(pos, Color(1.0, 1.0, 1.0, 0.9), 22)


func spark(pos: Vector2, color: Color, size: float) -> void:
	_effects.append({"kind": "spark", "pos": pos, "age": 0, "life": DEFAULT_LIFE, "color": color,
		"size": size, "angle": _rng.randf() * TAU})


func ring(pos: Vector2, color: Color, size: float, life: int) -> void:
	_effects.append({"kind": "ring", "pos": pos, "age": 0, "life": life, "color": color, "size": size})


## Flat elliptical shockwave along the floor.
func ground_ring(pos: Vector2, size: float, life: int) -> void:
	_effects.append({"kind": "ground_ring", "pos": pos, "age": 0, "life": life,
		"color": Color(0.95, 0.85, 0.7), "size": size})


func particles(pos: Vector2, color: Color, count: int, speed: float, life: int) -> void:
	for i in count:
		var a := _rng.randf_range(-PI, PI)
		var v := Vector2(cos(a), sin(a) - 0.6) * speed * _rng.randf_range(0.5, 1.2)
		_effects.append({"kind": "particle", "pos": pos, "vel": v, "gravity": PARTICLE_GRAVITY, "age": 0,
			"life": life + _rng.randi_range(-3, 3), "color": color, "size": _rng.randf_range(2.0, 4.0)})


## Anime-style radial speed lines around a big impact.
func burst(pos: Vector2, color: Color, life: int) -> void:
	var lines := PackedVector3Array()  # x = angle, y = inner radius factor, z = length factor
	for i in 26:
		lines.append(Vector3(_rng.randf() * TAU, _rng.randf_range(0.6, 1.1), _rng.randf_range(0.4, 1.0)))
	_effects.append({"kind": "burst", "pos": pos, "age": 0, "life": life, "color": color, "lines": lines})


## Bright arc in front of a blocking fighter (the guard absorbing the hit).
func guard_flash(pos: Vector2, facing: int) -> void:
	_effects.append({"kind": "guard", "pos": pos, "age": 0, "life": 12,
		"color": Color(0.65, 0.85, 1.0), "facing": facing})


## Perfect parry: a sharp four-point glint, a fast ring and bright sparks.
func parry_flash(pos: Vector2, facing: int) -> void:
	var c := Color(0.75, 0.95, 1.0)
	_effects.append({"kind": "glint", "pos": pos, "age": 0, "life": 16, "color": c})
	ring(pos, c, 30.0, 10)
	particles(pos, c, 10, 5.0, 12)
	guard_flash(pos, facing)


## Guard break: shards of the guard flying out, a wide ring and a burst.
func shatter(pos: Vector2) -> void:
	var c := Color(1.0, 0.45, 0.3)
	ring(pos, c, 60.0, 18)
	burst(pos, Color(1.0, 0.9, 0.8, 0.9), 18)
	for i in 12:
		var a := _rng.randf_range(-PI, 0.2)
		var v := Vector2(cos(a), sin(a)) * _rng.randf_range(4.0, 8.0)
		_effects.append({"kind": "shard", "pos": pos, "vel": v, "gravity": PARTICLE_GRAVITY, "age": 0,
			"life": 22 + _rng.randi_range(-4, 4), "color": c, "size": _rng.randf_range(5.0, 9.0),
			"angle": _rng.randf() * TAU})


func dust(pos: Vector2, size: float) -> void:
	_effects.append({"kind": "dust", "pos": pos, "age": 0, "life": DEFAULT_LIFE + int(size * 4.0),
		"color": Color(0.78, 0.68, 0.56), "size": size})


## Persistent crack decal that grows outward from `pos` over CRACK_GROW_TICKS
## (later branches start a little later). `vertical` cracks run across a wall;
## otherwise they spread along the (foreshortened) floor. More `size` = longer
## cracks with side branches.
func crack(pos: Vector2, size: float, vertical: bool, branches: int = 6) -> void:
	for branch in branches:
		var line := PackedVector2Array([pos])
		var base := TAU * branch / branches + _rng.randf_range(-0.4, 0.4)
		var p := pos
		var seg := size / 4.0 * _rng.randf_range(0.75, 1.15)
		for s in 4:
			base += _rng.randf_range(-0.5, 0.5)
			var step := Vector2(cos(base), sin(base)) * seg * _rng.randf_range(0.6, 1.2)
			if not vertical:
				step.y *= 0.25  # foreshortened floor
			p += step
			line.append(p)
			# Big cracks fork off short side branches.
			if size > 90.0 and s == 1 and _rng.randf() < 0.6:
				var fork := PackedVector2Array([p])
				var fa := base + _rng.randf_range(0.6, 1.1) * (1.0 if _rng.randf() < 0.5 else -1.0)
				var fs := Vector2(cos(fa), sin(fa)) * seg * 0.8
				if not vertical:
					fs.y *= 0.25
				fork.append(p + fs)
				fork.append(p + fs * 1.7)
				_add_decal({"kind": "crack", "pts": fork, "age": -CRACK_GROW_TICKS / 2, "grow": CRACK_GROW_TICKS})
		_add_decal({"kind": "crack", "pts": line, "age": -branch % 3, "grow": CRACK_GROW_TICKS})
	decals_changed.emit()


## Pillar damage: a dent (irregular dark hollow with a lit, chipped rim) and
## tapered cracks that run mostly up and down the pillar, thinning as they go,
## with short forks. Everything is clipped to `clip` (the pillar), so damage
## never spills onto the paper walls. Higher `power` = bigger dent, more and
## longer cracks. Repeated hits on the same spot stack up.
func wall_crack(pos: Vector2, power: int, clip: Rect2) -> void:
	pos.x = clampf(pos.x, clip.position.x + 6.0, clip.end.x - 6.0)
	var r := 6.0 + power * 4.5
	var dent := PackedVector2Array()
	for i in 11:
		var a := TAU * i / 11.0 + _rng.randf_range(-0.18, 0.18)
		var p := pos + Vector2(cos(a) * 0.85, sin(a) * 1.15) * r * _rng.randf_range(0.7, 1.15)
		p.x = clampf(p.x, clip.position.x + 1.0, clip.end.x - 1.0)
		dent.append(p)
	_add_decal({"kind": "dent", "pts": dent, "pos": pos, "r": r, "age": 0, "grow": 3})
	# Chip specks scattered around the dent.
	for i in 3 + power * 2:
		var a := _rng.randf() * TAU
		var p := pos + Vector2(cos(a), sin(a)) * r * _rng.randf_range(1.2, 2.0)
		if clip.has_point(p):
			_add_decal({"kind": "speck", "pos": p, "size": _rng.randf_range(1.0, 2.2), "age": 0, "grow": 4})
	var count := 2 + power
	for b in count:
		# Mostly vertical: half the cracks run up, half down, fanned slightly.
		var up := b % 2 == 0
		var ang := (-PI * 0.5 if up else PI * 0.5) + _rng.randf_range(-0.7, 0.7)
		var length := (26.0 + power * 24.0) * _rng.randf_range(0.6, 1.15)
		var pts := PackedVector2Array([pos + Vector2(cos(ang), sin(ang)) * r * 0.8])
		var p: Vector2 = pts[0]
		var travelled := 0.0
		while travelled < length:
			ang += _rng.randf_range(-0.45, 0.45)
			# Bend back inward instead of leaving the pillar.
			var step := Vector2(cos(ang), sin(ang)) * _rng.randf_range(7.0, 13.0)
			var nxt := p + step
			if nxt.x < clip.position.x + 2.0 or nxt.x > clip.end.x - 2.0:
				ang = PI - ang
				nxt = p + Vector2(-step.x, step.y)
			if not clip.grow(-1.0).has_point(nxt):
				break
			p = nxt
			pts.append(p)
			travelled += step.length()
			# Occasional fork, thinner and shorter.
			if pts.size() == 3 and power >= 3 and _rng.randf() < 0.5:
				var fork := PackedVector2Array([p])
				var fa := ang + _rng.randf_range(0.5, 0.9) * (1.0 if _rng.randf() < 0.5 else -1.0)
				var q := p
				for k in 3:
					var fs := Vector2(cos(fa), sin(fa)) * _rng.randf_range(5.0, 9.0)
					if not clip.grow(-1.0).has_point(q + fs):
						break
					q += fs
					fork.append(q)
					fa += _rng.randf_range(-0.4, 0.4)
				if fork.size() >= 2:
					_add_decal({"kind": "crack", "pts": fork, "w": 1.6 + power * 0.2,
						"age": -CRACK_GROW_TICKS / 2, "grow": CRACK_GROW_TICKS, "wall": true})
		if pts.size() >= 2:
			_add_decal({"kind": "crack", "pts": pts, "w": 2.4 + power * 0.7, "age": -(b % 3), "grow": CRACK_GROW_TICKS, "wall": true})
	decals_changed.emit()


## Floor crater: a dark elliptical bowl with a lit rim, punched in over 5 ticks.
func crater(pos: Vector2, size: float) -> void:
	_add_decal({"kind": "crater", "pos": pos, "size": size, "age": 0, "grow": 5})
	decals_changed.emit()


## Chips of stone or wood. `spread` is the launch cone around straight up
## (wall chips use a sideways `bias`). They bounce on the floor and settle.
func debris(pos: Vector2, count: int, color: Color, speed: float = 6.0, bias: float = 0.0) -> void:
	for i in count:
		var a := -PI * 0.5 + bias + _rng.randf_range(-1.1, 1.1)
		var v := Vector2(cos(a), sin(a)) * speed * _rng.randf_range(0.4, 1.1)
		_debris.append({"pos": pos + Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-4.0, 4.0)),
			"vel": v, "age": 0, "size": _rng.randf_range(2.5, 6.0), "angle": _rng.randf() * TAU,
			"spin": _rng.randf_range(-0.4, 0.4), "color": color.darkened(_rng.randf_range(0.0, 0.35))})
	while _debris.size() > MAX_DEBRIS:
		_debris.pop_front()


## Billowing dust: several puffs that rise, spread and fade.
func dust_cloud(pos: Vector2, size: float, life: int = 40) -> void:
	for i in 7:
		var off := Vector2(_rng.randf_range(-1.0, 1.0) * 30.0 * size, _rng.randf_range(-8.0, 0.0))
		var drift := Vector2(signf(off.x) * _rng.randf_range(0.6, 1.6), -_rng.randf_range(0.3, 0.9))
		_effects.append({"kind": "cloud", "pos": pos + off, "vel": drift, "age": 0, "life": life + _rng.randi_range(-8, 8),
			"color": Color(0.74, 0.65, 0.54), "size": size * _rng.randf_range(14.0, 24.0)})


## Pillar shake on side -1 (left) or +1 (right).
func jolt_wall(side: int, amount: float) -> void:
	wall_jolt[side] = maxf(wall_jolt[side], amount)


func _add_decal(d: Dictionary) -> void:
	_decals.append(d)
	while _decals.size() > MAX_DECALS:
		_decals.pop_front()


func _tick_destruction() -> void:
	var redraw := false
	for d in _decals:
		if d["age"] < d["grow"]:
			d["age"] += 1
			redraw = true
	for side in [-1, 1]:
		if wall_jolt[side] > 0.05:
			wall_jolt[side] *= 0.82
			redraw = true
		elif wall_jolt[side] > 0.0:
			wall_jolt[side] = 0.0
			redraw = true
	for i in range(_debris.size() - 1, -1, -1):
		var c := _debris[i]
		c["age"] += 1
		var vel: Vector2 = c["vel"]
		var pos: Vector2 = c["pos"]
		if pos.y < floor_y or vel != Vector2.ZERO:
			vel.y += 0.5
			pos += vel
			c["angle"] += c["spin"]
			if pos.y >= floor_y:
				# Bounce with losses, then rest on the floor.
				pos.y = floor_y
				vel = Vector2(vel.x * 0.5, -vel.y * 0.3) if absf(vel.y) > 2.0 else Vector2.ZERO
			c["vel"] = vel
			c["pos"] = pos
		if c["age"] >= DEBRIS_LIFE:
			_debris.remove_at(i)
	if redraw:
		decals_changed.emit()


# --- Drawing ------------------------------------------------------------------

## Called by the arena's _draw so cracks and craters sit under the fighters.
func draw_decals(canvas: CanvasItem) -> void:
	for d in _decals:
		var g := clampf(float(d["age"]) / float(d["grow"]), 0.0, 1.0)
		if g <= 0.0:
			continue
		if d["kind"] == "crater":
			var pos: Vector2 = d["pos"]
			var r: float = d["size"] * (0.4 + 0.6 * g)
			canvas.draw_set_transform(pos, 0.0, Vector2(1.0, 0.24))
			canvas.draw_circle(Vector2.ZERO, r, Color(0.07, 0.05, 0.04, 0.75))
			canvas.draw_circle(Vector2(0.0, -r * 0.25), r * 0.7, Color(0.12, 0.09, 0.07, 0.6))
			canvas.draw_arc(Vector2.ZERO, r, PI * 0.05, PI * 0.95, 32, Color(0.62, 0.5, 0.38, 0.6), 4.0, true)
			canvas.draw_arc(Vector2.ZERO, r * 1.05, PI * 1.05, PI * 1.95, 32, Color(0.04, 0.03, 0.02, 0.6), 3.0, true)
			canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			continue
		if d["kind"] == "dent":
			_draw_dent(canvas, d, g)
			continue
		if d["kind"] == "speck":
			canvas.draw_circle(d["pos"], d["size"], Color(0.05, 0.035, 0.03, 0.8))
			continue
		var pts: PackedVector2Array = d["pts"]
		var shown := _grown_polyline(pts, g)
		if shown.size() < 2:
			continue
		# Tapered: thick at the origin, thinning toward the tip. A light bevel
		# line just below each segment makes it read as a split in the surface.
		var w0: float = d.get("w", 2.6)
		var n := shown.size() - 1
		# On the dark pillar the split shows pale splintered wood around it.
		var wall: bool = d.get("wall", false)
		var edge := RAW_WOOD if wall else CRACK_LIGHT
		for i in n:
			var w := lerpf(w0, 0.8, float(i) / maxf(float(pts.size() - 1), 1.0))
			if wall:
				# Splinters only near the hit, fading along the crack.
				var near := 1.0 - float(i) / maxf(float(pts.size() - 1), 1.0)
				if near > 0.35:
					var c := edge
					c.a *= near
					canvas.draw_line(shown[i], shown[i + 1], c, w + 1.6 * near, true)
			else:
				canvas.draw_line(shown[i] + Vector2(0.8, 1.2), shown[i + 1] + Vector2(0.8, 1.2), edge, maxf(w * 0.5, 0.8), true)
		for i in n:
			var w := lerpf(w0, 0.8, float(i) / maxf(float(pts.size() - 1), 1.0))
			canvas.draw_line(shown[i], shown[i + 1], CRACK_COLOR, w, true)
			if i > 0:
				canvas.draw_circle(shown[i], w * 0.5, CRACK_COLOR)
	# Settled and flying debris chips (drawn with the decals so they sit on the floor).
	for c in _debris:
		var a := 1.0 - smoothstep(0.75, 1.0, float(c["age"]) / DEBRIS_LIFE)
		var col: Color = c["color"]
		col.a *= a
		var s: float = c["size"]
		var pts2 := PackedVector2Array()
		for k in 4:
			pts2.append(c["pos"] + Vector2.from_angle(c["angle"] + k * TAU / 4.0) * s * (1.0 if k % 2 == 0 else 0.6))
		canvas.draw_colored_polygon(pts2, col)


## Dent: dark hollow, a deeper core, and a lit lower-right rim (light from the
## upper left), punched in quickly.
static func _draw_dent(canvas: CanvasItem, d: Dictionary, g: float) -> void:
	var centre: Vector2 = d["pos"]
	var pts: PackedVector2Array = d["pts"]
	var scaled := PackedVector2Array()
	var core := PackedVector2Array()
	for p in pts:
		scaled.append(centre + (p - centre) * (0.5 + 0.5 * g))
		core.append(centre + (p - centre) * 0.55 * g + Vector2(-1.0, -1.0))
	# Splintered raw wood around the hit, then the dark crushed hollow inside.
	var ring := PackedVector2Array()
	for p in scaled:
		ring.append(centre + (p - centre) * 1.35)
	canvas.draw_colored_polygon(ring, RAW_WOOD)
	canvas.draw_colored_polygon(scaled, Color(0.08, 0.06, 0.05, 0.95))
	canvas.draw_colored_polygon(core, Color(0.02, 0.015, 0.01, 0.95))
	var rim := scaled.duplicate()
	rim.append(scaled[0])
	canvas.draw_polyline(rim, Color(0.03, 0.02, 0.015, 0.9), 2.0, true)
	# Lit edge on the lower right half of the rim.
	var lit := PackedVector2Array()
	for p in scaled:
		var dir := p - centre
		if dir.x + dir.y > 0.0:
			lit.append(p + dir.normalized() * 1.2)
	if lit.size() >= 2:
		canvas.draw_polyline(lit, Color(0.5, 0.4, 0.3, 0.7), 1.2, true)


## The first `g` (0..1) of a polyline, by segment count, with the last
## segment partially drawn.
static func _grown_polyline(pts: PackedVector2Array, g: float) -> PackedVector2Array:
	if g >= 1.0:
		return pts
	var segs := (pts.size() - 1) * g
	var whole := int(segs)
	var out := PackedVector2Array()
	for i in whole + 1:
		out.append(pts[i])
	if whole < pts.size() - 1:
		out.append(pts[whole].lerp(pts[whole + 1], segs - whole))
	return out


func _draw() -> void:
	for e in _effects:
		var t := float(e["age"]) / float(e["life"])
		var color: Color = e["color"]
		var pos: Vector2 = e["pos"]
		match e["kind"]:
			"spark":
				color.a = 1.0 - t
				var size: float = e["size"]
				draw_circle(pos, size * 0.45 * (1.0 - t), Color(1.0, 1.0, 1.0, (1.0 - t) * 0.9))
				for i in 8:
					var a: float = e["angle"] + TAU * i / 8.0
					var dir := Vector2(cos(a), sin(a))
					var reach := size * (0.6 + t * 1.3) * (1.0 if i % 2 == 0 else 0.6)
					draw_line(pos + dir * size * 0.2 * (1.0 + t), pos + dir * reach, color, 3.0 * (1.0 - t) + 1.0, true)
			"ring":
				color.a = (1.0 - t) * 0.9
				var r: float = e["size"] * (0.3 + t * 1.8)
				draw_arc(pos, r, 0.0, TAU, 40, color, 6.0 * (1.0 - t) + 1.0, true)
			"ground_ring":
				color.a = (1.0 - t) * 0.8
				var gr: float = e["size"] * (0.2 + t * 1.6)
				draw_set_transform(pos, 0.0, Vector2(1.0, 0.22))
				draw_arc(Vector2.ZERO, gr, 0.0, TAU, 48, color, 10.0 * (1.0 - t) + 2.0, true)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"particle":
				color.a = 1.0 - t
				var vel: Vector2 = e["vel"]
				draw_line(pos, pos - vel * 1.5, color, e["size"], true)
			"burst":
				color.a = 0.85 * (1.0 - t)
				var lines: PackedVector3Array = e["lines"]
				var spread := 70.0 + t * 260.0
				for l in lines:
					var dir := Vector2(cos(l.x), sin(l.x))
					var inner := spread * l.y
					draw_line(pos + dir * inner, pos + dir * (inner + 90.0 * l.z * (1.0 - t * 0.5)), color, 2.0, true)
			"guard":
				color.a = 0.9 * (1.0 - t)
				var face: int = e["facing"]
				var centre := pos - Vector2(face * 18.0, 0.0)
				var from := -PI * 0.42 if face > 0 else PI - PI * 0.42
				draw_arc(centre, 34.0 + t * 10.0, from, from + PI * 0.84, 20, color, 5.0 * (1.0 - t) + 1.5, true)
			"shard":
				# Tumbling triangle.
				color.a = 1.0 - t
				var sz: float = e["size"] * (1.0 - t * 0.5)
				var ang: float = e["angle"] + t * 8.0
				var pts := PackedVector2Array()
				for k in 3:
					pts.append(pos + Vector2.from_angle(ang + k * TAU / 3.0) * sz * (1.0 if k == 0 else 0.55))
				draw_colored_polygon(pts, color)
			"glint":
				# Long thin cross that snaps out and shrinks: reads as a clean deflect.
				var g := sin(PI * minf(t * 2.5, 1.0)) * (1.0 - t)
				color.a = 1.0 - t
				draw_circle(pos, 9.0 * g + 2.0, Color(1.0, 1.0, 1.0, color.a))
				for k in 4:
					var dir := Vector2.from_angle(PI * 0.25 + k * PI * 0.5)
					var reach := 75.0 if k % 2 == 0 else 45.0
					draw_line(pos - dir * 4.0, pos + dir * reach * g, color, 4.0 * (1.0 - t) + 1.0, true)
			"cloud":
				color.a = 0.32 * sin(PI * minf(t * 1.6, 1.0)) * (1.0 - t * 0.6)
				draw_circle(pos, e["size"] * (0.5 + t * 0.9), color)
			"dust":
				color.a = 0.5 * (1.0 - t)
				var ds: float = e["size"]
				for side in [-1.0, 1.0]:
					for j in 3:
						var puff := pos + Vector2(side * (8.0 + t * 30.0 + j * 7.0) * ds, -4.0 - j * 2.0 - t * 7.0 * ds)
						draw_circle(puff, (6.0 - j * 1.5) * (1.0 - t * 0.4) * ds, color)
