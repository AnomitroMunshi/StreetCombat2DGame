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
##   floor_break() a smashed hole in the floorboards: dark broken-board hole
##                ringed with pale splintered wood, broken board ends sticking
##                up, and a few tapered cracks running along the planks
##   debris()     chips with gravity that bounce on the floor and settle;
##                pooled and capped (MAX_DEBRIS) for mobile
##   dust_cloud() billowing dust that rises and spreads
##   jolt_wall()  short shake of an arena pillar (read by main.gd's drawing)
## Decals persist until the scene is reloaded (restart). Randomness is seeded.

signal decals_changed

const DEFAULT_LIFE: int = 14
const PARTICLE_GRAVITY: float = 0.45
## Caps (oldest removed first) so long matches never pile up effects.
const MAX_DEBRIS: int = 120
## Cinematic light colours (additive glow layer).
const GLOW_WARM := Color(1.0, 0.62, 0.22)
const GLOW_HOT := Color(1.0, 0.95, 0.8)
const GLOW_BLUE := Color(0.35, 0.65, 1.0)
const MAX_EFFECTS: int = 260
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
var _comic_font: Font = null


## Additive layer for light: flares, energy waves, spin arcs, speed lines.
## Overlapping light adds up and glows instead of covering what is behind.
var _glow: Node2D = null


func _ready() -> void:
	_rng.seed = 4242
	_glow = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	add_child(_glow)
	_glow.draw.connect(_draw_glow)


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


## Effects move once per physics tick and are drawn between ticks at the
## physics interpolation fraction, so they stay smooth at any render rate and
## in slow motion (fewer ticks per frame). Ages, lifetimes and caps stay
## tick-driven.
var _frac: float = 1.0


func _process(_delta: float) -> void:
	_frac = Engine.get_physics_interpolation_fraction()
	if not _effects.is_empty() or not _debris.is_empty():
		queue_redraw()
		if _glow != null:
			_glow.queue_redraw()


## Where an effect is drawn this frame.
func _drawn_pos(e: Dictionary) -> Vector2:
	return (e.get("prev", e["pos"]) as Vector2).lerp(e["pos"], _frac)


## An effect's age fraction this frame (continuous between ticks).
func _drawn_t(e: Dictionary) -> float:
	return clampf((float(e["age"]) - 1.0 + _frac) / float(e["life"]), 0.0, 1.0)


func _physics_process(_delta: float) -> void:
	_tick_destruction()
	if _glow != null:
		_glow.queue_redraw()
	for i in range(_effects.size() - 1, -1, -1):
		var e := _effects[i]
		e["age"] += 1
		e["prev"] = e["pos"]  # drawn interpolated between ticks (smooth in slow motion)
		if e.has("move"):
			e["pos"] = (e["pos"] as Vector2) + (e["move"] as Vector2)
		if e["kind"] == "cloud":
			e["pos"] = (e["pos"] as Vector2) + (e["vel"] as Vector2)
			e["vel"] = (e["vel"] as Vector2) * 0.96
		elif e["kind"] == "blood":
			var bv: Vector2 = e["vel"]
			bv.y += e["gravity"]
			bv.x *= 0.985
			e["vel"] = bv
			var bp := (e["pos"] as Vector2) + bv
			if bp.y >= floor_y - 1.0:
				_add_decal({"kind": "stain", "pos": Vector2(bp.x, floor_y - _rng.randf_range(1.0, 7.0)), "age": 0, "grow": 4,
					"size": float(e["size"]) * _rng.randf_range(1.2, 2.2), "stretch": clampf(absf(bv.x) * 0.35, 1.0, 3.0)})
				e["age"] = e["life"]
			e["pos"] = bp
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


## Tiered, directional hit (1 light, 2 solid, 3 heavy): a hot core flash
## stretched along the blow, streaks and sweat flung the way it travels. Light
## hits stay small and sharp; only heavy ones get the flare and air wave.
func hit(pos: Vector2, dir: Vector2, tier: int, color: Color, kind: int = CombatData.ImpactKind.STRAIGHT,
		body: bool = false) -> void:
	dir = dir.normalized()
	if kind == CombatData.ImpactKind.HOOK:
		# Hooks: a sideways swipe arcing into the target.
		_spawn({"kind": "swipe", "pos": pos - dir * 6.0, "age": 0, "life": 8 + tier * 2, "color": color,
			"size": 22.0 + tier * 8.0, "dir": dir.angle(), "turn": signf(dir.x)})
	if body:
		# Body shots: a compact thud low on the body, no big flare.
		tier = mini(tier, 2)
	_spawn({"kind": "flash", "pos": pos, "age": 0, "life": 5 + tier * 2, "color": color,
		"size": 8.0 + tier * 5.0, "dir": dir.angle()})
	streaks(pos, dir, 3 + tier * 3, color, 0.3 + tier * 0.06, 24.0 + tier * 22.0)
	sweat(pos, dir, 2 + tier * 3, 3.0 + tier * 1.6)
	if tier >= 2:
		ring(pos, color, 8.0 + tier * 6.0, 6 + tier)
	if tier >= 3:
		# Heavy: a shock wave off the impact (no flare: it hid the punch).
		air_wave(pos + dir * 12.0, dir, 34.0, 10)


