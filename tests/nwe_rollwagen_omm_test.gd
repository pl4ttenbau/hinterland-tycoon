extends Node

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var passed := _check_consist()
	print("Rollwagen freight consist: ", "PASS" if passed else "FAIL")
	get_tree().quit(0 if passed else 1)

func _check_consist() -> bool:
	if GameTypes.ensure_initialized() != OK:
		return false
	var coach := GameTypes.get_veh_type("nwe_rollwagen_omm") as RailVehicleTypeData
	if coach == null or coach.has_motor or coach.capacity.amount != 26:
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
	var meshes := wagon.find_children("*", "MeshInstance3D", true, false)
	var ok := meshes.size() == 2
	var triangles := 0
	var widths: Array[int] = []
	var material_names: Array[String] = []
	for n: Node in meshes:
		var mesh := n as MeshInstance3D
		ok = ok and mesh.mesh.get_surface_count() == 1 and mesh.layers == RenderLayers.VEHICLES
		var arrays: Array = mesh.mesh.surface_get_arrays(0)
		triangles += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		var mat := mesh.get_active_material(0) as StandardMaterial3D
		if mat == null or mat.albedo_texture == null:
			return false
		widths.append(mat.albedo_texture.get_width())
		material_names.append(mat.resource_name)
		ok = ok and not (arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).is_empty()
		if mesh.name == "Rollwagen":
			ok = ok and mat.normal_enabled and mat.normal_texture != null
			ok = ok and mat.roughness_texture != null and mat.metallic_texture != null
		if mesh.name == "Omm_Klagenfurt":
			var p := wagon.to_local(mesh.to_global(Vector3.ZERO))
			ok = ok and absf(p.y - 0.50) < 0.001
	ok = ok and triangles == 3188 and widths.has(4096) and widths.has(2048)
	ok = ok and material_names[0] != material_names[1]
	ok = ok and (wagon.get_node("VehicleCollider") as VehicleCollider).vehicle3d == wagon
	var separation: float = (coach.length_metres + train.locomotive.vehicle_obj.veh_type.length_metres) / 2.0
	ok = ok and absf(train.locomotive.position.distance_to(wagon.position) - separation) < 0.005
	train.spawn_wagon(VehicleData.of(coach.key))
	train.movement.place_vehicles()
	var next: RailVehicle3D = train.vehicles[2]
	var free_eye := wagon.to_global(Vector3(0, 0.28, 5.18))
	var next_attachment := next.to_global(Vector3(0, 0.28, -5.18))
	ok = ok and free_eye.distance_to(next_attachment) < 0.005
	print("Rollwagen materials/UVs/seat/3188 triangles/10.36 m couplers: ", ok)
	var before := wagon.position
	train.movement.start()
	train.movement.speed.target = 1.0
	for tick: int in range(600):
		train.movement._physics_process(1.0/60.0)
	ok = ok and wagon.position.distance_to(before) > 1.0
	train.free()
	return ok
