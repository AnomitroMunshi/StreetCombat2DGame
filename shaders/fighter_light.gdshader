shader_type canvas_item;
// The arena's light on a fighter (FighterVisual.set_scene_light): the scene's
// ambient colour, a key light and an optional fill from fixed world
// directions. The body is shaded like a rounded volume around its centre, so
// the side facing the light brightens and the far side falls into the
// ambient shadow whichever way the fighter faces; feet near the floor sit a
// little darker (contact occlusion).

uniform vec3 ambient = vec3(1.0);
uniform vec3 key_color = vec3(1.0);
// Direction TOWARD the light, in world space (y down: upper left = (-0.7, -0.7)).
uniform vec2 key_dir = vec2(-0.7, -0.7);
uniform float key_strength = 0.0;
uniform vec3 fill_color = vec3(1.0);
uniform vec2 fill_dir = vec2(0.7, -0.7);
uniform float fill_strength = 0.0;
// The body's centre and half extents, world px (updated every frame).
uniform vec2 centre = vec2(0.0);
uniform vec2 radius = vec2(48.0, 96.0);
uniform float floor_y = 560.0;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = (world - centre) / radius;
	float r = length(p);
	vec2 n = r > 0.001 ? p / r : vec2(0.0);
	float reach = clamp(r * 1.4, 0.0, 1.0);
	float k = dot(n, normalize(key_dir)) * reach;
	float f = dot(n, normalize(fill_dir)) * reach;
	vec3 light = ambient * (1.0 - key_strength * 0.6 * max(-k, 0.0));
	light += key_color * key_strength * 0.7 * max(k, 0.0);
	light += fill_color * fill_strength * 0.7 * max(f, 0.0);
	light *= mix(0.86, 1.0, smoothstep(0.0, 40.0, floor_y - world.y));
	COLOR.rgb *= light;
}