## Finisher strike (light layer), built to stay crisp: a small white-hot core
## stretched along the blow, thin tapered spark needles thrown mostly in a cone
## along it (decelerating, white at the tip, warm at the tail), and one thin
## shockwave flattened across the line of the blow. The knockout blow adds a
## short anamorphic lens streak. No soft discs or thick rings: the blow itself
## stays readable.
## Blood on heavy blows to the head: false turns it off everywhere.
const BLOOD: bool = true
const BLOOD_COLOR := Color(0.52, 0.03, 0.04)
const BLOOD_DARK := Color(0.3, 0.01, 0.02)
const STRIKE_HOT := Color(1.0, 0.97, 0.9)
const STRIKE_WARM := Color(1.0, 0.72, 0.38)


func strike(pos: Vector2, dir: Vector2, power: int, final: bool = false) -> void:
	dir = dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	var base := dir.angle()
	power = clampi(power, 1, 3)
	_spawn({"kind": "score", "glow": true, "pos": pos, "age": 0, "life": 4 + power, "color": STRIKE_HOT,
		"size": 3.5 + power * 2.2 + (1.5 if final else 0.0), "dir": base})
	var count := 5 + power * 4 + (8 if final else 0)
	for i in count:
		var wide := _rng.randf() < 0.3
		var a := base + _rng.randf_range(-1.5, 1.5) if wide else base + _rng.randfn(0.0, 0.32)
		var reach := _rng.randf_range(24.0, 50.0 + power * 26.0) * (1.5 if final else 1.0)
		_spawn({"kind": "needle", "glow": true, "pos": pos, "age": 0,
			"life": _rng.randi_range(5, 8 + power * 2) + (4 if final else 0), "color": STRIKE_HOT,
			"dir": a, "size": reach, "len": _rng.randf_range(10.0, 18.0 + power * 8.0) * (0.6 if wide else 1.0),
			"width": _rng.randf_range(1.0, 1.4 + power * 0.35)})
	_spawn({"kind": "shock", "glow": true, "pos": pos + dir * 4.0, "age": 0, "life": 7 + power * 2,
		"color": STRIKE_HOT, "size": 16.0 + power * 12.0 + (34.0 if final else 0.0), "dir": base})
	if final:
		_spawn({"kind": "shock", "glow": true, "pos": pos + dir * 10.0, "age": 0, "life": 16,
			"color": STRIKE_WARM, "size": 120.0, "dir": base})
		_spawn({"kind": "lens", "glow": true, "pos": pos, "age": 0, "life": 18, "color": STRIKE_HOT, "size": 360.0})


## Blood thrown along a blow: a short spray of droplets (bigger ones first,
## a fine mist after) that fall under gravity and stain the floor where they
## land.
func blood(pos: Vector2, dir: Vector2, amount: int) -> void:
	if not BLOOD:
		return
	dir = dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	for i in amount:
		var heavy := i < amount / 3
		var a := dir.angle() + _rng.randfn(0.0, 0.28 if heavy else 0.5) - 0.15 * signf(dir.x)
		var spd := _rng.randf_range(3.0, 6.5) if heavy else _rng.randf_range(4.0, 9.0)
		_spawn({"kind": "blood", "pos": pos, "vel": Vector2.from_angle(a) * spd, "gravity": 0.38, "age": 0,
			"life": 90, "color": BLOOD_COLOR, "size": _rng.randf_range(2.2, 3.4) if heavy else _rng.randf_range(1.0, 1.8)})


## A wide motion smear behind a big swing (the Super Chor slap): an arc round
## `centre` from angle a0 to a1, fading quickly.
func swing_arc(centre: Vector2, radius: float, a0: float, a1: float, color: Color, life: int = 12) -> void:
	_spawn({"kind": "swing_arc", "pos": centre, "age": 0, "life": life, "color": color, "size": radius,
		"a0": a0, "a1": a1})


## Comic onomatopoeia ("ঠাস!", "ধুম!"): a jagged burst with the word on it.
## Kept small: knockout shots zoom the camera right in, and the word must sit
## beside the action, never over it.
const COMIC_SIZE: float = 17.0
const COMIC_FONT: int = 13


func comic(pos: Vector2, text: String, color: Color, life: int = 24) -> void:
	_spawn({"kind": "comic", "pos": pos, "age": 0, "life": life, "color": color, "text": text,
		"tilt": _rng.randf_range(-0.25, 0.25)})


## Sweat / spit droplets thrown along a blow, falling under gravity.
func sweat(pos: Vector2, dir: Vector2, count: int, speed: float) -> void:
	for i in count:
		var a := dir.angle() + _rng.randf_range(-0.55, 0.55)
		var v := Vector2.from_angle(a) * speed * _rng.randf_range(0.6, 1.3) + Vector2(0.0, -_rng.randf_range(0.3, 1.5))
		_spawn({"kind": "particle", "pos": pos, "vel": v, "gravity": PARTICLE_GRAVITY, "age": 0,
			"life": 16 + _rng.randi_range(-3, 6), "color": Color(0.85, 0.93, 1.0, 0.9), "size": _rng.randf_range(1.5, 3.0)})


