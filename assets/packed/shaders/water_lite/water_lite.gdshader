shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

// Linear RGB DATA: RG = OpenGL normal XY, B = roughness. Not hint_normal!
uniform sampler2D surface_data : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 water_color : source_color = vec3(0.04, 0.095, 0.095);
uniform vec3 bank_color : source_color = vec3(0.095, 0.17, 0.13);
uniform float tile_meters : hint_range(1.0, 80.0) = 14.0;
uniform float normal_strength : hint_range(0.0, 2.5) = 0.85;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.45;
uniform float roughness_offset : hint_range(-0.1, 0.3) = 0.0;
// Metres/second in world XZ. A weak drift, not aligned wave crests.
uniform vec2 drift_a = vec2(0.045, 0.021);
uniform vec2 drift_b = vec2(-0.027, 0.038);
uniform float animation_speed : hint_range(0.0, 3.0) = 1.0;
// Optional artist-painted vertex RED masks the bank tint (0 = deep, 1 = bank).
uniform float vertex_bank_tint : hint_range(0.0, 1.0) = 0.0;
uniform float distance_softening_start = 80.0;
uniform float distance_softening_end = 550.0;

varying vec2 world_xz;

vec3 unpack_normal(vec2 encoded) {
	vec2 xy = encoded * 2.0 - 1.0;
	return vec3(xy, sqrt(max(1.0 - dot(xy, xy), 0.001)));
}

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float clock = TIME * animation_speed;
	vec2 uv_a = (world_xz - drift_a * clock) / tile_meters;
	vec2 uv_b = (world_xz - drift_b * clock) / tile_meters * 1.913 + vec2(0.371, 0.619);
	vec3 a = texture(surface_data, uv_a).rgb;
	vec3 b = texture(surface_data, uv_b).rgb;
	vec3 na = unpack_normal(a.rg);
	vec3 nb = unpack_normal(b.rg);
	// Combine slopes instead of averaging encoded colours (which flattens normals).
	vec2 slope = na.xy / na.z + detail_strength * nb.xy / nb.z;
	float far_blend = smoothstep(distance_softening_start, distance_softening_end, length(VERTEX));
	slope *= normal_strength * mix(1.0, 0.22, far_blend);
	vec3 world_normal = normalize(vec3(slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
	ALBEDO = mix(water_color, bank_color, COLOR.r * vertex_bank_tint);
	METALLIC = 0.0;
	// Godot F0 = 0.16 * SPECULAR^2. 0.35 gives water-like ~2% F0.
	SPECULAR = 0.35;
	ROUGHNESS = clamp(mix(a.b, b.b, 0.35) + roughness_offset + far_blend * 0.1, 0.055, 0.4);
}
