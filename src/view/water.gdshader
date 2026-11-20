// Open water: deep-to-shallow colour by view angle, with small moving waves
// from summed sines. No screen or depth textures, so it runs on Compatibility.
shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec3 deep : source_color = vec3(0.03, 0.16, 0.33);
uniform vec3 shallow : source_color = vec3(0.1, 0.38, 0.56);

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world.xz;
	float t = TIME;
	vec2 slope = vec2(
		cos(p.x * 0.9 + t * 1.3) * 0.5 + cos(p.x * 2.3 - p.y * 1.1 + t * 2.1) * 0.25,
		cos(p.y * 0.7 - t * 1.1) * 0.5 + cos(p.y * 2.7 + p.x * 0.8 + t * 1.7) * 0.25);
	vec3 n = normalize(vec3(-slope.x * 0.12, 1.0, -slope.y * 0.12));
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = mix(shallow, deep, facing);
	ROUGHNESS = 0.15;
	METALLIC = 0.0;
	SPECULAR = 0.35;
}