func spark(pos: Vector2, color: Color, size: float) -> void:
	_spawn({"kind": "spark", "pos": pos, "age": 0, "life": DEFAULT_LIFE, "color": color,
		"size": size, "angle": _rng.randf() * TAU})


func ring(pos: Vector2, color: Color, size: float, life: int) -> void:
	_spawn({"kind": "ring", "pos": pos, "age": 0, "life": life, "color": color, "size": size})


## Flat elliptical shockwave along the floor.
func ground_ring(pos: Vector2, size: float, life: int) -> void:
	_spawn({"kind": "ground_ring", "pos": pos, "age": 0, "life": life,
		"color": Color(0.95, 0.85, 0.7), "size": size})


func particles(pos: Vector2, color: Color, count: int, speed: float, life: int) -> void:
	for i in count:
		var a := _rng.randf_range(-PI, PI)
		var v := Vector2(cos(a), sin(a) - 0.6) * speed * _rng.randf_range(0.5, 1.2)
		_spawn({"kind": "particle", "pos": pos, "vel": v, "gravity": PARTICLE_GRAVITY, "age": 0,
			"life": life + _rng.randi_range(-3, 3), "color": color, "size": _rng.randf_range(2.0, 4.0)})


## Anime-style radial speed lines around a big impact.
func burst(pos: Vector2, color: Color, life: int) -> void:
	var lines := PackedVector3Array()  # x = angle, y = inner radius factor, z = length factor
	for i in 26:
		lines.append(Vector3(_rng.randf() * TAU, _rng.randf_range(0.6, 1.1), _rng.randf_range(0.4, 1.0)))
	_spawn({"kind": "burst", "pos": pos, "age": 0, "life": life, "color": color, "lines": lines})


## Bright arc in front of a blocking fighter (the guard absorbing the hit).
func guard_flash(pos: Vector2, facing: int) -> void:
	_spawn({"kind": "guard", "pos": pos, "age": 0, "life": 12,
		"color": Color(0.65, 0.85, 1.0), "facing": facing})


## Directional impact streaks: fast lines shooting out along `dir` in a cone
## (counter hits, finisher blows, palm blasts).
func streaks(pos: Vector2, dir: Vector2, count: int, color: Color, spread: float = 0.5, length: float = 70.0) -> void:
	var lines := PackedVector3Array()  # x = angle, y = start offset, z = length factor
	var base := dir.angle()
	for i in count:
		lines.append(Vector3(base + _rng.randf_range(-spread, spread), _rng.randf_range(0.0, 20.0), _rng.randf_range(0.5, 1.0)))
	_spawn({"kind": "streaks", "pos": pos, "age": 0, "life": 12, "color": color, "lines": lines, "length": length})


## Two strikes meeting: white-gold sparks bursting both ways and a small ring.
func clash(pos: Vector2) -> void:
	var c := Color(1.0, 0.92, 0.6)
	spark(pos, c, 26.0)
	ring(pos, Color.WHITE, 26.0, 10)
	streaks(pos, Vector2.UP, 8, c, PI, 40.0)
	particles(pos, c, 12, 6.0, 12)


## Perfect parry: a sharp four-point glint, a fast ring and bright sparks.
func parry_flash(pos: Vector2, facing: int) -> void:
	var c := Color(0.75, 0.95, 1.0)
	_spawn({"kind": "glint", "pos": pos, "age": 0, "life": 16, "color": c})
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
		_spawn({"kind": "shard", "pos": pos, "vel": v, "gravity": PARTICLE_GRAVITY, "age": 0,
			"life": 22 + _rng.randi_range(-4, 4), "color": c, "size": _rng.randf_range(5.0, 9.0),
			"angle": _rng.randf() * TAU})


func dust(pos: Vector2, size: float) -> void:
	_spawn({"kind": "dust", "pos": pos, "age": 0, "life": DEFAULT_LIFE + int(size * 4.0),
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
		var start := pos + Vector2(cos(ang), sin(ang)) * r * 0.8
		start.x = clampf(start.x, clip.position.x + 2.0, clip.end.x - 2.0)
		var pts := PackedVector2Array([start])
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
						"age": -CRACK_GROW_TICKS / 2, "grow": CRACK_GROW_TICKS, "raw": true})
		if pts.size() >= 2:
			_add_decal({"kind": "crack", "pts": pts, "w": 2.4 + power * 0.7, "age": -(b % 3), "grow": CRACK_GROW_TICKS, "raw": true})
	decals_changed.emit()


