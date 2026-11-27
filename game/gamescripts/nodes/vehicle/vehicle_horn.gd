## VehicleHorn: the horn or whistle of one vehicle.
##
## The player blows it with the `horn` action (H) while driving (see PlayerControl). A train also
## whistles on its own when it starts moving after standing for a while, so you hear trains leave
## stations across the map.
##
## Which sound plays follows the vehicle type, the same way TrainRollingAudio picks its engine loop:
## - rail, MotorType.STEAM: the whistle of Prussian P 8 38 2267 (Work With Sounds, CC BY 4.0)
## - rail, any other motorised type: the Makrofon of a DB class 628 railcar (CC BY-SA 3.0)
## - road, motorised: a two-tone electric car horn, synthesized here (no recording needed)
## - unpowered stock (wagons, trailers): no horn at all
## Sources and licences: LICENSE.md and the *_provenance.json files in assets/sounds/vehicles/horns/.
##
## The recordings are loaded at runtime instead of preloaded: a missing file then only silences
## that horn (with one warning) instead of breaking every script that references this class.
class_name VehicleHorn extends Node3D

## Emitted whenever the horn actually sounds (player or automatic). Tests count these.
signal blown(automatic: bool)

## One playable horn: which stream, which part of it, and how loud.
class HornSound:
	var stream: AudioStream
	## Where to start in the recording, seconds.
	var start: float
	## How long to play, seconds. The end fades out over FADE_SECONDS.
	var length: float
	var volume_db: float

	func _init(p_stream: AudioStream, p_start: float, p_length: float, p_volume_db: float) -> void:
		stream = p_stream
		start = p_start
		length = p_length
		volume_db = p_volume_db

const STEAM_WHISTLE_PATH: String = "res://assets/sounds/vehicles/horns/wws_p8_steam_whistle.ogg"
const MAKROFON_PATH: String = "res://assets/sounds/vehicles/horns/db628_makrofon.ogg"

#region Cuts and volumes: measured with tools/audio/audio_levels.gd, still to confirm by ear in game
## The P 8 recording (11 s) is 0.4 s of silence, a rising attack up to 1.1 s, the full whistle until
## 4.0 s, a quieter stretch (about 6 dB down) until 5.2 s, a second loud part until 6.6 s, then a
## short echo and room noise. One blast is the attack plus the first loud part; the second part would
## make a single press last over 6 s. The cut ends at 4.1 s, where the level drops.
const STEAM_WHISTLE_START: float = 0.4
const STEAM_WHISTLE_LENGTH: float = 3.7
## The 628 recording (6.6 s) is "first outside, then inside": the outside take is loud from 0.3 s to
## 2.3 s and then dies away until 3.8 s; the inside take starts at 4.3 s. Cut just before the first
## onset and keep a little of the decay, so the fade lands on a sound that is ending anyway.
const MAKROFON_START: float = 0.25
const MAKROFON_LENGTH: float = 2.4
## Level matching: in their loud parts the whistle sits around −20 dB RMS and the Makrofon around
## −10 dB, so the whistle gets 10 dB more gain and both land near −16 dB. The steam gain is above
## 0 dB, but the whistle's peak (−7.7 dBFS) still leaves headroom.
const STEAM_VOLUME_DB: float = 4.0
const MAKROFON_VOLUME_DB: float = -6.0
## The synthesized car horn is −6 dB RMS throughout. −14 dB puts it about 4 dB under the rail horns:
## a car honks quieter than a locomotive.
const CAR_VOLUME_DB: float = -14.0
#endregion

## The car horn: two tones a minor third apart, like the paired low/high diaphragm horns of 1960s–80s
## cars (roughly G#4 and B4). Short, because a honk is short.
const CAR_HORN_TONES: Array[float] = [415.0, 494.0]
const CAR_HORN_SECONDS: float = 0.7
const SYNTH_MIX_RATE: int = 22050

## Short fade at the end of a cut, so stopping mid-recording doesn't click.
const FADE_SECONDS: float = 0.12
## Ignore presses closer together than this: holding H or mashing it shouldn't machine-gun the horn.
const MIN_INTERVAL: float = 0.3

