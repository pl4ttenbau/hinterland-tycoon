shader_type spatial;
render_mode cull_disabled;

uniform sampler2D grass_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform float draw_distance = 16.0;
uniform float fade_start = 10.0;
uniform float wind_strength : hint_range(0.0, 0.2) = 0.055;
uniform float saturation : hint_range(0.0, 1.0) = 0.8;
varying float blade_height;
varying float variation;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	float distance_to_camera = distance(root, CAMERA_POSITION_WORLD);
	float fade = 1.0 - smoothstep(fade_start, draw_distance, distance_to_camera);
	// Thin the distant population smoothly as well as shrinking its silhouettes.
	float coverage = mix(1.0, 0.35, smoothstep(5.0, draw_distance, distance_to_camera));
	fade *= smoothstep(INSTANCE_CUSTOM.x - 0.12, INSTANCE_CUSTOM.x + 0.12, coverage);
	blade_height = clamp(VERTEX.y, 0.0, 1.0);
	variation = INSTANCE_CUSTOM.z;
	VERTEX *= fade;
	float wind = sin(TIME * 1.7 + root.x * 0.6 + root.z * 0.3);
	VERTEX.x += wind * blade_height * blade_height * wind_strength * fade;
	// Cards receive light from either side without casting extra shadows.
}

void fragment() {
	vec4 tex = texture(grass_texture, UV);
	ALBEDO = tex.rgb * mix(vec3(0.78, 0.85, 0.7), vec3(1.08, 1.03, 0.85), variation);
	ALBEDO *= mix(0.8, 1.0, blade_height) * COLOR.rgb;
	float luminance = dot(ALBEDO, vec3(0.2126, 0.7152, 0.0722));
	ALBEDO = mix(vec3(luminance), ALBEDO, saturation);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.35;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
	BACKLIGHT = vec3(0.2);
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}
