extends RefCounted

var failures: int = 0
var passed: int = 0
var tree: SceneTree

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures += 1
		push_error(message)

func settle() -> void:
	# PathMesh3D rebuilds in internal process; physics sees it the following tick.
	for frame: int in range(4):
		await tree.process_frame
	await tree.physics_frame

func ray_at(host: Node3D, point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 6.0, point - Vector3.UP * 6.0, 1)
	return host.get_world_3d().direct_space_state.intersect_ray(query)

func run(scene_tree: SceneTree) -> int:
	tree = scene_tree
	for test: StringName in [&"test_roads", &"test_road_type_profile", &"test_mud_and_cobbles", &"test_rails", &"test_player"]:
		if await call(test) != true:
			check(false, "%s aborted" % test)
	print("Infrastructure collision tests: %d passed, %d failures" % [passed, failures])
	return 0 if failures == 0 else 1

func test_roads() -> bool:
	for scene_path: String in [RoadData.RURAL_ROAD_SCENE_PATH, RoadData.DIRT_PATH_SCENE_PATH]:
		var road: RoadWay3D = load(scene_path).instantiate()
		road.position = Vector3(30, 20, 15)
		road.rotation.y = 0.7
		var curve := Curve3D.new()
		curve.add_point(Vector3.ZERO, Vector3.ZERO, Vector3(0, 2, -10))
		curve.add_point(Vector3(10, 4, -30), Vector3(-10, -1, 0), Vector3(10, 1, 0))
		curve.add_point(Vector3(35, 6, -40), Vector3(-10, -1, 0))
		road.get_path_3d().curve = curve
		tree.root.add_child(road)
		await settle()
		check(road.get_road_mesh().collision_mode == PathMesh3D.COLLISION_MODE_TRIMESH, "Road collision is enabled at tree entry")
		for fraction: float in [0.1, 0.3, 0.5, 0.7, 0.9]:
			var pos: Vector3 = road.get_path_3d().to_global(curve.sample_baked(curve.get_baked_length() * fraction))
			var hit: Dictionary = ray_at(road, pos)
			check(not hit.is_empty(), "Curved, sloped and transformed road has a physical surface at %.1f" % fraction)
			if not hit.is_empty():
				check(absf(hit.position.y - pos.y) < 0.5, "Collision follows the rendered road height")
		# Curve edits must replace collision, rather than retaining a baked snapshot.
		curve.set_point_position(1, Vector3(10, 7, -30))
		await settle()
		var point: Vector3 = road.get_path_3d().to_global(curve.sample_baked(curve.get_baked_length() * 0.5))
		var edited_hit: Dictionary = ray_at(road, point)
		check(not edited_hit.is_empty() and absf(edited_hit.position.y - point.y) < 0.5, "Collision rebuilds after editing a curve")
		road.free()
	return true

func test_road_type_profile() -> bool:
	if GameTypes.ensure_initialized() != OK:
		return false
	var rural := GameTypes.get_road_type("rural_road")
	var dirt := GameTypes.get_road_type("dirt_path")
	check(rural != null and dirt != null and rural != dirt, "Road catalog loads both existing road types")
	if rural == null:
		return false
	var data := RoadData.of(1, "legacy_road")
	check(data.get_road_type() == rural, "Legacy road types fall back to the rural profile")
	data.curve = Curve3D.new()
	data.curve.add_point(Vector3.ZERO)
	data.curve.add_point(Vector3(0, 0, -20))
	var width := rural.drivable_width_metres
	var height := rural.mesh_height_metres
	rural.drivable_width_metres = 8.0
	rural.mesh_height_metres = 0.45
	var road := RoadWay3D.of(data)
	rural.drivable_width_metres = width
	rural.mesh_height_metres = height
	if road == null:
		return false
	tree.root.add_child(road)
	await settle()
	var centre := ray_at(road, Vector3(0, 0, -10))
	var edge := ray_at(road, Vector3(3.5, 0, -10))
	check(not centre.is_empty() and absf(centre.position.y - 0.45) < 0.01, "Mesh height raises the spawned road surface")
	check(not edge.is_empty() and absf(edge.position.y - 0.45) < 0.01, "Drivable width extends the surfaced collision")
	var path := road.get_path_3d()
	var route := RoadVehicleRoute.new()
	check(route.assign([path]) and route.sample_ahead(5.0).is_equal_approx(Vector3(0, 0, -5)), "Automatic routes still sample the centre spline")
	road.free()
	return true