## A body spiked into the floorboards (seen at the floor's foreshortened
## angle): an irregular hole of broken boards, a ring of pale splintered raw
## wood, broken board ends sticking up around the rim, and a few cracks that
## run along the planks (wood splits with the grain), thick at the hole and
## thinning out. Higher `power` = bigger hole, more and longer cracks.
func floor_break(pos: Vector2, power: int) -> void:
	var r := 30.0 + power * 12.0
	var hole := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0 + _rng.randf_range(-0.12, 0.12)
		hole.append(pos + Vector2(cos(a) * r, sin(a) * r * 0.26) * 1.0 + Vector2(cos(a), sin(a) * 0.26) * r * _rng.randf_range(-0.2, 0.1))
	_add_decal({"kind": "crater", "pts": hole, "pos": pos, "r": r, "age": 0, "grow": 5})
	for i in 5 + power:
		var a := _rng.randf_range(0.0, TAU)
		var base := pos + Vector2(cos(a) * r * 0.92, sin(a) * r * 0.24)
		var tip := base + Vector2(cos(a) * _rng.randf_range(5.0, 11.0), -_rng.randf_range(5.0, 12.0))
		_add_decal({"kind": "spike", "pts": PackedVector2Array([base + Vector2(-3.5, 0.0), tip, base + Vector2(3.5, 0.0)]),
			"age": -2, "grow": 4})
	for b in 3 + power:
		var grain := 0.0 if b % 2 == 0 else PI
		var ang := grain + _rng.randf_range(-0.3, 0.3)
		var start := pos + Vector2(cos(ang) * r * 0.85, sin(ang) * r * 0.22)
		var pts := PackedVector2Array([start])
		var p := start
		var length := (45.0 + power * 25.0) * _rng.randf_range(0.6, 1.2)
		var travelled := 0.0
		while travelled < length:
			ang = lerp_angle(ang + _rng.randf_range(-0.35, 0.35), grain, 0.3)
			var step := Vector2(cos(ang), sin(ang) * 0.25) * _rng.randf_range(8.0, 14.0)
			p += step
			pts.append(p)
			travelled += step.length()
		_add_decal({"kind": "crack", "pts": pts, "w": 2.6 + power * 0.6, "age": -(b % 3), "grow": CRACK_GROW_TICKS, "raw": true})
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


## Impact flare (glow layer): a hot core, a warm halo and long tapered rays
## that snap out and fade. `power` 1..3 scales size and ray count.
func flare(pos: Vector2, power: int, warm: Color = GLOW_WARM, rays_dir: float = INF) -> void:
	var rays := PackedVector3Array()  # angle, length factor, width factor
	for i in 8 + power * 3:
		var a := _rng.randf() * TAU if rays_dir == INF else rays_dir + _rng.randf_range(-1.2, 1.2)
		rays.append(Vector3(a, _rng.randf_range(0.45, 1.0), _rng.randf_range(0.6, 1.2)))
	_spawn({"kind": "flare", "glow": true, "pos": pos, "age": 0, "life": 12 + power * 3,
		"color": warm, "size": 40.0 + power * 28.0, "lines": rays})


## Energy crescent (glow layer) travelling along `dir`: stacked bright arcs,
## like a palm blast or the arc of a spinning kick.
func energy_wave(pos: Vector2, dir: Vector2, size: float, color: Color = GLOW_BLUE, life: int = 18, speed: float = 4.0) -> void:
	_spawn({"kind": "ewave", "glow": true, "pos": pos, "move": dir.normalized() * speed, "dir": dir.angle(),
		"age": 0, "life": life, "color": color, "size": size})


## Spin arcs (glow layer) circling a spinning body.
func spin_arcs(pos: Vector2, radius: float, color: Color = GLOW_BLUE) -> void:
	_spawn({"kind": "garcs", "glow": true, "pos": pos, "age": 0, "life": 10, "color": color,
		"size": radius, "angle": _rng.randf() * TAU})


## Speed lines (glow layer) streaming behind something moving along `dir`.
func speed_lines(pos: Vector2, dir: Vector2, color: Color = GLOW_BLUE, count: int = 4, spread: float = 30.0) -> void:
	var n := Vector2(-dir.y, dir.x)
	for i in count:
		var start := pos + n * _rng.randf_range(-spread, spread) - dir * _rng.randf_range(0.0, 20.0)
		_spawn({"kind": "speed", "glow": true, "pos": start, "dir": dir, "age": 0, "life": 9,
			"color": color, "size": _rng.randf_range(40.0, 90.0)})


## Big angular chunks of stone / wood: two-tone (lit face, shaded body) with a
## dark edge, tumbling, bouncing and settling with the other debris.
func chunks(pos: Vector2, count: int, color: Color, speed: float = 8.0, bias: float = 0.0, spread: float = 1.0,
		min_size: float = 6.0, max_size: float = 14.0) -> void:
	for i in count:
		var a := -PI * 0.5 + bias + _rng.randf_range(-spread, spread)
		var v := Vector2(cos(a), sin(a)) * speed * _rng.randf_range(0.45, 1.15)
		var shape := PackedVector2Array()
		var verts := _rng.randi_range(5, 6)
		var sz := _rng.randf_range(min_size, max_size)
		for k in verts:
			shape.append(Vector2.from_angle(TAU * k / verts + _rng.randf_range(-0.3, 0.3)) * sz * _rng.randf_range(0.6, 1.0))
		_debris.append({"pos": pos + Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-6.0, 6.0)),
			"vel": v, "age": 0, "size": sz, "angle": _rng.randf() * TAU, "spin": _rng.randf_range(-0.3, 0.3),
			"color": color.darkened(_rng.randf_range(0.0, 0.25)), "shape": shape})
	while _debris.size() > MAX_DEBRIS:
		_debris.pop_front()


