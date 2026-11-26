shader_type spatial;
render_mode cull_disabled;

// Blender atlas: G roughness, B metallic, A Specular IOR Level.
// glTF's specular-texture extension falls back to a constant in Godot's
// StandardMaterial3D importer; retain the approved paint/lamp response here.
uniform sampler2D albedo_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D surface_map : filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_strength = 0.78;

void fragment() {
	vec4 surface = texture(surface_map, UV);
	ALBEDO = texture(albedo_map, UV).rgb;
	ROUGHNESS = surface.g;
	METALLIC = surface.b;
	SPECULAR = surface.a;
	NORMAL_MAP = texture(normal_map, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
}
