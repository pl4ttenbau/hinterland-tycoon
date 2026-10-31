extends Node

class TestReflections:
	extends "res://game/gamescripts/nodes/world/world_reflections.gd"
	var candidate_reads: int = 0

	func _collect_candidates() -> Array[Vector3]:
		candidate_reads += 1
		return [Vector3.ZERO, Vector3(1, 0, 1), Vector3(100, 0, 0),
			Vector3(200, 0, 0), Vector3(300, 0, 0), Vector3(400, 0, 0)]

var failures: int = 0

func _ready() -> void:
	_start.call_deferred()

func _start() -> void:
	var completed: Variant = await _run()
	_check(completed == true, "Environment test completed without a runtime error")
	print("World environment tests: %d failures" % failures)
	get_tree().quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> bool:
	var daylight: Node3D = load("res://assets/packed/environment/day_environment.tscn").instantiate()
	var environment: Environment = daylight.get_node("WorldEnvironment").environment
	_check(environment.tonemap_mode == Environment.TONE_MAPPER_AGX, "Shared daylight uses AgX")
	_check(not environment.ssao_enabled and not environment.sdfgi_enabled,
		"The default daylight avoids costly ambient occlusion and GI")
	_check(not environment.fog_enabled and not environment.volumetric_fog_enabled,
		"The saved editor environment has no fog")
	get_tree().root.add_child(daylight)
	var runtime_environment: Environment = daylight.get_node("WorldEnvironment").environment
	_check(runtime_environment.fog_enabled, "Play enables ordinary distance fog")
	_check(not environment.fog_enabled and runtime_environment != environment,
		"Runtime fog leaves the shared authoring resource unchanged")
	_check(not daylight.has_node("ReflectionProbe"), "No origin-only reflection probe")
	daylight.free()
	for map_key: String in ["mpsb", "sachalin", "harzmountains", "franzburger"]:
		var shared_daylight: bool = false
		for dependency: String in ResourceLoader.get_dependencies(MapData.build_scene_file_path(map_key)):
			if dependency.ends_with("res://assets/packed/environment/day_environment.tscn"):
				shared_daylight = true
		_check(shared_daylight, "%s uses the shared daylight" % map_key)
	var vehicle_type := VehicleTypeData.new()
	vehicle_type.model_scene_path = "res://assets/meshes/vehicles/rail/fkbn_t1_motorwagon/model_fkbn_t1_motorwagon.tscn"
	var vehicle_data := VehicleData.new()
	vehicle_data.veh_type = vehicle_type
	var vehicle: Vehicle3D = Vehicle3D.of_vehicle_obj(vehicle_data)
	var visuals: Array[Node] = vehicle.find_children("*", "GeometryInstance3D", true, false)
	_check(not visuals.is_empty(), "Legacy railcar fixture contains renderable geometry")
	for visual: Node in visuals:
		_check((visual as GeometryInstance3D).layers == 64, "Spawned railcars use the Vehicles layer")
	vehicle.free()

	var world := WorldMapScene.new()
	get_tree().root.add_child(world)
	var reflections := TestReflections.new()
	# Exercise the translated environment used by Franzburger.
	reflections.position = Vector3(0, 53, 0)
	reflections.refresh_delay = 0.05
	world.add_child(reflections)
	for i: int in range(20):
		reflections.request_refresh()
	await _settle_captures()
	_check(reflections.candidate_reads == 1, "Loading events coalesce into one capture batch")
	var probes: Array[Node] = reflections.find_children("*", "ReflectionProbe", false, false)
	_check(probes.size() == 4, "Probe budget is enforced and nearby sites are merged")
	for node: Node in probes:
		var probe := node as ReflectionProbe
		_check(is_equal_approx(probe.global_position.y, 4.0), "Capture heights ignore environment offset")
		_check(probe.update_mode == ReflectionProbe.UPDATE_ONCE, "No continuous captures")
		_check((probe.cull_mask & 64) == 0 and (probe.cull_mask & 2) == 0,
			"Vehicles and water are excluded from captures")
		_check((probe.reflection_mask & 64) != 0, "Vehicles still receive local reflections")
	var reads_before: int = reflections.candidate_reads
	SignalBus.world_update.emit()
	await get_tree().create_timer(0.1).timeout
	_check(reflections.candidate_reads == reads_before, "Periodic world ticks do not recapture")
	SignalBus.roads_spawned.emit()
	await _settle_captures()
	_check(reflections.candidate_reads == reads_before + 1, "Construction refreshes captures")
	reflections.max_probes = 0
	reflections.request_refresh()
	await _settle_captures()
	_check(reflections.find_children("*", "ReflectionProbe", false, false).is_empty(),
		"Probe budget can disable captures completely")
	world.queue_free()
	await get_tree().process_frame
	return true

func _settle_captures() -> void:
	await get_tree().create_timer(0.1).timeout
	for frame: int in range(40):
		await get_tree().process_frame