## Long thin wood splinters (pooled with the debris): they tumble fast, bounce
## on the floor and settle like the chips.
func splinters(pos: Vector2, count: int, color: Color, speed: float = 8.0, bias: float = 0.0, spread: float = 1.1) -> void:
	for i in count:
		var a := -PI * 0.5 + bias + _rng.randf_range(-spread, spread)
		var v := Vector2(cos(a), sin(a)) * speed * _rng.randf_range(0.45, 1.15)
		_debris.append({"pos": pos + Vector2(_rng.randf_range(-5.0, 5.0), _rng.randf_range(-5.0, 5.0)),
			"vel": v, "age": 0, "size": _rng.randf_range(9.0, 16.0), "angle": _rng.randf() * TAU,
			"spin": _rng.randf_range(-0.6, 0.6), "color": color.lightened(_rng.randf_range(0.0, 0.2)), "stick": true})
	while _debris.size() > MAX_DEBRIS:
		_debris.pop_front()


## A crescent of air pushed out along `dir` (palm strikes, kick arcs).
func air_wave(pos: Vector2, dir: Vector2, size: float, life: int = 14, color: Color = Color(1.0, 0.97, 0.9)) -> void:
	_spawn({"kind": "wave", "pos": pos, "dir": dir.angle(), "age": 0, "life": life, "color": color, "size": size})


## Wind swirling around a spinning body (tornado / spinning kicks).
func swirl(pos: Vector2, radius: float, color: Color = Color(0.95, 0.95, 1.0)) -> void:
	_spawn({"kind": "swirl", "pos": pos, "age": 0, "life": 12, "color": color, "size": radius,
		"angle": _rng.randf() * TAU})


## Scuff mark left on the floor by a skidding body (persistent decal).
func scuff(from: Vector2, to: Vector2) -> void:
	if from.distance_to(to) < 1.0:
		return
	_add_decal({"kind": "scuff", "pts": PackedVector2Array([from, to]), "age": 0, "grow": 1})
	decals_changed.emit()


## Billowing dust: several puffs that rise, spread and fade.
func dust_cloud(pos: Vector2, size: float, life: int = 40, puffs: int = 7) -> void:
	for i in puffs:
		var off := Vector2(_rng.randf_range(-1.0, 1.0) * 34.0 * size, _rng.randf_range(-10.0, 0.0) * size)
		var drift := Vector2(signf(off.x) * _rng.randf_range(0.5, 1.8) * (0.6 + size * 0.4), -_rng.randf_range(0.2, 0.9))
		_spawn({"kind": "cloud", "pos": pos + off, "vel": drift, "age": 0, "life": life + _rng.randi_range(-8, 12),
			"color": Color(0.74, 0.64, 0.52), "size": size * _rng.randf_range(15.0, 26.0)})


## Pillar shake on side -1 (left) or +1 (right).
func jolt_wall(side: int, amount: float) -> void:
	wall_jolt[side] = maxf(wall_jolt[side], amount)


## Every transient effect goes through here: past MAX_EFFECTS the oldest are
## dropped, so big finishers can never pile up unbounded work.
func _spawn(e: Dictionary) -> void:
	_effects.append(e)
	if _effects.size() > MAX_EFFECTS:
		_effects.remove_at(0)


func get_effect_count() -> int:
	return _effects.size()


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
		c["prev"] = c["pos"]
		c["prev_angle"] = c["angle"]
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
			_draw_floor_hole(canvas, d, g)
			continue
		if d["kind"] == "spike":
			# Broken board end sticking up out of the floor.
			var sk: PackedVector2Array = d["pts"]
			canvas.draw_colored_polygon(sk, RAW_WOOD)
			canvas.draw_polyline(sk, Color(0.08, 0.06, 0.05, 0.8), 1.2, true)
			continue
		if d["kind"] == "dent":
			_draw_dent(canvas, d, g)
			continue
		if d["kind"] == "stain":
			# Floor seen at a low angle: a flattened drop, darker at its rim.
			var sp0: Vector2 = d["pos"]
			var sz: float = d["size"] * g
			canvas.draw_set_transform(sp0, 0.0, Vector2(d["stretch"], 0.32))
			canvas.draw_circle(Vector2.ZERO, sz * 1.15, Color(BLOOD_DARK, 0.75))
			canvas.draw_circle(Vector2.ZERO, sz * 0.8, Color(BLOOD_COLOR, 0.85))
			canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			continue
		if d["kind"] == "scuff":
			var sp: PackedVector2Array = d["pts"]
			canvas.draw_line(sp[0], sp[1], Color(0.1, 0.07, 0.05, 0.35), 3.0, true)
			canvas.draw_line(sp[0] + Vector2(0, 3), sp[1] + Vector2(0, 3), Color(0.1, 0.07, 0.05, 0.2), 2.0, true)
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
		var wall: bool = d.get("raw", false)
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
	# Settled debris rests on the floor under the fighters; pieces still in
	# flight are drawn on this layer, above them (see _draw).
	for c in _debris:
		if c["vel"] != Vector2.ZERO:
			continue
		_draw_chip(canvas, c)


