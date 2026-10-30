extends Node

## Count failures explicitly so the headless command exits unsuccessfully on a regression.
var failures: int = 0
## Track data and fork data use the same managers as the game, without loading a world.
var rails: RailsLoader
var forks: RailForkLoader

func _ready() -> void:
	self._run.call_deferred()

## Report all failures in one run instead of stopping at the first assertion.
func check(condition: bool, message: String) -> void:
	if not condition:
		self.failures += 1
		push_error(message)

## Marker positions and order must match the current route, without obsolete branch balls.
func check_markers(path: ActiveRailVehiclePath, message: String) -> void:
	## Marker height is deliberately raised above the track for visibility.
	var markers: Array[Node] = path.get_node(ActiveRailVehiclePath.DEBUG_MARKERS_PARENT_NAME).get_children()
	self.check(markers.size() == path.curve.point_count, message + ": one ball per curve point")
	for point_i: int in range(mini(markers.size(), path.curve.point_count)):
		self.check(markers[point_i].position.is_equal_approx(path.curve.get_point_position(point_i) + Vector3.UP * 0.8), message + ": current route position")

## Build simple fixture tracks with the production curve-building code.
func make_track(num: int, points: Array[Vector3]) -> RailTrackData:
	## Keep fixture IDs deterministic, including valid track number zero.
	var track := RailTrackData.new()
	track.num = num
	for point_i: int in range(points.size()):
		track.add_node(RailNodeData.of(point_i, points[point_i], track), false)
	track.build_curve()
	self.rails.track_storage.add(track)
	return track

## Attach two branches to a root track at one physical switch.
func make_fork(root_track: RailTrackData, branches: Array[RailTrackData]) -> NewRailForkData:
	## The loader groups endpoint records that share this position.
	var connected_tracks: Array[RailTrackData] = [root_track]
	connected_tracks.append_array(branches)
	for track: RailTrackData in connected_tracks:
		## Root exits at its last node; branches start at their first node.
		var node_fork := RailNodeForkData.new()
		node_fork.railNode = track.nodes.back() if track == root_track else track.nodes[0]
		node_fork.static_track = track == root_track
		node_fork.railNode.fork = node_fork
		self.forks.add_new_or_connection(node_fork)
	## Initialize before creating the train, matching the normal map loading sequence.
	var fork: NewRailForkData = self.forks.get_fork_at_pos(root_track.nodes.back().position)
	fork.setting.init_current_setting()
	return fork

## Use bare vehicle nodes so tests need neither imported meshes nor a terrain scene.
func make_train(track: RailTrackData, distance: float, lengths: Array[float]) -> Train3D:
	## Instantiate the real train scene to keep its child hierarchy intact.
	var train: Train3D = load(Train3D.EMPTY_SCENE_PATH).instantiate()
	train._create_motor(Enums.PathDirection.TRACK_NODES_INCREASE)
	train.last_node = track.nodes[0]
	for length: float in lengths:
		## Only length affects path following and fork occupancy.
		var vehicle := Vehicle3D.new()
		vehicle.train3d = train
		vehicle.vehicle_obj = VehicleData.new()
		vehicle.vehicle_obj.veh_type = VehicleTypeData.new()
		vehicle.vehicle_obj.veh_type.length_metres = length
		train.add_vehicle(vehicle, train.vehicles.is_empty())
	train.init_segment_path()
	train.m_passed_since_start = distance
	train.get_active_path().ensure_lookahead(train.get_front_distance())
	self.get_tree().root.add_child(train)
	train._update_segment_progress()
	train._place_vehicles()
	return train

