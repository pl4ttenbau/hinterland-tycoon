shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform sampler2D steam_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec4 light_tint : source_color = vec4(1.0, 0.98, 0.93, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.47, 0.56, 0.62, 1.0);
uniform float soot : hint_range(0.0, 1.0) = 0.0;
uniform float soft_intersection : hint_range(0.01, 3.0) = 0.65;
uniform float near_fade = 0.8;
uniform float far_fade_start = 135.0;
uniform float far_fade_end = 180.0;

varying float particle_age;
varying float camera_distance;
varying vec2 tile_origin;

void vertex() {
	float size = length(MODEL_MATRIX[0].xyz);
	float c = cos(INSTANCE_CUSTOM.x);
	float s = sin(INSTANCE_CUSTOM.x);
	mat4 billboard = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	mat4 spin_scale = mat4(vec4(c * size, s * size, 0.0, 0.0), vec4(-s * size, c * size, 0.0, 0.0), vec4(0.0, 0.0, size, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * billboard * spin_scale;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	float tile = INSTANCE_CUSTOM.z;
	tile_origin = vec2(mod(tile, 4.0), floor(tile / 4.0));
	particle_age = INSTANCE_CUSTOM.y;
	camera_distance = length((VIEW_MATRIX * MODEL_MATRIX[3]).xyz);
}

void fragment() {
	// Gentle internal advection adds motion within a puff, at one atlas fetch.
	vec2 p = UV - 0.5;
	float inside = max(0.0, 1.0 - dot(p, p) * 4.0);
	float t = particle_age * 5.0;
	vec2 flow = sin(vec2(p.y * 9.0 + t, p.x * 8.0 - t)) * 0.026 * inside;
	vec2 sprite_uv = clamp(UV + flow, vec2(2.0 / 256.0), vec2(254.0 / 256.0));
	vec4 puff = texture(steam_atlas, (tile_origin + sprite_uv) * 0.25);
	// Erode low-density wisps as steam evaporates instead of just shrinking a disk.
	float erosion = smoothstep(0.25, 1.0, particle_age) * 0.32;
	float alpha = puff.a * smoothstep(erosion, erosion + 0.2, puff.a) * COLOR.a;
	float depth = texture(scene_depth, SCREEN_UV).r;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
	#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	#endif
	vec4 opaque_view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float opaque_distance = -opaque_view.z / opaque_view.w;
	float intersection = clamp((opaque_distance + VERTEX.z) / soft_intersection, 0.0, 1.0);
	alpha *= intersection;
	alpha *= smoothstep(near_fade * 0.35, near_fade, camera_distance);
	alpha *= 1.0 - smoothstep(far_fade_start, far_fade_end, camera_distance);
	vec3 steam_color = mix(shadow_tint.rgb, light_tint.rgb, puff.r);
	vec3 smoke_color = mix(vec3(0.10, 0.115, 0.13), vec3(0.31, 0.30, 0.28), puff.r);
	ALBEDO = mix(steam_color, smoke_color, soot);
	ALPHA = clamp(alpha, 0.0, 0.92);
}
