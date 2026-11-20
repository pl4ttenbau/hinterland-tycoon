## godot --headless --path . res://tests/infrastructure_erasure_test.tscn -- --no-mcp
extends Node3D

const SERVICES := preload("res://scenes/subscenes/world_services.tscn")

var failures: int = 0
var results: Array[Error] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().create_timer(10.0).timeout.connect(func(): get_tree().quit(1))
	var services: WorldServicesCoordinator = SERVICES.instantiate()
	add_child(services)
	if GameTypes.ensure_initialized() != OK or services.initialize() != OK:
		get_tree().quit(1)
		return
	var eraser: EraserManager = Managers.eraser
	eraser.erase_finished.connect(func(_track: AbstractTrack, _op: EraserManager.Operation, result: Error): results.append(result))
	_check(await _test_roads(services.roads, eraser) == true, "Road test completed")
	_check(await _test_rails(services.rails, services.forks, eraser) == true, "Rail test completed")
	remove_child(services)
	_check(Managers.eraser == null, "Unmounting unregisters EraserManager")
	services.queue_free()
	await get_tree().process_frame
	print("Infrastructure erasure: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _test_roads(roads: RoadsLoader, eraser: EraserManager) -> bool:
	var road := _road(roads, 10, [Vector3.ZERO, Vector3(10, 0, 0), Vector3(20, 0, 0), Vector3(30, 0, 0)])
	var branch := _road(roads, 20, [Vector3(30, 0, 0), Vector3(30, 0, 10)])
	var overpass := _road(roads, 30, [Vector3(30, 8, 0), Vector3(30, 8, 10)])
	_cross(road.nodes.back(), [branch.num])
	_cross(branch.nodes.front(), [road.num])
	# A different height must not acquire a connection during ID reassignment.
	_cross(overpass.nodes.front(), [road.num])
	roads.spawn_road(road)
	roads.spawn_road(branch)
	var view: RoadWay3D = roads.storage.get_container_by_num(road.num)
	var vehicle: RoadVehicle3D = RoadVehicle3D.new()
	vehicle.route._paths.append(view.get_path_3d())
	Managers.vehicles.road_vehicles.append(vehicle)
	_check(roads.erase_segment(road, 1) == ERR_BUSY, "An active vehicle route blocks cuts on its road")
	vehicle.route._paths.clear()
	var visit := RoadRoutePoint.new()
	visit.road_num = road.num
	visit.node_index = 2
	vehicle.route_plan.points.append(visit)
	_check(roads.erase_segment(road, 1) == ERR_BUSY, "A legacy route's node reference cannot silently move")
	Managers.vehicles.road_vehicles.erase(vehicle)
	vehicle.free()
	var end: RoadNode = road.nodes.back()
	var handle: Vector3 = road.curve.get_point_in(3)
	var marker := RoadMarkerData.new()
	marker.road_num = road.num
	roads.markers.markers.append(marker)
	_check(roads.erase_segment(road, 1) == ERR_BUSY and road.nodes.size() == 4, "An anchored marker blocks geometry erasure atomically")
	roads.markers.markers.clear()
	eraser.erase_requested.emit(road, EraserManager.Operation.SEGMENT, 1, -1)
	_check(results == [OK], "Signal request reports completion")
	var tail: RoadData = roads.storage.get_by_num(31)
	_check(tail != null and road.nodes.size() == 2, "Middle cut retains two roads")
	if tail == null:
		return false
	_check(end.parent_track == tail and end.index == 1, "Moved road endpoint is reindexed")
	_check(tail.curve.get_point_in(1) == handle and tail.curve.get_point_position(0) == tail.nodes[0].position, "Right curve retains its handles and world positions")
	var tail_view: RoadWay3D = roads.storage.get_container_by_num(tail.num)
	_check(view.get_path_3d().curve == road.curve and tail_view.position == Vector3.ZERO, "Both road views use the new curves at the world origin")
	# PathMesh3D rebuilds mesh and collision on the next idle frame; physics then needs a step to see it.
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(view.get_road_mesh().get_total_triangle_count() > 0 and tail_view.get_road_mesh().get_total_triangle_count() > 0, "Sub-tile road fragments keep their meshes")
	_check(_road_hit(5.0), "Left sub-tile fragment keeps collision")
	_check(_road_hit(25.0), "Right sub-tile fragment keeps collision")
	_check(not _road_hit(15.0), "The erased gap is clear of collision")
	_check(branch.nodes[0].cross.connecting_roads == [tail.num] and end.cross.connecting_roads == [branch.num], "Reciprocal road links follow the moved endpoint")
	_check(overpass.nodes[0].cross == null, "A mismatched height cannot inherit a link")
	var graph := RoadPathfinder.new()
	graph.build(roads.storage.get_all())
	_check(not graph.find_path(end, branch.nodes.back()).is_empty(), "Routing uses the moved cross")
	_check(graph.find_path(road.nodes.back(), end).is_empty(), "Routing cannot cross the gap")
	_check(roads.erase_cross(tail, 1) == OK and end.cross == null and branch.nodes[0].cross == null, "Removing a cross clears both sides and leaves its geometry")
	_cross(branch.nodes.front(), [tail.num])
	_check(roads.erase_node(tail, 1) == OK, "Removing the endpoint of a two-node road removes the road")
	_check(not roads.storage._by_id.has(tail.num) and not tail_view.is_inside_tree(), "Removed road leaves the store and scene immediately")
	_check(branch.nodes[0].cross == null, "Deleting a road removes a one-way reference on a neighbor")
	_check(roads.erase_segment(road, -1) == ERR_INVALID_PARAMETER, "Invalid segment is rejected")
	# A node erase keeps the two outside spans and drops the node itself.
	var long_road := _road(roads, 40, [Vector3.ZERO, Vector3.RIGHT, Vector3.RIGHT * 2, Vector3.RIGHT * 3, Vector3.RIGHT * 4])
	var removed: RoadNode = long_road.nodes[2]
	_check(roads.erase_node(long_road, 2) == OK and removed.parent_track == null, "Erased road node is detached")
	_check(long_road.nodes.size() == 2 and roads.storage.get_by_num(41).nodes.size() == 2, "Node erasure leaves a gap on both sides")
	var junction := Vector3(100, 0, 100)
	var junction_road := _road(roads, 42, [junction - Vector3.RIGHT, junction, junction + Vector3.RIGHT])
	var discarded := _road(roads, 43, [junction, junction + Vector3.FORWARD])
	var incoming := _road(roads, 44, [junction, junction + Vector3.BACK])
	_cross(junction_road.nodes[1], [discarded.num])
	_cross(incoming.nodes[0], [junction_road.num])
	_check(roads.erase_segment(discarded, 0) == OK, "The third leg of a road junction can be erased")
	graph.build(roads.storage.get_all())
	_check(not graph.find_path(incoming.nodes.back(), junction_road.nodes.back()).is_empty(), "An unrelated one-way link to an interior anchor survives")
	for remaining: RoadData in roads.storage.get_all().duplicate():
		roads.erase_span(remaining, 0, remaining.nodes.size() - 1)
	return true


func _road_hit(x: float) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(Vector3(x, 4.0, 0.0), Vector3(x, -2.0, 0.0), 1)
	return not get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _test_rails(rails: RailsLoader, forks: RailForkLoader, eraser: EraserManager) -> bool:
	var junction := Vector3(30, 0, 30)
	var track := _rail(rails, 50, [junction - Vector3.RIGHT * 30, junction - Vector3.RIGHT * 20, junction - Vector3.RIGHT, junction], 3, true)
	var straight := _rail(rails, 51, [junction, junction + Vector3.RIGHT * 10], 0, false)
	var branch := _rail(rails, 52, [junction, junction + Vector3.FORWARD * 10], 0, false)
	var group: NewRailForkData = forks.get_fork_at_pos(junction)
	rails.spawn_rail_track(track)
	rails.spawn_rail_track(straight)
	rails.spawn_rail_track(branch)
	forks.spawn_rail_forks()
	var view: RailTrack3D = rails.track_storage.get_container_by_num(track.num)
	var endpoint: RailNodeData = track.nodes.back()
	var selected: int = group.setting.current.connected
	var depot := RailDepotData.new()
	depot.track_num = track.num
	Managers.depots.rail_depots.append(depot)
	_check(rails.erase_segment(track, 1) == ERR_BUSY and track.nodes.size() == 4, "A rail depot blocks dependent geometry erasure")
	Managers.depots.rail_depots.clear()
	_check(eraser.erase(track, EraserManager.Operation.SPAN, 2, 1) == OK, "Reversed span endpoints work through EraserManager")
	var tail: RailTrackData = rails.track_storage.get_by_num(53)
	if tail == null:
		return false
	_check(view.curve == track.curve and tail.curve.get_point_position(1) == junction, "Both rail curves reflect the cut")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var tail_view: RailTrack3D = rails.track_storage.get_container_by_num(tail.num)
	_check(tail_view.get_bed_mesh().get_total_triangle_count() > 0, "Sub-tile rail fragments keep their bedding")
	_check(rails.outer_buffers.size() == 2, "The new rail ends get buffers")
	_check(endpoint.parent_track == tail and rails.fork_storage.get_by_track(tail.num) == endpoint.fork, "Moved fork is indexed under the new track ID")
	_check(group.setting.current.root == tail.num and group.setting.current.connected == selected, "Moving the root preserves the selected branch")
	_check(straight.nodes[0].fork.connective_tracks.has(tail.num) and not branch.nodes[0].fork.connective_tracks.has(track.num), "Neighbors reference the new rail fragment")
	_check(rails.erase_node(branch, 0) == OK and group.connected_tracks.size() == 2, "Erasing a fork endpoint leaves the other two tracks connected")
	_check(group.setting.settable_tracks.is_empty() and group.setting.current.connected == straight.num, "The surviving two tracks form a fixed connection")
	_check(rails.erase_fork(straight, 0) == OK, "Explicit rail disconnection keeps the tracks")
	_check(forks.get_fork_at_pos(junction) == null and endpoint.fork == null and straight.nodes[0].fork == null, "The last fork legs and group are dropped together")
	_check(rails.fork_storage.get_all().is_empty() and tail.nodes.size() == 2 and straight.nodes.size() == 2, "Fork indexes clear and rail geometry remains")
	for remaining: RailTrackData in rails.track_storage.get_all().duplicate():
		rails.erase_span(remaining, 0, remaining.nodes.size() - 1)
	_check(rails.outer_buffers.is_empty(), "Removing the tracks removes their buffers")
	return true


func _road(roads: RoadsLoader, num: int, positions: Array[Vector3]) -> RoadData:
	var road := RoadData.of(num, "rural_road")
	road.start_pos = positions[0]
	for pos: Vector3 in positions:
		var node := RoadNode.of(road.nodes.size(), pos, road)
		road.add_node(node)
	roads.storage.add(road)
	return road


func _cross(node: RoadNode, links: Array[int]) -> void:
	(node.parent_track as RoadData).crosses.append(RoadCross.of(node, links))


func _rail(rails: RailsLoader, num: int, positions: Array[Vector3], fork_index: int, static_track: bool) -> RailTrackData:
	var track := RailTrackData.new()
	track.num = num
	track.infr_type_key = "750_MM"
	track.start_pos = positions[0]
	for pos: Vector3 in positions:
		var node := RailNodeData.of(track.nodes.size(), pos, track)
		track.add_node(node, false)
	var leg := RailNodeForkData.new()
	leg.railNode = track.nodes[fork_index]
	leg.railNode.fork = leg
	leg.static_track = static_track
	track.add_fork(leg)
	rails.fork_storage.add(leg)
	rails.track_storage.add(track)
	return track


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
