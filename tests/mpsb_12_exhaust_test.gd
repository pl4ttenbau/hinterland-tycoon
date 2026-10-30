extends Node

const MODEL: PackedScene = preload("res://assets/meshes/vehicles/rail/mpsb_12/model_mpsb_12.tscn")
var passed: int = 0
var failed: int = 0


func _ready() -> void:
	call_deferred(&"_run")


func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + label)


func _run() -> void:
	if _test_model() != true:
		failed += 1
		push_error("MPSB 12 integration test did not finish.")
	print("MPSB 12 exhaust: %d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _test_model() -> bool:
	var train: Train3D = load(Train3D.EMPTY_SCENE_PATH).instantiate() as Train3D
	train._create_motor(Enums.PathDirection.TRACK_NODES_INCREASE)
	var locomotive: Vehicle3D = MODEL.instantiate() as Vehicle3D
	locomotive.vehicle_obj = VehicleData.new()
	locomotive.train3d = train
	train.add_vehicle(locomotive, true)
	get_tree().root.add_child(train)
	train.set_physics_process(false)
	var exhaust: Node3D = locomotive.get_node("Steam/ChimneyExhaust") as Node3D
	exhaust.set_process(false)
	exhaust.set_physics_process(false)
	var plume: GPUParticles3D = exhaust.get_node("Plume") as GPUParticles3D
	check(not locomotive.has_node("Steam/TopSteamParticles3D"), "old chimney emitter is replaced")
	check(locomotive.has_node("Steam/SideSteamParticles3D_R") and locomotive.has_node("Steam/SideSteamParticles3D_L"), "both original cylinder emitters remain")
	var side_controller: VehicleDrivingParticles = locomotive.get_node("Steam") as VehicleDrivingParticles
	check(side_controller.child_particles.size() == 2, "legacy speed control only drives the two cylinder emitters")
	check(exhaust.locomotive == locomotive, "chimney driver is bound to MPSB 12")
	check(plume.layers == 64, "original particle visibility layer is preserved")
	check(plume.amount == 256 and not plume.local_coords, "balanced world-space GPU plume")
	check(exhaust.position.is_equal_approx(Vector3(-0.002134, 2.925, -2.461572)), "outlet matches the measured chimney lip")
	check(not exhaust.auto_velocity, "render-rate velocity estimation is disabled")
	exhaust._physics_process(1.0 / 60.0)
	locomotive.position.z -= 5.0 / 60.0
	exhaust._physics_process(1.0 / 60.0)
	check(exhaust.vehicle_velocity.is_equal_approx(Vector3(0.0, 0.0, -5.0)), "world velocity comes from physics displacement in meters/second")
	train.motor.start()
	train.motor.speed.current = 0.25
	train.motor.speed.target = 1.0
	exhaust._physics_process(1.0 / 60.0)
	var acceleration_load: float = exhaust.engine_load
	check(acceleration_load > 0.8, "acceleration produces strong exhaust effort")
	train.motor.speed.target = train.motor.speed.current
	exhaust._physics_process(1.0 / 60.0)
	var cruising_load: float = exhaust.engine_load
	check(cruising_load > 0.0 and cruising_load < acceleration_load, "cruising reduces exhaust effort")
	train.motor.speed.brake_applied = true
	exhaust._physics_process(1.0 / 60.0)
	check(exhaust.engine_load < cruising_load, "braking suppresses powered chuffs")
	locomotive.position.z += 3.0 / 60.0
	exhaust._physics_process(1.0 / 60.0)
	check(exhaust.vehicle_velocity.z > 2.99, "reverse movement reverses inherited exhaust velocity")
	train.motor.stop()
	exhaust._physics_process(1.0 / 60.0)
	check(is_zero_approx(exhaust.engine_load) and exhaust.exhaust_strength > 0.0, "stopped locomotive retains a small idle plume")
	train.free()
	return true