#region Automatic departure whistle (trains only)
## Below this speed (m/s) the train counts as standing.
const STANDSTILL_MPS: float = 0.1
## Whistle once it has stood at least this long (s)…
const DEPARTURE_MIN_STAND: float = 5.0
## …and then reaches this speed (m/s). Above STANDSTILL_MPS so creeping or a jolt doesn't count.
const DEPARTURE_MPS: float = 0.5
#endregion

## Horns carry much further than rolling noise (TrainRollingAudio uses 8 / 100).
@export var unit_size: float = 20.0
@export var audible_distance: float = 400.0
@export var audio_bus: StringName = &"Master"
## Trains whistle by themselves when they start from a stand. Off for road vehicles: a car that honks
## at every start would be unbearable.
@export var auto_whistle: bool = true

## The car horn is generated once and shared by every road vehicle.
static var _car_horn: AudioStreamWAV
## Paths already warned about, so a missing file warns once per run, not once per press.
static var _missing_warned: Dictionary = {}

var _player: AudioStreamPlayer3D
var _sound: HornSound
## Seconds left in the current blast; 0 when silent.
var _remaining: float = 0.0
## Seconds since the last blast started, for MIN_INTERVAL. Starts "long ago".
var _since_blow: float = INF
## Seconds the train has been standing, for the departure whistle.
var _standing: float = 0.0


## The horn of `vehicle`: a train's comes with its scene (train_3d.tscn), a road vehicle gets one on
## first use. Null for anything else.
static func of(vehicle: Node3D) -> VehicleHorn:
	if vehicle is Train3D:
		return vehicle.get_node_or_null("Horn") as VehicleHorn
	if vehicle is RoadVehicle3D:
		var horn := vehicle.get_node_or_null("Horn") as VehicleHorn
		if horn == null:
			horn = VehicleHorn.new()
			horn.name = "Horn"
			horn.auto_whistle = false
			vehicle.add_child(horn)
		return horn
	return null


## The sound for a vehicle type, or null when it has no horn (unpowered, or no type).
## `on_rail` decides between the rail horns and the car horn: VehicleTypeData has no domain field of
## its own at this level, and the caller always knows which kind of vehicle it is.
static func sound_for(definition: VehicleTypeData, on_rail: bool) -> HornSound:
	if definition == null or not definition.has_motor:
		return null
	if not on_rail:
		return HornSound.new(car_horn_stream(), 0.0, CAR_HORN_SECONDS, CAR_VOLUME_DB)
	if definition.motor_type == GameEnums.MotorType.STEAM:
		return HornSound.new(_load(STEAM_WHISTLE_PATH), STEAM_WHISTLE_START, STEAM_WHISTLE_LENGTH, STEAM_VOLUME_DB)
	# Diesel, electric and UNKNOWN motorised stock (e.g. the petrol Wismar railcar) all get the Makrofon:
	# close enough for every non-steam railcar and locomotive we have.
	return HornSound.new(_load(MAKROFON_PATH), MAKROFON_START, MAKROFON_LENGTH, MAKROFON_VOLUME_DB)


## The synthesized car horn, built on first use.
static func car_horn_stream() -> AudioStreamWAV:
	if _car_horn == null:
		_car_horn = _synthesize_car_horn()
	return _car_horn


