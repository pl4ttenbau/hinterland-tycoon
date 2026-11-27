extends Node

var failures: int = 0
var checks: int = 0

func _ready() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	if _test_locomotive() != true:
		check(false, "Harz integration suite aborted")
	print("Harz Brockenlok: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _test_locomotive() -> bool:
	check(GameTypes.ensure_initialized() == OK, "Production catalogs initialize")
	var definition := GameTypes.get_veh_type("harz_99_23_24") as RailVehicleTypeData
	check(definition != null and definition.has_motor, "Brockenlok is a catalog locomotive")
	check(definition.motor_type == GameEnums.MotorType.STEAM, "Uses shared steam audio mapping")
	check(definition.get_purchase_price() == 251700, "Can be purchased at the balanced catalog price")
	var rails := RailsLoader.new()
	Managers.rails = rails
	Managers.forks = RailJunctionLoader.new()
	var track := RailTrackData.new()
	track.num = 0
	track.infr_type_key = "1000_MM"
	for index: int in range(4):
		track.add_node(RailNodeData.of(index, Vector3(0, 0, -100 * index), track), false)
	track.build_curve()
	rails.track_storage.add(track)
	# Exercise the actual depot picker filter without constructing a world.
	var picker := VehicleListUi.new()
	picker.all_vehicle_types = [definition]
	picker.depot_track = track
	picker.hide_wagons = true
	check(picker.filtered.has(definition), "Available in the metre-gauge locomotive picker")
	track.infr_type_key = "750_MM"
	picker.filter()
	check(not picker.filtered.has(definition), "Excluded from 750 mm depots")
	track.infr_type_key = "NORMAL_GAUGE"
	picker.filter()
	check(not picker.filtered.has(definition), "Excluded from standard-gauge depots")
	track.infr_type_key = "1000_MM"
	picker.free()
	var start := VehicleStartPos.of(0, 1, Enums.PathDirection.TRACK_NODES_INCREASE)
	var train := Train3D.of(definition.key, start)
	train.spawn_wagon(VehicleData.of("ghe_covered_wagon_1000mm"))
	add_child(train)
	train.movement.set_physics_process(false)
	train.movement.place_vehicles()
	var loco: RailVehicle3D = train.locomotive
	check(train.get_cam() == loco.get_node("Camera3D"), "Shared driving camera resolves")
	check((loco.get_node("VehicleCollider") as VehicleCollider).vehicle3d == loco, "Clickable collider resolves locomotive")
	check(is_equal_approx(loco.position.y, track.get_rail_head_height()), "Treads sit at the production rail-head height")
	check((-loco.global_basis.z).dot(Vector3.FORWARD) > 0.999, "Smokebox faces the direction of travel")
	var mesh := loco.get_node("Brockenlok/Brockenlok") as MeshInstance3D
	check(mesh.mesh.get_surface_count() == 1, "One merged material surface")
	var arrays: Array = mesh.mesh.surface_get_arrays(0)
	check((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 == 17031, "Approved triangle count survives import")
	var bounds: AABB = mesh.transform * mesh.get_aabb()
	# The glTF scene owns the tiny centering transform, above the mesh node.
	bounds = (mesh.get_parent() as Node3D).transform * bounds
	check(absf(bounds.size.x - 2.683959) < 0.002 and absf(bounds.size.y - 3.7475) < 0.002, "Original metre scale survives import")
	check(absf(bounds.size.z - definition.length_metres) < 0.002, "Consist length matches the physical coupler envelope")
	check(absf(bounds.get_center().z) < 0.002, "Couplers are centered around the vehicle origin")
	var mat := mesh.get_active_material(0) as ShaderMaterial
	check(mat != null and mat.get_shader_parameter("albedo_map") != null, "Approved weathered material is assigned")
	check(mat.get_shader_parameter("albedo_map").get_width() == 4096 and mat.get_shader_parameter("normal_map").get_width() == 4096, "4096-pixel atlas detail is retained")
	check(mat.get_shader_parameter("surface_map") != null and is_equal_approx(mat.get_shader_parameter("normal_strength"), 0.78), "Packed roughness, metallic and specular atlas plus normal strength are retained")
	check(mesh.layers == RenderLayers.VEHICLES, "Factory assigns vehicle render layer")
	var separation: float = (definition.length_metres + train.vehicles[1].vehicle_obj.veh_type.length_metres) / 2.0
	check(absf(loco.global_position.distance_to(train.vehicles[1].global_position) - separation) < 0.005, "Metre-gauge wagon spacing follows both coupler lengths")
	var exhaust: Node3D = loco.get_node("Steam/ChimneyExhaust")
	check(exhaust.locomotive == loco and is_equal_approx(exhaust.driving_wheel_diameter, 1.0), "Exhaust uses shared driver and one-metre driving wheels")
	check((loco.get_node("Steam") as VehicleDrivingParticles).locomotive == loco, "Cylinder steam follows the movement controller")
	train.movement.start()
	train.movement.speed.target = 1.0
	var before: Vector3 = loco.global_position
	for tick: int in range(600):
		train.movement._physics_process(1.0 / 60.0)
	check(train.movement.speed_mps > 0.5 and loco.global_position.z < before.z - 1, "Production dynamics accelerates and drives the imported locomotive")
	check(train.movement.speed_mps <= 35.0 / 3.6, "Coupled train respects its slower wagon's speed limit")
	var speed_before_brake: float = train.movement.speed_mps
	train.movement.speed.brake_applied = true
	for tick: int in range(180):
		train.movement._physics_process(1.0 / 60.0)
	check(train.movement.speed_mps < speed_before_brake, "Shared driver brake decelerates the train")
	var poses: Array[Transform3D] = [loco.global_transform, train.vehicles[1].global_transform]
	train.movement.reverse_from_current_spot()
	check(loco.global_transform.is_equal_approx(poses[0]) and train.vehicles[1].global_transform.is_equal_approx(poses[1]), "Reversing preserves model and wagon poses")
	train.free()
	return true
