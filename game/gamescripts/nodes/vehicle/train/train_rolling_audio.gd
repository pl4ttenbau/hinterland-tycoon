extends Node3D
## A bounded rolling bed plus a motor layer selected by the shared motor enum.

const ROLLING_LOOP: AudioStreamWAV = preload("res://assets/sounds/vehicles/rail/brockenbahn_wagon_filtered_loop.wav")
const DIESEL_LOOP: AudioStreamWAV = preload("res://assets/sounds/vehicles/rail/v100_diesel_loop.wav")
const STEAM_LOOP: AudioStreamWAV = preload("res://assets/sounds/vehicles/rail/harz_99_7245_steam_first2s_loop.wav")
const MAX_EMITTERS: int = 3
const SILENT_GAIN: float = 0.001

@export_range(-40.0, 0.0) var rolling_volume_db: float = -16.0
@export var audio_bus: StringName = &"Master"
@export_range(10.0, 500.0) var audible_distance: float = 100.0
## Gameplay calibration only: the recording's actual source speed is unknown.
@export_range(1.0, 100.0) var rolling_reference_kmh: float = 30.0
@export_range(-40.0, 0.0) var diesel_volume_db: float = -22.0
@export_range(-40.0, 0.0) var steam_volume_db: float = -24.0

var _train: Train3D
var _players: Array[AudioStreamPlayer3D] = []
var _gain: float = 0.0
var _pitch: float = 0.35
var _rng := RandomNumberGenerator.new()
var _engine_player: AudioStreamPlayer3D
var _engine_vehicle: RailVehicle3D
var _engine_motor_type: GameEnums.MotorType = GameEnums.MotorType.UNKNOWN
var _engine_pitch: float = 1.0
var _engine_gain: float = 0.0
var _engine_load: float = 0.0

func _ready() -> void:
	_train = get_parent() as Train3D
	# Local RNG avoids changing the simulation's random sequence.
	_rng.seed = get_instance_id()
	if _train != null:
		process_physics_priority = _train.movement.process_physics_priority + 1

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_train) or not is_instance_valid(_train.movement):
		_stop_players()
		return
	var count: int = _train.vehicles.size()
	_sync_players(mini(count, MAX_EMITTERS))
	_sync_engine()
	var clock_rate: float = Engine.time_scale
	# Audio playback uses wall time; explicitly suspend it when the simulation clock stops.
	for player: AudioStreamPlayer3D in _players:
		player.stream_paused = clock_rate <= 0.0
	if is_instance_valid(_engine_player):
		_engine_player.stream_paused = clock_rate <= 0.0
	if clock_rate <= 0.0:
		return
	var wall_delta: float = delta / clock_rate
	var movement: TrainMovement = _train.movement
	var speed_mps: float = absf(movement.get_speed_mps())
	if not movement.can_process() or movement.derailed:
		speed_mps = 0.0
	# At a crawl the full loop would rumble unnaturally: fade it out instead.
	var target_gain: float = smoothstep(0.3, 3.0, speed_mps)
	_gain = lerpf(_gain, target_gain, 1.0 - exp(-8.0 * wall_delta))
	var target_pitch: float = clampf(speed_mps / (rolling_reference_kmh / 3.6), 0.35, 2.5)
	_pitch = lerpf(_pitch, target_pitch, 1.0 - exp(-6.0 * wall_delta))
	_update_engine(wall_delta, clock_rate)
	for index: int in range(_players.size()):
		var player: AudioStreamPlayer3D = _players[index]
		# Spread the bounded emitters over the current consist, including after coupling.
		var vehicle_index: int = roundi(float(index) * (count - 1) / maxi(_players.size() - 1, 1))
		var vehicle: RailVehicle3D = _train.vehicles[vehicle_index]
		player.global_position = vehicle.global_position
		player.pitch_scale = clampf(_pitch * clock_rate, 0.05, 4.0)
		# Constant total power: adding wagons must not multiply the mix volume.
		player.volume_db = rolling_volume_db + linear_to_db(maxf(_gain, SILENT_GAIN)) \
			- 10.0 * log(float(_players.size())) / log(10.0)
		if _gain <= SILENT_GAIN:
			player.stop()
		elif not player.playing:
			player.play(_rng.randf_range(0.0, ROLLING_LOOP.get_length()))