## Two buzzing tones through a soft clipper: an electric diaphragm horn is a vibrating metal disc, so its
## tone is rich in odd harmonics and slightly overdriven, not a clean sine.
static func _synthesize_car_horn() -> AudioStreamWAV:
	# roundi, not int(): 0.7 × 22050 comes out as 15434.999… in floating point, and truncating would drop
	# the last sample, so the horn would be a hair shorter than CAR_HORN_SECONDS.
	var count: int = roundi(CAR_HORN_SECONDS * SYNTH_MIX_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for index: int in range(count):
		var t: float = float(index) / SYNTH_MIX_RATE
		var sample: float = 0.0
		for frequency: float in CAR_HORN_TONES:
			var phase: float = TAU * frequency * t
			# First three odd harmonics of a square wave; the highest (5 × 494 Hz) stays far below Nyquist.
			sample += sin(phase) + sin(3.0 * phase) / 3.0 + sin(5.0 * phase) / 5.0
		sample = tanh(sample * 0.9)
		# 15 ms attack, 40 ms release: no clicks at either end.
		var envelope: float = minf(1.0, t / 0.015) * minf(1.0, (CAR_HORN_SECONDS - t) / 0.04)
		data.encode_s16(index * 2, int(clampf(sample * envelope * 0.8, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SYNTH_MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


static func _load(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	if not _missing_warned.has(path):
		_missing_warned[path] = true
		push_warning("Horn sound missing, that horn stays silent: %s (see LICENSE.md for the source)" % path)
	return null


func _ready() -> void:
	_player = AudioStreamPlayer3D.new()
	_player.name = "HornPlayer"
	_player.bus = audio_bus
	_player.max_polyphony = 1
	_player.unit_size = unit_size
	_player.max_distance = audible_distance
	# A horn's pitch shouldn't wobble with the camera; speed effects belong to the rolling audio.
	_player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	add_child(_player)


## Sound the horn once. Returns false when nothing played: no horn on this vehicle, its recording is
## missing, or the last blast started less than MIN_INTERVAL ago.
func blow(automatic: bool = false) -> bool:
	if _since_blow < MIN_INTERVAL:
		return false
	var sound: HornSound = sound_for(_definition(), _on_rail())
	if sound == null or sound.stream == null:
		return false
	_sound = sound
	_since_blow = 0.0
	_remaining = sound.length
	_follow_source()
	_player.stream = sound.stream
	_player.volume_db = sound.volume_db
	_player.play(sound.start)
	blown.emit(automatic)
	return true


func is_sounding() -> bool:
	return _remaining > 0.0


func _physics_process(delta: float) -> void:
	# The player plays in wall time, so the cut and the press interval count wall time too; at
	# time_scale 0 (game clock stopped) both simply hold. The departure check stays on game time.
	var wall_delta: float = delta / Engine.time_scale if Engine.time_scale > 0.0 else 0.0
	_since_blow += wall_delta
	if auto_whistle:
		_watch_departure(delta)
	if _remaining <= 0.0:
		return
	_follow_source()
	_remaining -= wall_delta
	if _remaining <= 0.0:
		_remaining = 0.0
		_player.stop()
		return
	# Fade the tail of the cut: linear in amplitude over the last FADE_SECONDS.
	var fade: float = clampf(_remaining / FADE_SECONDS, 0.0, 1.0)
	_player.volume_db = _sound.volume_db + linear_to_db(maxf(fade, 0.001))


## Departure whistle: count standing time, and whistle once when the train pulls away after a real stop.
func _watch_departure(delta: float) -> void:
	var train := get_parent() as Train3D
	if train == null or not is_instance_valid(train.movement):
		return
	var speed: float = absf(train.movement.get_speed_mps())
	if speed < STANDSTILL_MPS:
		_standing += delta
		return
	if speed < DEPARTURE_MPS:
		# Creeping: neither a stop nor a departure yet. Keep the standing time for when it speeds up.
		return
	if _standing >= DEPARTURE_MIN_STAND:
		blow(true)
	_standing = 0.0


## The type that decides the sound: a train's first motorised vehicle (as for the engine audio), or
## the road vehicle itself.
func _definition() -> VehicleTypeData:
	var parent: Node = get_parent()
	if parent is Train3D:
		var vehicle: RailVehicle3D = _horn_vehicle(parent)
		return vehicle.vehicle_obj.veh_type if vehicle != null else null
	if parent is RoadVehicle3D and parent.vehicle_obj != null:
		return parent.vehicle_obj.veh_type
	return null


func _on_rail() -> bool:
	return get_parent() is Train3D


## A train's horn sits on its first motorised vehicle; a road vehicle's horn is its child and moves
## with it anyway.
func _follow_source() -> void:
	var train := get_parent() as Train3D
	if train == null:
		return
	var vehicle: RailVehicle3D = _horn_vehicle(train)
	if vehicle != null:
		global_position = vehicle.global_position


static func _horn_vehicle(train: Train3D) -> RailVehicle3D:
	for vehicle: RailVehicle3D in train.vehicles:
		if is_instance_valid(vehicle) and vehicle.vehicle_obj != null and vehicle.vehicle_obj.veh_type != null \
				and vehicle.vehicle_obj.veh_type.has_motor:
			return vehicle
	return null
