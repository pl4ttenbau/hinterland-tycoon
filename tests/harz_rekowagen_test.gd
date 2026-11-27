extends Node

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var passed := _check_consist()
	print("Harz passenger consist: ", "PASS" if passed else "FAIL")
	get_tree().quit(0 if passed else 1)

func _check_consist() -> bool:
	if GameTypes.ensure_initialized() != OK:
		return false
	var coach := GameTypes.get_veh_type("harz_rekowagen") as RailVehicleTypeData
	if coach == null or coach.has_motor or coach.capacity.amount != 40:
		return false
	if coach.get_purchase_price() != coach.PRICING.price_for(coach):
		return false
	Managers.rails = RailsLoader.new()
	Managers.forks = RailJunctionLoader.new()
	var track := RailTrackData.new()
	track.num = 0
	track.infr_type_key = "1000_MM"
	for i: int in range(4):
		track.add_node(RailNodeData.of(i, Vector3(0, 0, -100 * i), track), false)
	track.build_curve()
	Managers.rails.track_storage.add(track)
	var picker := VehicleListUi.new()
	picker.all_vehicle_types = [coach]
	picker.depot_track = track
	picker.hide_wagons = false
	picker.filter()
	var available := picker.filtered.has(coach)
	track.infr_type_key = "750_MM"
	picker.filter()
	available = available and not picker.filtered.has(coach)
	picker.free()
	track.infr_type_key = "1000_MM"
	if not available:
		return false
	var start := VehicleStartPos.of(0, 1, Enums.PathDirection.TRACK_NODES_INCREASE)
	var train := Train3D.of("harz_99_23_24", start)
	train.spawn_wagon(VehicleData.of(coach.key))
	add_child(train)
	train.movement.set_physics_process(false)
	train.movement.place_vehicles()
	var wagon: RailVehicle3D = train.vehicles[1]
	var mesh := wagon.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var bounds := mesh.global_transform * mesh.get_aabb()
	var mat := mesh.get_active_material(0) as StandardMaterial3D
	var ok := mesh.mesh.get_surface_count() == 1 and mat.albedo_texture.get_size() == Vector2(4096, 2048)
	ok = ok and mat.roughness_texture != null
	ok = ok and absf(bounds.size.z - coach.length_metres) < 0.005
	ok = ok and (wagon.get_node("VehicleCollider") as VehicleCollider).vehicle3d == wagon
	var separation: float = (coach.length_metres + train.locomotive.vehicle_obj.veh_type.length_metres) / 2.0
	ok = ok and absf(train.locomotive.position.distance_to(wagon.position) - separation) < 0.005
	var before := wagon.position
	train.movement.start()
	train.movement.speed.target = 1.0
	for tick: int in range(600):
		train.movement._physics_process(1.0/60.0)
	ok = ok and wagon.position.distance_to(before) > 1.0
	train.free()
	return ok
