// Sandstone paving in world space: staggered slabs with grout lines and a
// per-slab tint, so a single box reads as a laid bridge deck.
shader_type spatial;
render_mode specular_disabled;

uniform vec3 stone : source_color = vec3(0.8, 0.66, 0.52);
uniform vec3 grout : source_color = vec3(0.5, 0.37, 0.3);
uniform vec2 slab = vec2(1.6, 1.1);

varying vec3 world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Top face paves along x/z; the sides show courses of blocks along x/z and y.
	vec2 p = abs(NORMAL.y) > 0.5 ? world.xz : vec2(world.x + world.z, world.y * 1.4);
	vec2 cell = p / slab;
	cell.x += step(1.0, mod(floor(cell.y), 2.0)) * 0.5;   // stagger every other row
	vec2 id = floor(cell);
	vec2 f = fract(cell);
	float edge = min(min(f.x, 1.0 - f.x) * slab.x, min(f.y, 1.0 - f.y) * slab.y);
	float line = smoothstep(0.02, 0.06, edge);
	vec3 tint = stone * (0.88 + 0.16 * hash(id));
	ALBEDO = mix(grout, tint, line);
	ROUGHNESS = 0.9;
}
