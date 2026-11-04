shader_type spatial;
render_mode skip_vertex_transform, cull_disabled;

uniform sampler2D wheat_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float draw_distance = 16.0;
uniform float fade_start = 10.0;
uniform float wind_strength : hint_range(0.0, 0.5) = 0.18;
uniform vec2 wind_direction = vec2(1.0, 0.35);
uniform float saturation : hint_range(0.0, 1.0) = 0.85;
varying float blade_height;
varying float variation;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	float fade = 1.0 - smoothstep(fade_start, draw_distance, distance(root, CAMERA_POSITION_WORLD));
	blade_height = clamp(VERTEX.y / 1.8, 0.0, 1.0);
	variation = INSTANCE_CUSTOM.z;
	// Each crossed card selects a different transparent-edged cell of the atlas.
	float cell = floor(fract(INSTANCE_CUSTOM.x + UV2.x) * 3.0);
	UV.x = (UV.x + cell) / 3.0;
	vec3 world_vertex = (MODEL_MATRIX * vec4(VERTEX * fade, 1.0)).xyz;
	vec2 direction = wind_direction / max(length(wind_direction), 0.001);
	float wave = sin(dot(root.xz, direction) * 0.55 - TIME * 1.5) * 0.7;
	wave += sin(dot(root.xz, vec2(-direction.y, direction.x)) * 0.23 - TIME * 2.1) * 0.3;
	float bend = (wave * wind_strength + sin(TIME * 2.7 + INSTANCE_CUSTOM.y * TAU) * 0.02) * fade;
	// Four vertical segments curve towards the wind. Roots are never displaced.
	float flex = blade_height * blade_height;
	world_vertex.xz += direction * bend * flex;
	world_vertex.y -= abs(bend) * flex * 0.12;
	VERTEX = (VIEW_MATRIX * vec4(world_vertex, 1.0)).xyz;
}

void fragment() {
	vec4 tex = texture(wheat_atlas, UV);
	ALBEDO = tex.rgb * mix(vec3(0.92, 0.9, 0.83), vec3(1.08, 1.05, 0.95), variation);
	ALBEDO *= mix(0.78, 1.0, blade_height) * COLOR.rgb;
	float luminance = dot(ALBEDO, vec3(0.2126, 0.7152, 0.0722));
	ALBEDO = mix(vec3(luminance), ALBEDO, saturation);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.35;
	ROUGHNESS = 0.95;
	SPECULAR = 0.05;
	BACKLIGHT = vec3(0.25);
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}
