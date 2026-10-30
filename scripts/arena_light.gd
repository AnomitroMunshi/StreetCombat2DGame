class_name ArenaLight
extends Node2D
## The arena's light over the whole scene (backdrop, props, damage and both
## fighters alike), above the fighters and under the hit effects: an additive
## glow falling in from the key light's side (and from the fill light where a
## scene has one, e.g. the neon street's red and cyan signs) and a multiplied
## falloff that sinks the far side into the scene's shade. Reads the same
## fighter_light dictionary the fighters' shader uses; empty = no overlay.

## Gradient circle radius (world px): large enough that the far colour covers
## the whole camera range (StyleStage.VIEW) from a light placed off-stage.
const RADIUS: float = 2400.0
## How far off-stage (from the arena centre, along the light direction) the
## light source sits.
const SOURCE_DISTANCE: float = 1000.0
const CENTRE := Vector2(640.0, 380.0)

var _glow: Node2D
var _shade: Node2D
var _glows: Array = []  # [texture, rect, flicker]
var _shade_tex: Texture2D = null
var _shade_rect := Rect2()
var _flicker: float = 1.0
var _time: float = 0.0


func _ready() -> void:
	_shade = _layer(CanvasItemMaterial.BLEND_MODE_MUL, _draw_shade)
	_glow = _layer(CanvasItemMaterial.BLEND_MODE_ADD, _draw_glow)


func _layer(mode: CanvasItemMaterial.BlendMode, drawer: Callable) -> Node2D:
	var n := Node2D.new()
	var m := CanvasItemMaterial.new()
	m.blend_mode = mode
	n.material = m
	n.draw.connect(drawer)
	add_child(n)
	return n


func setup(light: Dictionary) -> void:
	_glows.clear()
	_shade_tex = null
	if not light.is_empty():
		var key := _color(light.get("key", [1, 1, 1]))
		var key_dir := _dir(light.get("key_dir", [-0.7, -0.7]))
		var strength := float(light.get("key_strength", 0.0))
		_add_glow(key, key_dir, float(light.get("arena_glow", strength * 0.32)), bool(light.get("flicker", false)))
		if light.has("fill"):
			_add_glow(_color(light["fill"]), _dir(light.get("fill_dir", [0.7, -0.7])),
				float(light.get("arena_glow", float(light.get("fill_strength", 0.0)) * 0.32)), bool(light.get("flicker", false)))
		# The far side falls toward the ambient shade.
		var ambient := _color(light.get("ambient", [1, 1, 1]))
		var far := Color.WHITE.lerp(ambient * (1.0 - float(light.get("arena_shade", strength * 0.4))), 0.8)
		far.a = 1.0
		var source := CENTRE + key_dir * SOURCE_DISTANCE
		_shade_tex = _radial([0.0, 0.4, 1.0], [Color.WHITE, Color.WHITE, far])
		_shade_rect = Rect2(source - Vector2.ONE * RADIUS, Vector2.ONE * RADIUS * 2.0)
	visible = not light.is_empty()
	_glow.queue_redraw()
	_shade.queue_redraw()


func _add_glow(color: Color, dir: Vector2, amount: float, flicker: bool) -> void:
	if amount <= 0.0:
		return
	var c := Color(color.r * amount, color.g * amount, color.b * amount)
	var source := CENTRE + dir * SOURCE_DISTANCE
	var tex := _radial([0.0, 0.3, 0.6, 1.0], [c, c.darkened(0.25), c.darkened(0.75), Color.BLACK])
	_glows.append([tex, Rect2(source - Vector2.ONE * RADIUS, Vector2.ONE * RADIUS * 2.0), flicker])


func _process(delta: float) -> void:
	if not visible or _glows.is_empty():
		return
	for g: Array in _glows:
		if g[2]:
			# A neon sign's hum: a slow wobble with the odd quick dip.
			_time += delta
			_flicker = 0.92 + 0.08 * sin(_time * 2.3) - (0.25 if fmod(_time, 4.7) < 0.06 else 0.0)
			_glow.queue_redraw()
			return


func _draw_glow() -> void:
	for g: Array in _glows:
		var k := _flicker if g[2] else 1.0
		_glow.draw_texture_rect(g[0], g[1], false, Color(k, k, k))


func _draw_shade() -> void:
	if _shade_tex != null:
		_shade.draw_texture_rect(_shade_tex, _shade_rect, false)


static func _radial(offsets: Array, colors: Array) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 256
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


static func _color(c: Array) -> Color:
	return Color(float(c[0]), float(c[1]), float(c[2]))


static func _dir(d: Array) -> Vector2:
	return Vector2(float(d[0]), float(d[1])).normalized()
