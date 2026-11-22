// Vertex-animated crowd. One draw call per character kind.
// Per instance:
//   INSTANCE_CUSTOM = (first frame, frame count, start time on the crowd clock, fps; fps < 0 plays once)
//   COLOR           = (team colour rgb, hit flash 0..1)
shader_type spatial;
render_mode cull_back;

const float WRAP = 64.0; // CrowdClock.WRAP

uniform sampler2D albedo : source_color, filter_linear_mipmap;
uniform sampler2D team_mask : filter_nearest;
uniform sampler2D positions : filter_nearest;   // 8 bits per axis within the bake's bounds
uniform vec3 bounds_min;
uniform vec3 bounds_size;
uniform sampler2D normals : filter_nearest;
uniform int width = 1;
uniform int rows_per_frame = 1;
uniform float clock = 0.0;

varying vec4 tint;
varying float height;   // 0 at the feet, 1 at the top of the bake
varying float shade;    // each figure a little lighter or darker than its neighbours

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
	VERTEX = bounds_min + bounds_size * mix(texelFetch(positions, t0, 0).xyz, texelFetch(positions, t1, 0).xyz, a);
	NORMAL = normalize(mix(texelFetch(normals, t0, 0).xyz, texelFetch(normals, t1, 0).xyz, a) * 2.0 - 1.0);
	tint = COLOR;
	shade = 0.86 + 0.28 * fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453);
	height = clamp((VERTEX.y - bounds_min.y) / max(bounds_size.y, 0.001), 0.0, 1.0);
}

void fragment() {
	vec3 tex = texture(albedo, UV).rgb;
	float team = texture(team_mask, UV).r;
	float luma = dot(tex, vec3(0.299, 0.587, 0.114));
	// Team colour dyes the cloth but keeps its shading and some of its own hue,
	// so folds, trims and straps still read.
	vec3 dyed = tint.rgb * (0.25 + luma * 1.5);
	vec3 c = mix(tex, mix(dyed, dyed * tex * 2.0, 0.3), team) * shade;
	// Ambient shading: darker toward the feet, where the crowd crowds the light out.
	c *= mix(0.5, 1.0, smoothstep(0.0, 0.55, height));
	// A dark silhouette edge where the surface turns away from the eye: a cheap
	// outline that parts one figure from the next in a dense crowd.
	c *= mix(0.3, 1.0, smoothstep(0.05, 0.4, dot(NORMAL, VIEW)));
	ALBEDO = mix(c, vec3(1.0), tint.a);
	ROUGHNESS = 0.55;
	SPECULAR = 0.35;
	RIM = 0.45;            // a bright edge against the deck: the figure stands out in depth
	RIM_TINT = 0.35;
}