## One debris chip or splinter.
static func _draw_chip(canvas: CanvasItem, c: Dictionary, at: Vector2 = Vector2.INF, angle: float = INF) -> void:
	if at == Vector2.INF:
		at = c["pos"]
	if angle == INF:
		angle = c["angle"]
	var a := 1.0 - smoothstep(0.75, 1.0, float(c["age"]) / DEBRIS_LIFE)
	var col: Color = c["color"]
	col.a *= a
	var s: float = c["size"]
	if c.has("shape"):
		var shp: PackedVector2Array = c["shape"]
		var xf := Transform2D(angle, at)
		var poly := xf * shp
		var lit := PackedVector2Array()
		for q in shp:
			lit.append(xf * (q * 0.6 + Vector2(-1.5, -1.5)))
		canvas.draw_colored_polygon(poly, col)
		canvas.draw_colored_polygon(lit, Color(col.lightened(0.3), col.a))
		var edge := poly.duplicate()
		edge.append(poly[0])
		canvas.draw_polyline(edge, Color(0.06, 0.04, 0.03, 0.7 * col.a), 1.2, true)
		return
	if c.get("stick", false):
		# Splinter: a thin tapered sliver.
		var ax := Vector2.from_angle(angle) * s * 0.5
		var nx := Vector2(-ax.y, ax.x).normalized() * 1.8
		canvas.draw_colored_polygon(PackedVector2Array([at - ax, at + nx, at + ax, at - nx]), col)
		return
	var pts2 := PackedVector2Array()
	for k in 4:
		pts2.append(at + Vector2.from_angle(angle + k * TAU / 4.0) * s * (1.0 if k % 2 == 0 else 0.6))
	canvas.draw_colored_polygon(pts2, col)


## The additive light layer.
func _draw_glow() -> void:
	for e in _effects:
		if not e.has("glow"):
			continue
		var t := _drawn_t(e)
		var color: Color = e["color"]
		var pos: Vector2 = _drawn_pos(e)
		match e["kind"]:
			"flare":
				var size: float = e["size"]
				var pop := minf(t * 5.0, 1.0)
				var fade := pow(1.0 - t, 1.3)
				_soft_disc(_glow, pos, size * (0.55 + 0.3 * pop) * (1.0 - t * 0.5), Color(color, 0.35 * fade))
				_soft_disc(_glow, pos, size * 0.28 * (1.0 - t * 0.6), Color(GLOW_HOT, 0.9 * fade))
				var rays: PackedVector3Array = e["lines"]
				for r in rays:
					var d := Vector2.from_angle(r.x)
					var n := Vector2(-d.y, d.x)
					var ln := size * 1.5 * r.y * (0.35 + 0.65 * pop)
					var w := 5.0 * r.z * fade + 0.5
					_glow.draw_colored_polygon(PackedVector2Array([pos + n * w, pos + d * ln, pos - n * w]), Color(color, 0.75 * fade))
					_glow.draw_colored_polygon(PackedVector2Array([pos + n * w * 0.4, pos + d * ln * 0.7, pos - n * w * 0.4]), Color(GLOW_HOT, 0.8 * fade))
			"ewave":
				# Stacked crescents: a wide soft one, a bright one and a thin
				# leading edge; they open up as they travel.
				var fade2 := pow(1.0 - t, 0.9)
				var r0: float = e["size"] * (0.45 + t * 0.9)
				var wd: float = e["dir"]
				var open := 0.85 + t * 0.35
				for k in 4:
					var rr := r0 * (1.0 - k * 0.1)
					var col := Color(color, (0.3 + k * 0.2) * fade2)
					_glow.draw_arc(pos - Vector2.from_angle(wd) * r0 * 0.6, rr, wd - open, wd + open, 32, col, (22.0 - k * 5.0) * fade2 + 1.5, true)
				_glow.draw_arc(pos - Vector2.from_angle(wd) * r0 * 0.6, r0 * 1.04, wd - open * 0.9, wd + open * 0.9, 28, Color(GLOW_HOT, 0.7 * fade2), 2.5, true)
			"garcs":
				var a0: float = e["angle"] + t * 7.0
				var sr: float = e["size"]
				var ga := 0.7 * (1.0 - t)
				_glow.draw_set_transform(pos, 0.0, Vector2(1.0, 0.38))
				_glow.draw_arc(Vector2.ZERO, sr * (1.0 + t * 0.25), a0, a0 + 2.6, 24, Color(color, ga), 7.0 * (1.0 - t) + 1.0, true)
				_glow.draw_arc(Vector2.ZERO, sr * 0.8, a0 + PI, a0 + PI + 2.0, 20, Color(GLOW_HOT, ga * 0.7), 3.0, true)
				_glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"score":
				# The contact itself: a tight hot core along the blow.
				var fk := 1.0 - t
				_glow.draw_set_transform(pos, e["dir"], Vector2(2.4, 0.5))
				_glow.draw_circle(Vector2.ZERO, e["size"] * 1.9, Color(STRIKE_WARM, 0.22 * fk))
				_glow.draw_circle(Vector2.ZERO, e["size"] * (1.0 - t * 0.4), Color(color, 0.95 * fk))
				_glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"needle":
				# A thin tapered spark: travels out fast and decelerates, tip
				# white-hot, tail cooling to warm; shortens as it fades.
				var u := 1.0 - pow(1.0 - t, 3.0)
				var d := Vector2.from_angle(e["dir"])
				var n := Vector2(-d.y, d.x)
				var head := pos + d * (6.0 + float(e["size"]) * u)
				var ln: float = e["len"] * (1.0 - t * 0.6)
				var w: float = e["width"] * (1.0 - t * 0.5)
				var a := pow(1.0 - t, 1.2)
				var mid := head - d * ln * 0.3
				_glow.draw_colored_polygon(PackedVector2Array([head - d * ln, mid + n * w, head, mid - n * w]), Color(STRIKE_WARM, 0.75 * a))
				_glow.draw_colored_polygon(PackedVector2Array([head - d * ln * 0.5, mid + n * w * 0.45, head, mid - n * w * 0.45]), Color(color, 0.95 * a))
			"shock":
				# Pressure ring: thin, fast, flattened across the line of the blow.
				var u := 1.0 - pow(1.0 - t, 2.2)
				var r: float = e["size"] * (0.2 + 0.8 * u)
				_glow.draw_set_transform(pos, e["dir"], Vector2(0.45, 1.0))
				_glow.draw_arc(Vector2.ZERO, r, 0.0, TAU, 56, Color(color, 0.7 * pow(1.0 - t, 1.5)), maxf(2.6 * (1.0 - t), 0.6), true)
				_glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"lens":
				# Anamorphic streak through the knockout contact.
				var open := minf(t * 6.0, 1.0)
				var la := pow(1.0 - t, 1.6)
				var half: float = e["size"] * (0.5 + 0.5 * open)
				_glow.draw_line(pos - Vector2(half, 0.0), pos + Vector2(half, 0.0), Color(STRIKE_WARM, 0.35 * la), 3.0, true)
				_glow.draw_line(pos - Vector2(half * 0.55, 0.0), pos + Vector2(half * 0.55, 0.0), Color(color, 0.8 * la), 1.2, true)
			"speed":
				var sd: Vector2 = e["dir"]
				var sl: float = e["size"]
				_glow.draw_line(pos, pos - sd * sl * (1.0 - t * 0.4), Color(color, 0.6 * (1.0 - t)), 3.0 * (1.0 - t) + 0.8, true)
			"streaks":
				pass


