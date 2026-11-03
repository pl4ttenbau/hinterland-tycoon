// NOTE: Shader automatically converted from Godot Engine 4.4.1.stable's StandardMaterial3D.

shader_type spatial;
render_mode depth_prepass_alpha, cull_disabled, world_vertex_coords;

uniform vec4 albedo : source_color;
uniform vec4 transmission : source_color;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0, 0.001);
uniform float alpha_antialiasing_edge : hint_range(0.0, 1.0, 0.01);
uniform ivec2 albedo_texture_size;
uniform float point_size : hint_range(0.1, 128.0, 0.1);

uniform float roughness : hint_range(0.0, 1.0);
uniform sampler2D texture_metallic : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r, filter_linear_mipmap, repeat_enable;

uniform float specular : hint_range(0.0, 1.0, 0.01);
uniform float metallic : hint_range(0.0, 1.0, 0.01);

uniform vec4 backlight : source_color;
uniform sampler2D texture_backlight : hint_default_black, filter_linear_mipmap, repeat_enable;

uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;

uniform float sway_speed = 1.0;
uniform float sway_strength = 0.05;
uniform float sway_phase_len = 8.0;

// Approximate canopy occlusion without shadow maps or extra texture samples.
// Dimensions are in mesh-local metres, before the tree instance is scaled.
group_uniforms Canopy_Shading;
uniform float canopy_shade_strength : hint_range(0.0, 1.0, 0.01) = 0.3;
uniform float canopy_radius : hint_range(0.1, 15.0, 0.1) = 4.0;
uniform float canopy_height : hint_range(0.1, 30.0, 0.1) = 10.0;
group_uniforms;

varying float canopy_occlusion;

void vertex() {
    // world_vertex_coords gives world-space VERTEX. Project onto the instance
    // axes to recover local coordinates, including rotated/scaled MultiMeshes.
    // This assumes ordinary TRS transforms (no shear) and avoids a matrix inverse.
    vec3 offset = VERTEX - MODEL_MATRIX[3].xyz;
    vec3 local_position = vec3(
        dot(offset, MODEL_MATRIX[0].xyz) / max(dot(MODEL_MATRIX[0].xyz, MODEL_MATRIX[0].xyz), 0.0001),
        dot(offset, MODEL_MATRIX[1].xyz) / max(dot(MODEL_MATRIX[1].xyz, MODEL_MATRIX[1].xyz), 0.0001),
        dot(offset, MODEL_MATRIX[2].xyz) / max(dot(MODEL_MATRIX[2].xyz, MODEL_MATRIX[2].xyz), 0.0001)
    );
    float inner_shade = 1.0 - smoothstep(0.15, 1.0, length(local_position.xz) / max(canopy_radius, 0.1));
    float lower_shade = 1.0 - smoothstep(0.25, 1.0, local_position.y / max(canopy_height, 0.1));
    canopy_occlusion = inner_shade * 0.65 + lower_shade * 0.35;

    float strength = COLOR.r * sway_strength;
    VERTEX.x += sin(VERTEX.x * sway_phase_len * 1.123 + TIME * sway_speed) * strength;
    VERTEX.y += sin(VERTEX.y * sway_phase_len + TIME * sway_speed * 1.12412) * strength;
    VERTEX.z += sin(VERTEX.z * sway_phase_len * 0.9123 + TIME * sway_speed * 1.3123) * strength;

	UV = UV * uv1_scale.xy + uv1_offset.xy;
}

void fragment() {
	vec2 base_uv = UV;

	vec4 albedo_tex = texture(texture_albedo, base_uv);
	ALBEDO = albedo.rgb * albedo_tex.rgb;
	float canopy_light = 1.0 - canopy_shade_strength * canopy_occlusion;
	AO = canopy_light;
	AO_LIGHT_AFFECT = 0.5;

	float metallic_tex = dot(texture(texture_metallic, base_uv), metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	SPECULAR = specular;

	vec4 roughness_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);
	float roughness_tex = dot(texture(texture_roughness, base_uv), roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
	ALPHA *= albedo.a * albedo_tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	ALPHA_ANTIALIASING_EDGE = alpha_antialiasing_edge;
	ALPHA_TEXTURE_COORDINATE = UV * vec2(albedo_texture_size);

	// Backlight: Enabled
	vec3 backlight_tex = texture(texture_backlight, base_uv).rgb;
	BACKLIGHT = (backlight.rgb + backlight_tex) * canopy_light;
}
