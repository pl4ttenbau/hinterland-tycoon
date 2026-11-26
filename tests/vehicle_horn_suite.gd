extends RefCounted
## VehicleHorn: which sound each vehicle type gets, the synthesized car horn, one blast's lifetime and
## the press interval, and the departure whistle of trains.
## The recordings themselves aren't auditioned here; that needs a listen in game.

var tree: SceneTree

var passed: int = 0
var failed: int = 0

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error(message)

func run(context: SceneTree) -> int:
	tree = context
	for test: Callable in [_test_assets, _test_sound_choice, _test_car_horn, _test_blast, _test_departure_whistle]:
		if await test.call() != true:
			check(false, "%s aborted" % test.get_method())
	print("Vehicle horn tests: %d passed, %d failures" % [passed, failed])
	return 0 if failed == 0 else 1

static func _type(has_motor: bool, motor_type: GameEnums.MotorType) -> VehicleTypeData:
	var definition := VehicleTypeData.new()
	definition.has_motor = has_motor
	definition.motor_type = motor_type
	return definition

## A train from the real scene with one vehicle of the given type, physics off so the test drives it.
func _train(definition: VehicleTypeData) -> Train3D:
	var train: Train3D = load("res://scenes/subscenes/vehicle/train_3d.tscn").instantiate()
	var vehicle := RailVehicle3D.new()
	vehicle.position = Vector3(5.0, 0.0, 0.0)
	vehicle.vehicle_obj = VehicleData.new()
	vehicle.vehicle_obj.veh_type = definition
	train.get_node("TrainVehicles").add_child(vehicle)
	train.vehicles.append(vehicle)
	tree.root.add_child(train)
	train.movement.set_physics_process(false)
	train.get_node("RollingAudio").set_physics_process(false)
	train.get_node("Horn").set_physics_process(false)
	return train

## The two recordings must be in the project (see LICENSE.md for where they come from).
func _test_assets() -> bool:
	for path: String in [VehicleHorn.STEAM_WHISTLE_PATH, VehicleHorn.MAKROFON_PATH]:
		check(ResourceLoader.exists(path) and load(path) is AudioStream, "Horn recording is imported: %s" % path)
	return true

func _test_sound_choice() -> bool:
	check(VehicleHorn.sound_for(null, true) == null, "No type, no horn")
	check(VehicleHorn.sound_for(_type(false, GameEnums.MotorType.UNKNOWN), true) == null, "Unpowered wagons have no horn")
	check(VehicleHorn.sound_for(_type(false, GameEnums.MotorType.UNKNOWN), false) == null, "Unpowered road trailers have no horn")
	var steam: VehicleHorn.HornSound = VehicleHorn.sound_for(_type(true, GameEnums.MotorType.STEAM), true)
	check(steam != null and steam.stream != null and steam.stream.resource_path == VehicleHorn.STEAM_WHISTLE_PATH,
		"Steam locomotives whistle")
	for motor: GameEnums.MotorType in [GameEnums.MotorType.DIESEL, GameEnums.MotorType.ELECTRIC, GameEnums.MotorType.UNKNOWN]:
		var horn: VehicleHorn.HornSound = VehicleHorn.sound_for(_type(true, motor), true)
		check(horn != null and horn.stream != null and horn.stream.resource_path == VehicleHorn.MAKROFON_PATH,
			"Motorised rail type %s gets the Makrofon" % GameEnums.MotorType.find_key(motor))
	# Road vehicles get the car horn whatever their motor type says (road catalog entries are UNKNOWN today).
	for motor: GameEnums.MotorType in [GameEnums.MotorType.UNKNOWN, GameEnums.MotorType.DIESEL, GameEnums.MotorType.STEAM]:
		var car: VehicleHorn.HornSound = VehicleHorn.sound_for(_type(true, motor), false)
		check(car != null and car.stream == VehicleHorn.car_horn_stream(), "Motorised road vehicles honk")
	return true

