// Terrain3D GPU placement, adapted from its particle_example (Cory Petkovsek,
// Roope Palmroos and contributors). Work runs at tile creation, not per blade/frame.
shader_type particles;
render_mode disable_velocity, disable_force;

uniform uint instance_rows = 16u;
uniform float instance_spacing = 1.0;
uniform float density = 0.75;
uniform uint grass_texture_mask = 1u;
uniform bool grass_area_mask_enabled = false;
uniform bool grass_area_includes_terrain = false;
uniform sampler2D grass_area_mask : hint_default_white, filter_linear, repeat_disable;
uniform vec2 grass_area_origin = vec2(0.0);
uniform vec2 grass_area_size = vec2(1.0);
uniform float minimum_normal_y = 0.85;
uniform float _vertex_spacing = 1.0;
uniform float _region_size = 256.0;
uniform int _region_map[1024];
uniform highp sampler2DArray _height_maps : repeat_disable;
uniform highp sampler2DArray _control_maps : repeat_disable;
uniform highp sampler2DArray _color_maps : repeat_disable;
uniform int water_count = 0;
uniform mat4 water_inverse[32];
uniform vec4 water_limits[32];

// Bounds must be checked before the array read (outside Terrain3D's 32x32 map).
ivec3 terrain_index(vec2 grid) {
	ivec2 region = ivec2(floor(grid / _region_size)) + ivec2(16);
	if (any(lessThan(region, ivec2(0))) || any(greaterThanEqual(region, ivec2(32)))) {
		return ivec3(0, 0, -1);
	}
	return ivec3(ivec2(mod(grid, _region_size)), _region_map[region.y * 32 + region.x] - 1);
}

float random(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float grass_weight(uint control) {
	uint base = (control >> 27u) & 31u;
	uint over = (control >> 22u) & 31u;
	float blend = float((control >> 14u) & 255u) / 255.0;
	return mix(float((grass_texture_mask >> base) & 1u), float((grass_texture_mask >> over) & 1u), blend);
}

bool place(uint index, vec3 emitter, inout mat4 transform, inout vec4 color, inout vec4 custom) {
	vec2 cell = vec2(float(index % instance_rows), float(index / instance_rows));
	vec2 anchor = emitter.xz + (cell + 0.5) * instance_spacing;
	vec3 r = vec3(random(anchor), random(anchor + 7.13), random(anchor - 3.71));
	vec2 xz = anchor + (r.xz - 0.5) * instance_spacing * 0.8;
	vec2 grid = xz / _vertex_spacing;
	vec2 base_grid = floor(grid);
	vec2 f = fract(grid);
	ivec3 a = terrain_index(base_grid);
	ivec3 b = terrain_index(base_grid + vec2(1, 0));
	ivec3 c = terrain_index(base_grid + vec2(0, 1));
	ivec3 d = terrain_index(base_grid + vec2(1, 1));
	transform = mat4(1.0);
	// Rejected particles are inactive: no NaNs or remote coordinates in culling bounds.
	if (min(min(a.z, b.z), min(c.z, d.z)) < 0 || r.y > density) {
		return false;
	}
	vec4 h = vec4(texelFetch(_height_maps, a, 0).r, texelFetch(_height_maps, b, 0).r,
		texelFetch(_height_maps, c, 0).r, texelFetch(_height_maps, d, 0).r);
	vec4 w = vec4((1.0-f.x)*(1.0-f.y), f.x*(1.0-f.y), (1.0-f.x)*f.y, f.x*f.y);
	float height = dot(h, w);
	vec3 normal = normalize(vec3(mix(h.x-h.y, h.z-h.w, f.y), _vertex_spacing,
		mix(h.x-h.z, h.y-h.w, f.x)));
	uvec4 control = floatBitsToUint(vec4(texelFetch(_control_maps, a, 0).r,
		texelFetch(_control_maps, b, 0).r, texelFetch(_control_maps, c, 0).r, texelFetch(_control_maps, d, 0).r));
	// Blend terrain eligibility at the root instead of clipping whole terrain cells.
	// Current maps disable auto shading, so its control flag is ignored.
	vec4 coverage = vec4(grass_weight(control.x), grass_weight(control.y),
		grass_weight(control.z), grass_weight(control.w));
	if (any(notEqual(control & uvec4(4u), uvec4(0u))) || normal.y < minimum_normal_y) {
		return false;
	}
	float allowance = grass_area_mask_enabled && grass_area_includes_terrain ? 1.0 : smoothstep(0.25, 0.9, dot(coverage, w));
	if (grass_area_mask_enabled) {
		vec2 uv = (xz - grass_area_origin) / grass_area_size;
		if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
			return false;
		}
		allowance *= textureLod(grass_area_mask, uv, 0.0).r;
	}
	// Fixed independent randomness turns gray coverage into stable density, not
	// translucent cards or rectangular blocks. A zero allowance always rejects.
	if (allowance <= 0.0 || random(anchor + vec2(19.37, 41.91)) >= allowance) {
		return false;
	}
	vec3 pos = vec3(xz.x, height, xz.y);
	for (int i = 0; i < water_count; i++) {
		vec3 local = (water_inverse[i] * vec4(pos, 1.0)).xyz;
		if (pos.y < water_limits[i].z && all(lessThanEqual(abs(local.xz), water_limits[i].xy))) {
			return false;
		}
	}
	// Stay mostly upright, with some slope alignment and a small buried root.
	vec3 up = normalize(mix(vec3(0, 1, 0), normal, 0.3));
	vec3 right = normalize(cross(up, vec3(0, 0, 1)));
	vec3 forward = cross(right, up);
	float angle = r.x * TAU;
	float size = mix(0.45, 0.7, r.z);
	transform[0].xyz = (right * cos(angle) + forward * sin(angle)) * size;
	transform[1].xyz = up * size;
	transform[2].xyz = (forward * cos(angle) - right * sin(angle)) * size;
	transform[3].xyz = pos - vec3(0, 0.035, 0);
	color = texelFetch(_color_maps, a, 0);
	custom = vec4(r, size);
	return true;
}

void start() {
	ACTIVE = place(INDEX, EMISSION_TRANSFORM[3].xyz, TRANSFORM, COLOR, CUSTOM);
}

void process() {
	// Placement stays fixed between tile recycling; wind/fade run in the draw shader.
}