func _sync_players(wanted: int) -> void:
	while _players.size() > wanted:
		var removed: AudioStreamPlayer3D = _players.pop_back()
		removed.stop()
		removed.queue_free()
	while _players.size() < wanted:
		var player := AudioStreamPlayer3D.new()
		player.name = "Rolling%d" % _players.size()
		player.stream = ROLLING_LOOP
		player.bus = audio_bus
		player.max_polyphony = 1
		player.volume_db = -80.0
		player.unit_size = 8.0
		player.max_distance = audible_distance
		player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(player)
		_players.append(player)

func _stop_players() -> void:
	for player: AudioStreamPlayer3D in _players:
		player.stop()
	_gain = 0.0
	if is_instance_valid(_engine_player):
		_engine_player.stop()
	_engine_gain = 0.0
	_engine_load = 0.0

func _sync_engine() -> void:
	var candidate: RailVehicle3D
	var motor_type: GameEnums.MotorType = GameEnums.MotorType.UNKNOWN
	for vehicle: RailVehicle3D in _train.vehicles:
		if vehicle.vehicle_obj == null or vehicle.vehicle_obj.veh_type == null:
			continue
		var definition: VehicleTypeData = vehicle.vehicle_obj.veh_type
		if definition.has_motor and definition.motor_type in [GameEnums.MotorType.DIESEL, GameEnums.MotorType.STEAM]:
			candidate = vehicle
			motor_type = definition.motor_type
			break
	if candidate == _engine_vehicle and motor_type == _engine_motor_type and is_instance_valid(_engine_player):
		return
	if is_instance_valid(_engine_player):
		_engine_player.stop()
		_engine_player.queue_free()
	_engine_player = null
	_engine_vehicle = candidate
	_engine_motor_type = motor_type
	_engine_pitch = 1.0
	_engine_gain = 0.0
	_engine_load = 0.0
	if candidate == null:
		return
	_engine_player = AudioStreamPlayer3D.new()
	_engine_player.name = "SteamEngine" if motor_type == GameEnums.MotorType.STEAM else "DieselEngine"
	_engine_player.stream = STEAM_LOOP if motor_type == GameEnums.MotorType.STEAM else DIESEL_LOOP
	# Retain the original stereo asset and locate its 3D player at the locomotive.
	_engine_player.attenuation_filter_db = -12.0
	_engine_player.panning_strength = 1.0
	_engine_player.bus = audio_bus
	_engine_player.max_polyphony = 1
	_engine_player.unit_size = 8.0
	_engine_player.max_distance = audible_distance
	_engine_player.volume_db = -80.0
	add_child(_engine_player)

func _update_engine(delta: float, clock_rate: float) -> void:
	if not is_instance_valid(_engine_player) or not is_instance_valid(_engine_vehicle):
		return
	var movement: TrainMovement = _train.movement
	var running: bool = movement.is_started and not movement.derailed and movement.can_process()
	_engine_load = lerpf(_engine_load, movement.get_traction_load(), 1.0 - exp(-3.0 * delta))
	var steam: bool = _engine_motor_type == GameEnums.MotorType.STEAM
	var target_gain: float = 1.0 if running else 0.0
	var target_pitch: float = lerpf(0.95, 1.05, _engine_load)
	var volume_db: float = diesel_volume_db + lerpf(-4.0, 0.0, _engine_load)
	if steam:
		# This is a working exhaust recording, not an idle bed. Fade out while
		# stationary or coasting. Source beat rate is unknown: the modest speed
		# modulation is artistic and does not claim cylinder/wheel synchronization.
		var speed_mps: float = absf(movement.get_speed_mps())
		target_gain *= smoothstep(0.2, 1.5, speed_mps) * sqrt(_engine_load)
		target_pitch = lerpf(0.9, 1.1, clampf(speed_mps / (rolling_reference_kmh / 3.6), 0.0, 1.0))
		volume_db = steam_volume_db
	_engine_gain = lerpf(_engine_gain, target_gain, 1.0 - exp(-8.0 * delta))
	_engine_pitch = lerpf(_engine_pitch, target_pitch, 1.0 - exp(-6.0 * delta))
	_engine_player.global_position = _engine_vehicle.global_position
	_engine_player.pitch_scale = clampf(_engine_pitch * clock_rate, 0.05, 4.0)
	_engine_player.volume_db = volume_db + linear_to_db(maxf(_engine_gain, SILENT_GAIN))
	if _engine_gain <= SILENT_GAIN:
		_engine_player.stop()
	elif not _engine_player.playing:
		_engine_player.play(_rng.randf_range(0.0, _engine_player.stream.get_length()))

func _exit_tree() -> void:
	_stop_players()
