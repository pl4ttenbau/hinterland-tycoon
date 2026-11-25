extends RefCounted

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
	if await _test_audio() != true:
		check(false, "Audio suite aborted")
	if _test_motor_mapping() != true:
		check(false, "Motor mapping suite aborted")
	print("Train audio tests: %d passed, %d failures" % [passed, failed])
	return 0 if failed == 0 else 1

func _test_audio() -> bool:
	var train: Train3D = load("res://scenes/subscenes/vehicle/train_3d.tscn").instantiate()
	for index: int in range(40):
		var vehicle := RailVehicle3D.new()
		vehicle.position = Vector3(index * 8.0, 0.0, 0.0)
		train.get_node("TrainVehicles").add_child(vehicle)
		train.vehicles.append(vehicle)
	tree.root.add_child(train)
	train.movement.set_physics_process(false)
	var audio: Node3D = train.get_node("RollingAudio")
	audio.set_physics_process(false)
	audio._physics_process(1.0 / 60.0)
	check(audio._players.size() == 3, "Forty vehicles use only three players")
	check(audio._players.all(func(p: AudioStreamPlayer3D) -> bool: return not p.playing), "Resting train is silent")
	var stream: AudioStreamWAV = audio._players[0].stream
	check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Imported WAV loops forwards")
	check(is_equal_approx(stream.get_length(), 16.0) and stream.mix_rate == 48000 and not stream.stereo,
		"Import preserves original mono 48 kHz loop duration")
	train.movement.speed_mps = 30.0 / 3.6
	for step: int in range(120):
		audio._physics_process(1.0 / 60.0)
	var first: AudioStreamPlayer3D = audio._players[0]
	check(first.playing and is_equal_approx(first.pitch_scale, 1.0), "30 km/h plays at reference rate")
	check(audio._players[2].global_position == train.vehicles.back().global_position, "Emitters cover the consist tail")
	check(first.max_polyphony == 1 and first.max_distance == 100.0 and first.bus == &"Master", "Spatial range and existing bus are configured")
	check(first.volume_db < -20.0, "Long consist gain remains conservative")
	check(absf(first.get_playback_position() - audio._players[1].get_playback_position()) > 0.01,
		"Loop emitters begin at different phases")
	train.movement.speed_mps = 60.0 / 3.6
	audio._physics_process(1.0 / 60.0)
	check(first.pitch_scale > 1.0 and first.pitch_scale < 1.2, "Pitch changes smoothly")
	for step: int in range(120):
		audio._physics_process(1.0 / 60.0)
	check(is_equal_approx(first.pitch_scale, 2.0), "60 km/h doubles loop rate")
	# Let AudioStreamPlayer3D commit its queued play request on a real physics frame.
	await tree.physics_frame
	await tree.physics_frame
	tree.paused = true
	await tree.process_frame
	check(first.stream_paused, "SceneTree pause suspends audio")
	tree.paused = false
	await tree.process_frame
	check(not first.stream_paused, "Unpausing resumes audio")
	Engine.time_scale = 0.0
	audio._physics_process(0.0)
	check(first.stream_paused, "Zero simulation time suspends audio")
	Engine.time_scale = 0.5
	audio._physics_process(1.0 / 120.0)
	check(not first.stream_paused and is_equal_approx(first.pitch_scale, 1.0), "Half simulation rate scales playback too")
	Engine.time_scale = 1.0
	train.movement.stop()
	for step: int in range(120):
		audio._physics_process(1.0 / 60.0)
	check(not first.playing, "Stopping fades then releases playback")
	train.movement.speed_mps = 0.1
	for step: int in range(120):
		audio._physics_process(1.0 / 60.0)
	check(not first.playing and is_equal_approx(first.pitch_scale, 0.35), "Crawling stays silent without zero pitch")
	train.movement.speed_mps = 10.0
	for step: int in range(120):
		audio._physics_process(1.0 / 60.0)
	tree.root.remove_child(train)
	check(not first.playing, "Removal immediately stops playback")
	tree.root.add_child(train)
	while train.vehicles.size() > 1:
		var removed: RailVehicle3D = train.vehicles.pop_back()
		removed.free()
	audio._physics_process(1.0 / 60.0)
	check(audio._players.size() == 1, "Consist shrink releases surplus players")
	var locomotive: RailVehicle3D = train.vehicles[0]
	locomotive.vehicle_obj = VehicleData.new()
	locomotive.vehicle_obj.veh_type = VehicleTypeData.new()
	var definition: VehicleTypeData = locomotive.vehicle_obj.veh_type
	definition.has_motor = true
	definition.motor_type = GameEnums.MotorType.STEAM
	train.movement.is_started = true
	audio._physics_process(1.0 / 60.0)
	var steam: AudioStreamPlayer3D = audio._engine_player
	check(steam != null and steam.stream == audio.STEAM_LOOP, "Steam type selects steam recording, never diesel")
	check(not steam.playing, "Working steam recording is silent at rest")
	check(steam.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Steam WAV loops forwards")
	check(is_equal_approx(steam.stream.get_length(), 1.88) and steam.stream.mix_rate == 44100 and steam.stream.stereo,
		"Steam import preserves original stereo 44.1 kHz duration")
	train.movement.speed_mps = 10.0
	train.movement._throttle = 1.0
	for step: int in range(180):
		audio._physics_process(1.0 / 60.0)
	check(steam.playing and first.playing, "Powered steam layers exhaust and rolling audio")
	check(steam.volume_db <= -24.0 and steam.pitch_scale >= 0.89 and steam.pitch_scale <= 1.11,
		"Steam mix is conservative and stays close to the original pitch")
	check(steam.global_position == locomotive.global_position and steam.max_polyphony == 1,
		"Steam is spatialized at locomotive with one voice")
	await tree.physics_frame
	await tree.physics_frame
	tree.paused = true
	await tree.process_frame
	check(steam.stream_paused, "SceneTree pause suspends steam")
	tree.paused = false
	await tree.process_frame
	Engine.time_scale = 0.0
	audio._physics_process(0.0)
	check(steam.stream_paused, "Zero clock suspends steam")
	Engine.time_scale = 1.0
	audio._physics_process(1.0 / 60.0)
	check(not steam.stream_paused, "Steam resumes after clock pause")
	train.movement.speed_mps = 0.0
	for step: int in range(120):
		audio._physics_process(1.0 / 60.0)
	check(not steam.playing, "Working exhaust fades at standstill even with throttle applied")
	train.movement.speed_mps = 10.0
	train.movement._throttle = 0.0
	for step: int in range(360):
		audio._physics_process(1.0 / 60.0)
	check(not steam.playing, "Working exhaust fades while coasting")
	definition.motor_type = GameEnums.MotorType.ELECTRIC
	audio._physics_process(1.0 / 60.0)
	check(audio._engine_player == null and not steam.playing, "Electric selection removes combustion audio")
	definition.motor_type = GameEnums.MotorType.DIESEL
	train.movement.speed_mps = 10.0
	train.movement._throttle = 0.0
	for step: int in range(120):
		audio._physics_process(1.0 / 60.0)
	var engine: AudioStreamPlayer3D = audio._engine_player
	check(engine != null and engine.playing and first.playing, "Diesel layers engine and rolling sound")
	check(engine.stream == audio.DIESEL_LOOP, "Diesel selection cannot retain steam recording")
	check(engine.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Diesel recording loops forwards")
	check(is_equal_approx(engine.stream.get_length(), 5.7407483), "Diesel recording keeps original duration")
	var unloaded_pitch: float = engine.pitch_scale
	train.movement.speed_mps = 0.0
	for step: int in range(120):
		audio._physics_process(1.0 / 60.0)
	check(engine.playing and is_equal_approx(engine.pitch_scale, unloaded_pitch), "Engine pitch is independent of wheel speed")
	train.movement._throttle = 1.0
	for step: int in range(180):
		audio._physics_process(1.0 / 60.0)
	check(engine.pitch_scale > unloaded_pitch and engine.pitch_scale <= 1.051, "Applied throttle modestly increases engine pitch")
	train.movement.stop()
	for step: int in range(120):
		audio._physics_process(1.0 / 60.0)
	check(not engine.playing, "Stopping controller fades engine playback")
	definition.has_motor = false
	audio._physics_process(1.0 / 60.0)
	check(audio._engine_player == null, "Unpowered wagons cannot play diesel even with a misconfigured enum")
	var impact: AudioStreamWAV = load("res://assets/sounds/vehicles/rail/wheel_joint_impact.wav")
	check(impact.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Optional wheel impact remains a one shot")
	train.free()
	check(not is_instance_valid(first), "Deleting train frees its audio players")
	# Profile changes queue old engine players for deletion at the end of frame.
	await tree.process_frame
	await tree.process_frame
	return true

func _test_motor_mapping() -> bool:
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://game/jsondata/rail_vehicle_types.json"))
	var source: Dictionary = catalog[0].duplicate(true)
	for kind: String in ["STEAM", "DIESEL", "ELECTRIC"]:
		source["motor_type"] = kind
		var mapped: RailVehicleTypeData = VehicleMapper.rail_type_dict_to_class(source)
		check(mapped != null and mapped.motor_type == GameEnums.MotorType[kind], "Mapper loads %s enum" % kind)
	source.erase("motor_type")
	check(VehicleMapper.rail_type_dict_to_class(source).motor_type == GameEnums.MotorType.UNKNOWN,
		"Older catalogs default to UNKNOWN")
	source["motor_type"] = "DIESEL"
	source["has_motor"] = false
	check(VehicleMapper.rail_type_dict_to_class(source) == null, "Mapper rejects powered motor type on unpowered stock (expected error)")
	source["has_motor"] = true
	source["motor_type"] = "INVALID"
	check(VehicleMapper.rail_type_dict_to_class(source) == null, "Mapper rejects unknown enum names (expected error)")
	source["motor_type"] = 2
	check(VehicleMapper.rail_type_dict_to_class(source) == null, "Catalog uses enum names rather than numeric ordinals (expected error)")
	return true