func _run() -> void:
	self.rails = RailsLoader.new()
	Managers.rails = self.rails
	self.forks = RailForkLoader.new()
	Managers.forks = self.forks
	## Two exits differ immediately beyond a junction at twenty metres.
	var approach := self.make_track(0, [Vector3.ZERO, Vector3(0, 0, -10), Vector3(0, 0, -20)])
	var straight := self.make_track(1, [Vector3(0, 0, -20), Vector3(0, 0, -30), Vector3(0, 0, -60)])
	var branch := self.make_track(2, [Vector3(0, 0, -20), Vector3(10, 0, -30), Vector3(40, 0, -40)])
	var fork := self.make_fork(approach, [straight, branch])
	var train := self.make_train(approach, 17.9, [4.0, 6.0, 8.0])
	var path: ActiveRailVehiclePath = train.get_active_path()
	self.check(path.segments.size() == 2, "A route is available before entering the fork")
	self.check(path.curve.point_count == 5, "The junction appears only once in the joined curve")
	self.check_markers(path, "Initial route markers")
	self.check(is_equal_approx(train.vehicles[2].offset_to_first, 12.0), "Mixed vehicle lengths produce correct cumulative spacing")
	## Save the train pose to prove switching ahead leaves the occupied geometry alone.
	var before: Transform3D = train.locomotive.global_transform
	fork.setting.current.connected = 2
	self.check(not train.derailed, "Switching ahead does not derail the train")
	self.check(path.segments.back().track_num == 2, "Switching ahead rebuilds the planned branch")
	self.check_markers(path, "Switched route markers")
	train._place_vehicles()
	self.check(train.locomotive.global_transform.is_equal_approx(before), "Switching ahead preserves the train pose")
	## A small movement on either side of the joined point should keep the same heading.
	var boundary: float = path.segment_end_distances[0]
	var before_heading: Vector3 = path.get_transf_at_m_passed(boundary - 0.01).basis.z
	var after_heading: Vector3 = path.get_transf_at_m_passed(boundary + 0.01).basis.z
	self.check(before_heading.dot(after_heading) > 0.999, "Junction headings are continuous")
	## Rotation must change between nodes, not only when crossing a rail node.
	var heading_a: Vector3 = path.get_transf_at_m_passed(boundary + 1.0).basis.z
	var heading_b: Vector3 = path.get_transf_at_m_passed(boundary + 3.0).basis.z
	self.check(heading_a.dot(heading_b) < 0.999, "Rotation changes along the bend between rail nodes")
	## Crossing a boundary advances onto the already planned segment with no transform tween.
	var moving_train := self.make_train(approach, 19.0, [4.0])
	moving_train.motor.start()
	moving_train.motor.speed.current = 1.0
	moving_train.move_forwards(0.5)
	self.check(moving_train.current_segment.track_num == 2, "Movement crosses onto the selected branch")
	self.check(is_equal_approx(moving_train.m_passed_since_start, 22.0), "Movement advances by this physics step's exact distance")
	moving_train.free()
	## Both reversals preserve locomotive and wagon poses, including their facing direction.
	train.m_passed_since_start = 16.0
	train._place_vehicles()
	var poses: Array[Transform3D] = []
	for vehicle: Vehicle3D in train.vehicles:
		poses.append(vehicle.global_transform)
	train.reverse_from_current_spot()
	self.check_markers(path, "Reversed route markers")
	for vehicle_i: int in range(train.vehicles.size()):
		self.check(train.vehicles[vehicle_i].global_position.distance_to(poses[vehicle_i].origin) < 0.03, "Reversing preserves every vehicle position")
		self.check(train.vehicles[vehicle_i].global_basis.z.dot(poses[vehicle_i].basis.z) > 0.999, "Reversing preserves vehicle facing")
	train.reverse_from_current_spot()
	self.check(not train.is_reversed, "Two reversals restore forward travel")
	## Switch beneath a wagon while the locomotive has already cleared the fork.
	train.m_passed_since_start = 26.0
	train._place_vehicles()
	train.motor.start()
	before = train.vehicles[1].global_transform
	fork.setting.current.connected = 1
	self.check(train.derailed and not train.motor.is_started, "Switching beneath a wagon derails and stops the train")
	self.check_markers(path, "Derailed route markers")
	self.check(not train.motor.start(), "A derailed train cannot restart")
	train.move_forwards(1.0)
	train.reverse_from_current_spot()
	self.check(train.vehicles[1].global_transform.is_equal_approx(before), "Derailed vehicles stay frozen")
	## Buffer handling must clamp distance even when one frame overshoots the track end.
	var buffer_train := self.make_train(straight, 39.0, [4.0])
	buffer_train.motor.start()
	buffer_train.motor.speed.current = 1.0
	buffer_train.move_forwards(10.0)
	self.check(not buffer_train.motor.is_started, "Buffer stops the train")
	self.check(is_equal_approx(buffer_train.m_passed_since_start, 40.0), "Buffer overshoot is clamped")
	self.check(PathCurveUtils.get_reversed_direction(Enums.PathDirection.TRACK_NODES_INCREASE) == Enums.PathDirection.TRACK_NODES_DECREASE, "Increasing direction reverses correctly")
	self.check(PathCurveUtils.get_reversed_direction(Enums.PathDirection.TRACK_NODES_DECREASE) == Enums.PathDirection.TRACK_NODES_INCREASE, "Decreasing direction reverses correctly")
	## A stationary locomotive occupying the switch must also derail immediately.
	var occupied_train := self.make_train(approach, 19.0, [4.0])
	fork.setting.current.connected = 2
	self.check(occupied_train.derailed, "Switching beneath a stationary locomotive derails it")
	## A switch already cleared by the whole train cannot reroute or derail it.
	var cleared_train := self.make_train(approach, 35.0, [4.0, 6.0])
	var cleared_curve: Curve3D = cleared_train.get_active_path().curve
	fork.setting.current.connected = 1
	self.check(not cleared_train.derailed, "Switching behind a cleared train is harmless")
	self.check(cleared_train.get_active_path().curve == cleared_curve, "Switching behind preserves the travelled route")
	## Entering the root track from a branch exercises track zero and decreasing direction.
	var return_train := self.make_train(branch, 25.0, [4.0])
	return_train.reverse_from_current_spot()
	return_train.get_active_path().ensure_lookahead(return_train.get_front_distance() + 20.0)
	self.check(return_train.get_active_path().segments.back().track_num == 0, "Reverse route can connect to track zero")
	self.check(return_train.get_active_path().segments.back().movement_dir == Enums.PathDirection.TRACK_NODES_DECREASE, "A reversed connection uses decreasing track nodes")
	## Releasing trains must disconnect Resource listeners that outlive their scene nodes.
	train.free()
	buffer_train.free()
	occupied_train.free()
	cleared_train.free()
	return_train.free()
	self.check(fork.setting.current.setting_changed.get_connections().is_empty(), "Freed trains release fork listeners")
	## Break fixture data cycles normally retained for the lifetime of a loaded map.
	for track: RailTrackData in [approach, straight, branch]:
		for rail_node: RailNodeData in track.nodes:
			if rail_node.fork != null:
				rail_node.fork.railNode = null
				rail_node.fork = null
			rail_node.parent_track = null
	fork.setting.parent = null
	self.rails.free()
	self.forks.free()
	print("Train path tests: ", self.failures, " failures")
	self.get_tree().quit(0 if self.failures == 0 else 1)