func test_mud_and_cobbles() -> bool:
	if GameTypes.ensure_initialized() != OK:
		return false
	for key: String in ["cobblestone_road", "mud_road"]:
		var data := RoadMapper.road_from_data_json({
			"num": 2,
			"type": key,
			"points": [{"pos": [0, 0, 0]}, {"pos": [0, 0, -24]}],
		})
		var definition := data.get_road_type()
		if definition == null or definition.key != key:
			return false
		var road := RoadWay3D.of(data)
		if road == null:
			return false
		tree.root.add_child(road)
		await settle()
		var material := road.get_road_mesh().material_override as StandardMaterial3D
		check(material != null and material.normal_enabled and material.normal_texture != null and material.roughness_texture != null,
			"%s spawns with normal and roughness maps" % key)
		var centre := ray_at(road, Vector3(0.0, 0.0, -10.0))
		var wheel := ray_at(road, Vector3(0.99, 0.0, -10.0))
		check(not centre.is_empty() and absf(centre.position.y - definition.mesh_height_metres) < 0.01,
			"%s supports collision at the catalog height" % key)
		check(not wheel.is_empty(), "%s supports collision at the wheel track" % key)
		if key == "mud_road" and not centre.is_empty() and not wheel.is_empty():
			check(wheel.position.y < centre.position.y - 0.05, "Mud wheel tracks are recessed below the grassy centre")
		road.free()
	return true

func test_rails() -> bool:
	if GameTypes.ensure_initialized() != OK:
		return false
	var expected_gauges: Dictionary = {"NORMAL_GAUGE": 1435, "1000_MM": 1000, "750_MM": 750, "600_MM": 600}
	check(GameTypes.rail_types.keys().size() == expected_gauges.size(), "Rail catalog lists every gauge used by the maps")
	for key: String in expected_gauges:
		var definition: RailType = GameTypes.rail_types.get(key)
		check(definition != null and definition.gauge_mm == expected_gauges[key] and definition.rail_head_height_metres > 0.0, "%s loads its gauge and rail height" % key)
	check(GameTypes.get_rail_type("1067_MM").key == InfrType.GAUGE_1000_MM, "Legacy 1067 mm tracks use the metre-gauge definition")
	check(GameTypes.get_rail_type("UNKNOWN").key == InfrTypesLoader.DEFAULT_RAIL_TYPE, "Unknown gauges fall back to standard gauge")
	for key: String in ["NORMAL_GAUGE", "750_MM", "600_MM"]:
		var rail: RailTrack3D = GameTypes.get_rail_type(key).scene.instantiate()
		rail.position = Vector3(0, 25, 0)
		var curve := Curve3D.new()
		curve.add_point(Vector3.ZERO)
		curve.add_point(Vector3(0, 0, -40))
		rail.curve = curve
		tree.root.add_child(rail)
		await settle()
		var path: Path3D = rail.get_child(0)
		var centre: Vector3 = path.to_global(Vector3(0, 0, -20))
		check(not ray_at(rail, centre).is_empty(), "Rail bedding supports collision for %s" % key)
		var bedding: PathMesh3D = rail.get_bed_mesh()
		check(bedding.collision_mode == PathMesh3D.COLLISION_MODE_TRIMESH, "Visible bedding has collision")

		# Walking uses bedding only; individual rails and sleepers have no collision.
		var tracks: PathMesh3D = rail.get_child(1)
		check(tracks.collision_mode == PathMesh3D.COLLISION_MODE_NONE, "Rails and sleepers are visual only")
		var track := RailTrackData.new()
		track.curve = curve
		track.hideFill = true
		rail.track = track
		await settle()
		check(not bedding.visible and bedding.collision_mode == PathMesh3D.COLLISION_MODE_NONE, "Hidden bedding has no invisible collision")
		check(tracks.collision_mode == PathMesh3D.COLLISION_MODE_NONE, "Hidden bedding does not enable track collision")
		check(ray_at(rail, centre).is_empty(), "Removing bedding leaves no rail or sleeper collision behind")

		# Restoring bedding must restore the walkable surface without solid tracks.
		track.hideFill = false
		rail.track = track
		await settle()
		check(bedding.visible and not ray_at(rail, centre).is_empty(), "Bedding collision can be restored")
		rail.free()
	return true

func test_player() -> bool:
	var road: RoadWay3D = load(RoadData.RURAL_ROAD_SCENE_PATH).instantiate()
	road.position.y = 10.0
	tree.root.add_child(road)
	await settle()
	var outer: PlayerAvatar = load("res://scenes/subscenes/player.tscn").instantiate()
	var player: BasicFpsPlayer = outer.walking_body
	player.position = Vector3(0, 14, -10)
	var previous_player: PlayerAvatar = GlobalState.player
	var previous_camera: Camera3D = GlobalState.active_cam
	tree.root.add_child(outer)
	check(not player.get_node("PlayerCollisionShape").disabled, "Actual player collider is enabled")
	check(player.get_collision_mask_value(1), "Actual player scans the generated surface layer")
	for frame: int in range(180):
		await tree.physics_frame
	check(player.is_on_floor(), "Actual player lands on road without terrain present")
	check(player.global_position.y > 10.0 and player.global_position.y < 10.5, "Player stands on the road surface, not a terrain-height query")
	outer.free()
	GlobalState.player = previous_player
	GlobalState.active_cam = previous_camera
	road.free()
	return true
