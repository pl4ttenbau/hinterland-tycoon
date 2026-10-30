shader_type particles;
render_mode disable_velocity;

// All velocities and wind are world-space; the outlet axis is local +Y.
uniform vec3 vehicle_velocity = vec3(0.0);
uniform vec3 wind_velocity = vec3(0.8, 0.0, 0.0);
uniform float inherited_velocity = 0.85;
uniform float emission_density = 1.0;
uniform float load = 0.65;
uniform float chuff_phase = 0.0;
uniform float pulse_strength = 0.75;
uniform float outlet_radius = 0.14;
uniform float exit_speed = 6.0;
uniform float spread = 0.22;
uniform float drag = 1.7;
uniform float buoyancy = 1.05;
uniform float turbulence = 0.7;
uniform float initial_size = 0.38;
uniform float final_size = 3.4;
uniform float opacity = 0.5;

uint hash_u(uint n) {
	n = (n ^ (n >> 16u)) * 2246822519u;
	n = (n ^ (n >> 13u)) * 3266489917u;
	return n ^ (n >> 16u);
}

float random_f(inout uint state) {
	state = hash_u(state + 747796405u);
	return float(state & 16777215u) / 16777216.0;
}

void start() {
	uint seed = hash_u(NUMBER + RANDOM_SEED + INDEX * 1013u);
	float beat = pow(0.5 + 0.5 * cos(chuff_phase), 3.0);
	float pulse = mix(1.0, 0.12 + 0.88 * beat, pulse_strength);
	// Gating happens only on birth: changing load never deletes an existing puff.
	ACTIVE = random_f(seed) < emission_density * mix(0.23, 1.0, load) * pulse;
	float angle = random_f(seed) * TAU;
	float radius = sqrt(random_f(seed)) * outlet_radius;
	vec3 local_position = vec3(cos(angle) * radius, 0.0, sin(angle) * radius);
	TRANSFORM = mat4(1.0);
	TRANSFORM[3] = EMISSION_TRANSFORM * vec4(local_position, 1.0);
	vec3 axis = normalize((EMISSION_TRANSFORM * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	vec3 sideways = normalize((EMISSION_TRANSFORM * vec4(cos(angle), 0.0, sin(angle), 0.0)).xyz);
	float speed = exit_speed * mix(0.65, 1.15, load) * mix(0.8, 1.2, random_f(seed));
	VELOCITY = (axis + sideways * spread * random_f(seed)) * speed;
	VELOCITY += vehicle_velocity * inherited_velocity;
	// CUSTOM: spin, normalized age, static atlas tile, lifetime multiplier.
	CUSTOM = vec4(random_f(seed) * TAU, 0.0, floor(random_f(seed) * 16.0), mix(0.72, 1.0, random_f(seed)));
	// Two immutable random values survive between simulation frames.
	COLOR = vec4(random_f(seed), random_f(seed), 1.0, 0.0);
	float size = initial_size;
	TRANSFORM[0].xyz = vec3(size, 0.0, 0.0);
	TRANSFORM[1].xyz = vec3(0.0, size, 0.0);
	TRANSFORM[2].xyz = vec3(0.0, 0.0, size);
}

void process() {
	CUSTOM.y += DELTA / (LIFETIME * CUSTOM.w);
	if (CUSTOM.y >= 1.0) {
		ACTIVE = false;
	}
	float age = clamp(CUSTOM.y, 0.0, 1.0);
	float t = age * LIFETIME * CUSTOM.w;
	// Smooth analytic eddies: no 3D noise lookup or particle collision pass.
	vec3 eddy = vec3(sin(t * 1.9 + COLOR.r * TAU), sin(t * 1.3 + COLOR.g * TAU) * 0.2, cos(t * 1.6 + COLOR.g * TAU));
	vec3 target_velocity = wind_velocity + vec3(0.0, buoyancy, 0.0) + eddy * turbulence;
	VELOCITY = mix(VELOCITY, target_velocity, 1.0 - exp(-drag * DELTA));
	TRANSFORM[3].xyz += VELOCITY * DELTA;
	float growth = (1.0 - exp(-age * 2.8)) / (1.0 - exp(-2.8));
	float size = mix(initial_size, final_size, growth) * mix(0.8, 1.2, COLOR.g);
	TRANSFORM[0].xyz = vec3(size, 0.0, 0.0);
	TRANSFORM[1].xyz = vec3(0.0, size, 0.0);
	TRANSFORM[2].xyz = vec3(0.0, 0.0, size);
	CUSTOM.x += (COLOR.r - 0.5) * 0.32 * DELTA;
	COLOR.a = opacity * mix(0.75, 1.0, COLOR.r) * smoothstep(0.0, 0.018, age) * (1.0 - smoothstep(0.25, 1.0, age));
}
