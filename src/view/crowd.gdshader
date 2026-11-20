// Vertex-animated crowd. One draw call per character kind.
// Per instance:
//   INSTANCE_CUSTOM = (first frame, frame count, start time on the crowd clock, fps; fps < 0 plays once)
//   COLOR           = (team colour rgb, hit flash 0..1)
shader_type spatial;
render_mode cull_back, specular_disabled;

const float WRAP = 64.0; // CrowdClock.WRAP

uniform sampler2D albedo : source_color, filter_linear_mipmap;
uniform sampler2D team_mask : filter_nearest;
uniform highp sampler2D positions : filter_nearest;
uniform sampler2D normals : filter_nearest;
uniform int width = 1;
uniform int rows_per_frame = 1;
uniform float clock = 0.0;

varying vec4 tint;

ivec2 texel(int vid, int frame) {
	return ivec2(vid % width, frame * rows_per_frame + vid / width);
}

void vertex() {
	float fps = INSTANCE_CUSTOM.w;
	float frames = INSTANCE_CUSTOM.y;
	float f = mod(clock - INSTANCE_CUSTOM.z + WRAP, WRAP) * abs(fps);
	f = fps > 0.0 ? mod(f, frames) : min(f, frames - 1.0);
	int f0 = int(f);
	int f1 = fps > 0.0 ? (f0 + 1) % int(frames) : min(f0 + 1, int(frames) - 1);
	float a = fract(f);
	int first = int(INSTANCE_CUSTOM.x + 0.5);
	ivec2 t0 = texel(VERTEX_ID, first + f0);
	ivec2 t1 = texel(VERTEX_ID, first + f1);
	VERTEX = mix(texelFetch(positions, t0, 0).xyz, texelFetch(positions, t1, 0).xyz, a);
	NORMAL = normalize(mix(texelFetch(normals, t0, 0).xyz, texelFetch(normals, t1, 0).xyz, a) * 2.0 - 1.0);
	tint = COLOR;
}

void fragment() {
	vec3 tex = texture(albedo, UV).rgb;
	float team = texture(team_mask, UV).r;
	float luma = dot(tex, vec3(0.299, 0.587, 0.114));
	vec3 c = mix(tex, tint.rgb * (0.3 + luma * 1.4), team);
	ALBEDO = mix(c, vec3(1.0), tint.a);
}
