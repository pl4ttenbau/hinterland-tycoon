@tool
class_name SteamExhaust
extends Node3D
## Attach to a chimney mouth. Local +Y is the exhaust direction. Units are meters.
## Existing particles stay in world space when the locomotive moves or turns.

enum Quality { LOW, BALANCED, HIGH }

const PROCESS_SHADER: Shader = preload("res://addons/steam_exhaust/shaders/exhaust_process.gdshader")
const DRAW_SHADER: Shader = preload("res://addons/steam_exhaust/shaders/exhaust_draw.gdshader")
const ATLAS: Texture2D = preload("res://addons/steam_exhaust/textures/steam_atlas.png")
const PARTICLE_BUDGETS: Array[int] = [128, 256, 512]

@export_group("Drive")
## Set to zero to stop births; already emitted steam dissipates naturally.
@export_range(0.0, 1.0, 0.01) var exhaust_strength: float = 1.0
@export_range(0.0, 1.0, 0.01) var engine_load: float = 0.7
## Disable if you supply vehicle_velocity yourself (e.g. from a physics body).
@export var auto_velocity: bool = true
@export var vehicle_velocity: Vector3 = Vector3.ZERO
@export_range(0.0, 1.0, 0.01) var velocity_inheritance: float = 0.85
@export var wind_velocity: Vector3 = Vector3(0.8, 0.0, 0.0)

@export_group("Exhaust beats")
@export_range(0.1, 3.0, 0.01, "suffix:m") var driving_wheel_diameter: float = 1.2
## Four beats per revolution suits a conventional two-cylinder locomotive.
@export_range(1, 8, 1) var beats_per_revolution: int = 4
## Zero derives beats/second from speed. Set this to drive a stationary preview.
@export_range(0.0, 20.0, 0.1, "suffix:Hz") var chuff_rate_hz: float = 0.0
@export_range(0.0, 1.0, 0.01) var pulse_strength: float = 0.75

@export_group("Plume shape — apply / rebuild after changing")
@export_range(0.01, 0.8, 0.01, "suffix:m") var outlet_radius: float = 0.14
@export_range(0.5, 18.0, 0.1, "suffix:m/s") var exit_speed: float = 6.0
@export_range(0.0, 0.8, 0.01) var spread: float = 0.22
@export_range(0.1, 5.0, 0.05) var drag: float = 1.7
@export_range(0.0, 4.0, 0.05) var buoyancy: float = 1.05
@export_range(0.0, 3.0, 0.05) var turbulence: float = 0.7
@export_range(0.05, 2.0, 0.01, "suffix:m") var initial_size: float = 0.38
@export_range(0.3, 8.0, 0.1, "suffix:m") var final_size: float = 3.4
@export_range(0.5, 10.0, 0.1, "suffix:s") var particle_lifetime: float = 4.8
@export_range(0.0, 1.0, 0.01) var opacity: float = 0.5

@export_group("Appearance")
## Zero is pale steam; increase only if you want combustion smoke in the exhaust.
@export_range(0.0, 1.0, 0.01) var soot: float = 0.0
@export var light_tint: Color = Color(1.0, 0.98, 0.93)
@export var shadow_tint: Color = Color(0.47, 0.56, 0.62)
@export_range(0.05, 3.0, 0.05, "suffix:m") var soft_intersection: float = 0.65

@export_group("Performance")
## Changing budget restarts particles. Distance LOD changes births without restarting.
@export var quality: Quality = Quality.BALANCED
@export_range(5.0, 500.0, 1.0, "suffix:m") var lod_start_distance: float = 45.0
@export_range(10.0, 1000.0, 1.0, "suffix:m") var cull_distance: float = 180.0
## Motion jumps above this are treated as teleports, clearing the old plume.
@export_range(5.0, 200.0, 1.0, "suffix:m") var teleport_distance: float = 25.0

@export_group("Editor")
@export var preview_in_editor: bool = false:
	set(value):
		preview_in_editor = value
		if is_node_ready():
			rebuild()
@export_tool_button("Apply shape / restart preview") var apply_shape: Callable = rebuild

var _simulation: ShaderMaterial
var _appearance: ShaderMaterial
var _previous_position: Vector3
var _phase: float = 0.0
var _external_wheel_angle: float = -1.0
var _lod_timer: float = 0.0
var _distance_density: float = 1.0
var _out_of_range_time: float = 0.0
var _sleeping: bool = false
var _initialized: bool = false
var _peak_motion_speed: float = 0.0
var _peak_speed_hold: float = 0.0

@onready var _plume: GPUParticles3D = $Plume


func _ready() -> void:
	rebuild()


## Recreates per-instance materials. Call after changing static shape/budget settings.
func rebuild() -> void:
	if not is_node_ready():
		return
	_plume.emitting = false
	_plume.amount = PARTICLE_BUDGETS[quality]
	_plume.lifetime = particle_lifetime
	_plume.local_coords = false
	_plume.fixed_fps = 30
	_plume.interpolate = true
	_plume.fract_delta = true
	_plume.preprocess = 0.0
	_plume.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	_plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_simulation = ShaderMaterial.new()
	_simulation.shader = PROCESS_SHADER
	for parameter: StringName in [&"outlet_radius", &"exit_speed", &"spread", &"drag", &"buoyancy", &"turbulence", &"initial_size", &"final_size", &"opacity"]:
		_simulation.set_shader_parameter(parameter, get(parameter))
	_plume.process_material = _simulation
	_appearance = ShaderMaterial.new()
	_appearance.shader = DRAW_SHADER
	_appearance.set_shader_parameter(&"steam_atlas", ATLAS)
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = _appearance
	_plume.draw_pass_1 = quad
	_previous_position = global_position
	_out_of_range_time = 0.0
	_distance_density = 1.0
	_sleeping = false
	_lod_timer = 0.0
	_peak_motion_speed = 0.0
	_peak_speed_hold = 0.0
	_initialized = true
	_plume.speed_scale = 1.0
	_plume.visible = true
	_upload_drive(0.0)
	_update_bounds()
	_plume.emitting = not Engine.is_editor_hint() or preview_in_editor
	_plume.restart()