## Soft round light: a few concentric discs, brighter at the centre.
static func _soft_disc(canvas: CanvasItem, pos: Vector2, r: float, color: Color) -> void:
	for i in 4:
		var k := 1.0 - i * 0.22
		canvas.draw_circle(pos, r * k, Color(color, color.a * 0.3))


## Floorboard hole: splintered raw-wood ring, dark broken hole, deeper core,
## a lit near rim (toward the viewer) and a dark far rim.
static func _draw_floor_hole(canvas: CanvasItem, d: Dictionary, g: float) -> void:
	var centre: Vector2 = d["pos"]
	var pts: PackedVector2Array = d["pts"]
	var ring := PackedVector2Array()
	var hole := PackedVector2Array()
	var core := PackedVector2Array()
	var k := 0.45 + 0.55 * g
	for p in pts:
		ring.append(centre + (p - centre) * 1.28 * k)
		hole.append(centre + (p - centre) * k)
		core.append(centre + (p - centre) * 0.55 * k + Vector2(0.0, -1.5))
	canvas.draw_colored_polygon(ring, RAW_WOOD)
	canvas.draw_colored_polygon(hole, Color(0.08, 0.06, 0.05, 0.96))
	canvas.draw_colored_polygon(core, Color(0.02, 0.015, 0.01, 0.95))
	var near := PackedVector2Array()
	var far := PackedVector2Array()
	for p in hole:
		if p.y >= centre.y:
			near.append(p)
		else:
			far.append(p)
	if near.size() >= 2:
		canvas.draw_polyline(near, Color(0.7, 0.56, 0.4, 0.8), 1.6, true)
	if far.size() >= 2:
		canvas.draw_polyline(far, Color(0.03, 0.02, 0.015, 0.9), 2.0, true)


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
	for c in _debris:
		if c["vel"] != Vector2.ZERO:
			_draw_chip(self, c, _drawn_pos(c), lerp_angle(c.get("prev_angle", c["angle"]), c["angle"], _frac))
	for e in _effects:
		if e.has("glow"):
			continue
		var t := _drawn_t(e)
		var color: Color = e["color"]
		var pos: Vector2 = _drawn_pos(e)
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
			"flash":
				# Hot core stretched along the blow: white centre, coloured halo.
				var fk := 1.0 - t
				var fs: float = e["size"]
				draw_set_transform(pos, e["dir"], Vector2(1.7, 0.6))
				draw_circle(Vector2.ZERO, fs * (0.7 + 0.5 * t), Color(color.r, color.g, color.b, 0.45 * fk))
				draw_circle(Vector2.ZERO, fs * 0.5 * fk, Color(1.0, 1.0, 1.0, 0.95 * fk))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"swing_arc":
				var sa := 1.0 - t
				var r: float = e["size"]
				for k in 2:
					var c2 := Color(1.0, 1.0, 1.0, 0.5 * sa * (1.0 - k * 0.4))
					draw_arc(pos, r - k * 6.0, minf(e["a0"], e["a1"]), maxf(e["a0"], e["a1"]), 16, c2, 6.0 - k * 2.0, true)
			"comic":
				var pop := minf(t * 5.0, 1.0)
				var fade := 1.0 - smoothstep(0.7, 1.0, t)
				var scale := lerpf(0.4, 1.0, pop) * (1.0 + 0.06 * sin(t * 40.0))
				draw_set_transform(pos, e["tilt"], Vector2.ONE * scale)
				var star := PackedVector2Array()
				for k in 18:
					var ang := TAU * k / 18.0
					star.append(Vector2(cos(ang) * 1.5, sin(ang)) * (COMIC_SIZE if k % 2 == 0 else COMIC_SIZE * 0.62))
				draw_colored_polygon(star, Color(color.r, color.g, color.b, 0.95 * fade))
				star.append(star[0])
				draw_polyline(star, Color(0.1, 0.05, 0.05, fade), 3.0, true)
				if _comic_font == null:
					_comic_font = Hud.make_speech_font()
				var text: String = e["text"]
				var ts := _comic_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, COMIC_FONT)
				draw_string_outline(_comic_font, Vector2(-ts.x * 0.5, COMIC_FONT * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
					COMIC_FONT, 4, Color(0.1, 0.05, 0.05, fade))
				draw_string(_comic_font, Vector2(-ts.x * 0.5, COMIC_FONT * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
					COMIC_FONT, Color(1.0, 0.98, 0.9, fade))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"swipe":
				# Curved swipe: an arc sweeping toward the target, thinning out.
				color.a = 0.85 * (1.0 - t)
				var sr: float = e["size"] * (0.8 + t * 0.4)
				var sd: float = e["dir"]
				var turn: float = e["turn"]
				var c := pos - Vector2.from_angle(sd) * sr * 0.6 + Vector2(0.0, sr * 0.55)
				var a0 := sd - turn * 1.9
				var a1 := sd - turn * (0.35 - t * 0.3)
				draw_arc(c, sr, minf(a0, a1), maxf(a0, a1), 16, color, 6.0 * (1.0 - t) + 1.0, true)
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
			"blood":
				# A droplet stretched along its motion.
				var bv2: Vector2 = e["vel"]
				var bs: float = e["size"]
				draw_line(pos, pos - bv2 * 0.9, Color(BLOOD_COLOR, 0.9), bs, true)
				draw_circle(pos, bs * 0.55, BLOOD_DARK)
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
			"wave":
				# Crescent pushing outward along its direction, thinning as it goes.
				color.a = 0.8 * (1.0 - t)
				var wr: float = e["size"] * (0.35 + t * 1.3)
				var wd: float = e["dir"]
				draw_arc(pos, wr, wd - 0.85, wd + 0.85, 18, color, 7.0 * (1.0 - t) + 1.0, true)
				draw_arc(pos, wr * 0.8, wd - 0.6, wd + 0.6, 14, Color(color, color.a * 0.5), 3.0 * (1.0 - t) + 0.5, true)
			"swirl":
				# Two flattened arcs circling the body like a wind trail.
				color.a = 0.55 * (1.0 - t)
				var sr: float = e["size"]
				var sa: float = e["angle"] + t * 6.0
				draw_set_transform(pos, 0.0, Vector2(1.0, 0.32))
				draw_arc(Vector2.ZERO, sr * (1.0 + t * 0.3), sa, sa + 2.2, 20, color, 4.0 * (1.0 - t) + 1.0, true)
				draw_arc(Vector2.ZERO, sr * (0.8 + t * 0.3), sa + PI, sa + PI + 1.8, 16, color, 3.0 * (1.0 - t) + 1.0, true)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"streaks":
				color.a = 0.9 * (1.0 - t)
				var sl: PackedVector3Array = e["lines"]
				var ln: float = e["length"]
				for l in sl:
					var d := Vector2.from_angle(l.x)
					var s0 := l.y + t * ln * 1.4
					draw_line(pos + d * s0, pos + d * (s0 + ln * l.z * (1.0 - t * 0.6)), color, 2.5 * (1.0 - t) + 0.8, true)
			"cloud":
				# Billowing puff: shaded underside, body, lit top; swells and
				# lingers, then thins out.
				var ca := 0.5 * minf(t * 6.0, 1.0) * pow(1.0 - t, 0.8)
				var cr: float = e["size"] * (0.55 + t * 1.1)
				# Soft edges: each layer is a few concentric discs, denser inside.
				for k in 3:
					var f := 1.0 - k * 0.18
					draw_circle(pos + Vector2(0.0, cr * 0.18), cr * f, Color(0.42, 0.35, 0.28, ca * 0.3))
					draw_circle(pos, cr * 0.9 * f, Color(color, ca * 0.38))
				draw_circle(pos + Vector2(-cr * 0.2, -cr * 0.25), cr * 0.5, Color(0.9, 0.82, 0.7, ca * 0.35))
			"dust":
				color.a = 0.5 * (1.0 - t)
				var ds: float = e["size"]
				for side in [-1.0, 1.0]:
					for j in 3:
						var puff := pos + Vector2(side * (8.0 + t * 30.0 + j * 7.0) * ds, -4.0 - j * 2.0 - t * 7.0 * ds)
						draw_circle(puff, (6.0 - j * 1.5) * (1.0 - t * 0.4) * ds, color)