func _test_car_horn() -> bool:
	var stream: AudioStreamWAV = VehicleHorn.car_horn_stream()
	check(stream == VehicleHorn.car_horn_stream(), "The car horn is built once and shared")
	check(stream.format == AudioStreamWAV.FORMAT_16_BITS and not stream.stereo and stream.mix_rate == VehicleHorn.SYNTH_MIX_RATE,
		"Car horn is 16-bit mono")
	check(is_equal_approx(stream.get_length(), VehicleHorn.CAR_HORN_SECONDS), "Car horn has its intended length")
	var data: PackedByteArray = stream.data
	var peak: int = 0
	for index: int in range(0, data.size(), 2):
		peak = maxi(peak, absi(data.decode_s16(index)))
	check(peak > 16000 and peak < 32767, "Car horn is loud but does not clip (peak %d)" % peak)
	check(absi(data.decode_s16(0)) < 200 and absi(data.decode_s16(data.size() - 2)) < 200, "Car horn starts and ends silent (no clicks)")
	return true

## One blast: plays at the motorised vehicle, ignores presses inside MIN_INTERVAL, stops after its length.
func _test_blast() -> bool:
	var train: Train3D = _train(_type(true, GameEnums.MotorType.DIESEL))
	var horn: VehicleHorn = VehicleHorn.of(train)
	check(horn != null and horn == train.get_node("Horn"), "A train's horn comes with its scene")
	var blows: Array[bool] = []
	horn.blown.connect(func(automatic: bool) -> void: blows.append(automatic))
	check(horn.blow(), "Diesel train blows its horn")
	check(horn.is_sounding() and blows == [false], "The blast runs and is reported as a player blast")
	check(horn.global_position.is_equal_approx(train.vehicles[0].global_position), "The horn sounds at the motorised vehicle")
	check(not horn.blow(), "A second press right away is ignored")
	var step: float = 1.0 / 60.0
	for frame: int in range(int(VehicleHorn.MAKROFON_LENGTH / step) + 2):
		horn._physics_process(step)
	check(not horn.is_sounding() and not horn._player.playing, "The blast ends after its length")
	check(horn.blow() and blows.size() == 2, "After the interval the horn blows again")
	train.free()

	var wagons: Train3D = _train(_type(false, GameEnums.MotorType.UNKNOWN))
	check(not VehicleHorn.of(wagons).blow(), "A train without a motorised vehicle stays silent")
	wagons.free()
	return true

## A train whistles once when it pulls away after standing, not while creeping or running.
func _test_departure_whistle() -> bool:
	var train: Train3D = _train(_type(true, GameEnums.MotorType.STEAM))
	var horn: VehicleHorn = VehicleHorn.of(train)
	var automatic: Array[bool] = []
	horn.blown.connect(func(was_automatic: bool) -> void: automatic.append(was_automatic))
	var step: float = 1.0 / 60.0
	var advance := func(seconds: float) -> void:
		for frame: int in range(int(seconds / step)):
			horn._physics_process(step)

	train.movement.speed_mps = 0.0
	advance.call(VehicleHorn.DEPARTURE_MIN_STAND - 1.0)
	train.movement.speed_mps = 2.0
	advance.call(0.5)
	check(automatic.is_empty(), "A short stop doesn't make the train whistle")

	train.movement.speed_mps = 0.0
	advance.call(VehicleHorn.DEPARTURE_MIN_STAND + 0.5)
	train.movement.speed_mps = 0.3
	advance.call(1.0)
	check(automatic.is_empty(), "Creeping off is not a departure yet")
	train.movement.speed_mps = 2.0
	advance.call(0.5)
	check(automatic == [true], "Pulling away after a real stop whistles once, as an automatic blast")
	advance.call(10.0)
	check(automatic.size() == 1, "Running on doesn't whistle again")

	horn.auto_whistle = false
	train.movement.speed_mps = 0.0
	advance.call(VehicleHorn.DEPARTURE_MIN_STAND + 0.5)
	train.movement.speed_mps = 2.0
	advance.call(0.5)
	check(automatic.size() == 1, "auto_whistle off keeps the train quiet")
	train.free()
	return true