func _process(delta: float) -> void:
	if not _initialized or (Engine.is_editor_hint() and not preview_in_editor):
		return
	var displacement: Vector3 = global_position - _previous_position
	_previous_position = global_position
	if displacement.length() > teleport_distance:
		reset_trail()
		displacement = Vector3.ZERO
	if auto_velocity and delta > 0.00001:
		vehicle_velocity = displacement / delta
	_lod_timer -= delta
	if _lod_timer <= 0.0:
		_lod_timer = 0.2
		var camera: Camera3D = get_viewport().get_camera_3d()
		var distance: float = global_position.distance_to(camera.global_position) if camera != null else 0.0
		_update_distance_lod(distance)
		_update_bounds()
	if _distance_density <= 0.0:
		_out_of_range_time += delta
		if _out_of_range_time >= particle_lifetime and not _sleeping:
			_sleeping = true
			_plume.speed_scale = 0.0
			_plume.visible = false
	else:
		_out_of_range_time = 0.0
		if _sleeping:
			_sleeping = false
			_plume.speed_scale = 1.0
			_plume.visible = true
			reset_trail()
	_plume.emitting = not _sleeping and _distance_density > 0.0 and exhaust_strength > 0.0
	if not _sleeping:
		_upload_drive(delta)


func _update_distance_lod(distance: float) -> void:
	var end: float = maxf(cull_distance, lod_start_distance + 1.0)
	_distance_density = 1.0 - smoothstep(lod_start_distance, end, distance)
	_appearance.set_shader_parameter(&"far_fade_start", end * 0.75)
	_appearance.set_shader_parameter(&"far_fade_end", end)


func _upload_drive(delta: float) -> void:
	var frequency: float = chuff_rate_hz
	if frequency <= 0.0:
		frequency = vehicle_velocity.length() * float(beats_per_revolution) / (PI * driving_wheel_diameter)
	if _external_wheel_angle >= 0.0:
		_phase = fposmod(_external_wheel_angle * float(beats_per_revolution), TAU)
	else:
		_phase = fposmod(_phase + delta * frequency * TAU, TAU)
	# At high speed individual beats merge, avoiding aliasing at 30 Hz simulation.
	var beat_visibility: float = smoothstep(0.15, 0.6, frequency) * (1.0 - smoothstep(5.0, 11.0, frequency))
	_simulation.set_shader_parameter(&"vehicle_velocity", vehicle_velocity)
	_simulation.set_shader_parameter(&"wind_velocity", wind_velocity)
	_simulation.set_shader_parameter(&"inherited_velocity", velocity_inheritance)
	_simulation.set_shader_parameter(&"emission_density", clampf(exhaust_strength, 0.0, 1.0) * _distance_density)
	_simulation.set_shader_parameter(&"load", clampf(engine_load, 0.0, 1.0))
	_simulation.set_shader_parameter(&"chuff_phase", _phase)
	_simulation.set_shader_parameter(&"pulse_strength", pulse_strength * beat_visibility)
	_appearance.set_shader_parameter(&"soot", soot)
	_appearance.set_shader_parameter(&"light_tint", light_tint)
	_appearance.set_shader_parameter(&"shadow_tint", shadow_tint)
	_appearance.set_shader_parameter(&"soft_intersection", soft_intersection)


func _update_bounds() -> void:
	# Conservative under turns, wind, and inherited momentum; updated only at 5 Hz.
	# Retain the previous high speed for a full lifetime after stopping / wind changes.
	var motion_speed: float = vehicle_velocity.length() + wind_velocity.length()
	_peak_speed_hold -= 0.2
	if motion_speed >= _peak_motion_speed or _peak_speed_hold <= 0.0:
		_peak_motion_speed = motion_speed
		_peak_speed_hold = particle_lifetime + 0.2
	var reach: float = (_peak_motion_speed + buoyancy + turbulence) * particle_lifetime
	reach += exit_speed / maxf(drag, 0.1) + final_size
	reach = maxf(reach, 8.0)
	_plume.visibility_aabb = AABB(Vector3.ONE * -reach, Vector3.ONE * reach * 2.0)


## Optional direct physics integration. Velocity must be world-space meters/second.
func set_drive_state(world_velocity: Vector3, load_value: float) -> void:
	auto_velocity = false
	vehicle_velocity = world_velocity
	engine_load = clampf(load_value, 0.0, 1.0)


## Optional exact wheel synchronization. Signed angles support reversing vehicles.
func set_wheel_angle(radians: float) -> void:
	_external_wheel_angle = fposmod(radians, TAU)


func clear_wheel_sync() -> void:
	_external_wheel_angle = -1.0


func set_quality(preset: Quality) -> void:
	if quality != preset:
		quality = preset
		rebuild()


## Call after teleporting / world-origin rebasing; also detected for large jumps.
func reset_trail() -> void:
	_previous_position = global_position
	if _initialized:
		_plume.restart()
