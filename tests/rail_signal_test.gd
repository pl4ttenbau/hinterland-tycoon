## godot --headless --path . res://tests/rail_signal_test.tscn -- --no-mcp
extends Node

var failures: int = 0
var rails: RailsLoader
var forks: RailForkLoader
var added_trains: Array[Train3D] = []

func _ready() -> void:
	self._run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		self.failures += 1
		push_error(message)

func make_track(num: int, points: Array[Vector3]) -> RailTrackData:
	var track := RailTrackData.new()
	track.num = num
	for point_i: int in range(points.size()):
		track.add_node(RailNodeData.of(point_i, points[point_i], track), false)
	track.build_curve()
	self.rails.track_storage.add(track)
	return track

## Root exits at its last node; branches start at their first node.
func make_fork(root_track: RailTrackData, branches: Array[RailTrackData]) -> NewRailForkData:
	var connected_tracks: Array[RailTrackData] = [root_track]
	connected_tracks.append_array(branches)
	for track: RailTrackData in connected_tracks:
		var node_fork := RailNodeForkData.new()
		node_fork.railNode = track.nodes.back() if track == root_track else track.nodes[0]
		node_fork.static_track = track == root_track
		node_fork.railNode.fork = node_fork
		self.forks.add_new_or_connection(node_fork)
	var fork: NewRailForkData = self.forks.get_fork_at_pos(root_track.nodes.back().position)
	fork.setting.init_current_setting()
	return fork

## A train facing increasing node order, with its first vehicle centre `distance` metres along the track.
func make_train(track: RailTrackData, distance: float, powered: bool) -> Train3D:
	var train: Train3D = load(Train3D.EMPTY_SCENE_PATH).instantiate()
	train.movement.direction = Enums.PathDirection.TRACK_NODES_INCREASE
	train.movement.last_node = track.nodes[0]
	var vehicle := Vehicle3D.new()
	vehicle.train3d = train
	vehicle.vehicle_obj = VehicleData.new()
	var veh_type := VehicleTypeData.new()
	veh_type.length_metres = 10.0
	if powered:
		## 10 kN on 20 t: 0.5 m/s², up to 10 m/s.
		veh_type.has_motor = true
		veh_type.max_speed_kmh = 36
		veh_type.mass_tonnes = 20.0
		veh_type.tractive_effort_kn = 10.0
		veh_type.motor_power_kw = 1000.0
	vehicle.vehicle_obj.veh_type = veh_type
	train.add_vehicle(vehicle, true)
	train.movement.init_segment_path()
	train.movement.m_passed_since_start = distance
	train.movement.get_active_path().ensure_lookahead(train.movement.get_front_distance())
	self.get_tree().root.add_child(train)
	train.movement.update_segment_progress()
	train.movement.place_vehicles()
	GlobalState.trains.append(train)
	self.added_trains.append(train)
	return train

func add_signal(track: RailTrackData, offset: float, facing: RailSignalData.Facing) -> RailSignalData:
	var rail_signal := RailSignalData.new()
	rail_signal.num = self.rails.signals.next_num()
	rail_signal.track_num = track.num
	rail_signal.offset = offset
	rail_signal.facing = facing
	self.rails.signals.add(rail_signal)
	return rail_signal

func simulate(movement: TrainMovement, seconds: float) -> void:
	for _step: int in range(roundi(seconds * 60.0)):
		movement.update_speed(1.0 / 60.0)
		movement.move_forwards(1.0 / 60.0)

func clear_for(rail_signal: RailSignalData, direction: Enums.PathDirection, trains: Array) -> bool:
	return RailSignalBlocks.is_block_clear(rail_signal, direction, self.rails.signals, RailSignalBlocks.occupancy(trains))

func _run() -> void:
	self.rails = RailsLoader.new()
	Managers.rails = self.rails
	self.forks = RailForkLoader.new()
	Managers.forks = self.forks
	var increase := Enums.PathDirection.TRACK_NODES_INCREASE
	var decrease := Enums.PathDirection.TRACK_NODES_DECREASE
	## A 100 m approach into a switch; a 200 m straight exit and a branch.
	var approach := self.make_track(0, [Vector3.ZERO, Vector3(0, 0, -50), Vector3(0, 0, -100)])
	var straight := self.make_track(1, [Vector3(0, 0, -100), Vector3(0, 0, -150), Vector3(0, 0, -200), Vector3(0, 0, -250), Vector3(0, 0, -300)])
	var branch := self.make_track(2, [Vector3(0, 0, -100), Vector3(20, 0, -150), Vector3(60, 0, -200)])
	var fork := self.make_fork(approach, [straight, branch])

	## Train A runs on the straight from 20 m; train B stands at 160 m.
	var a := self.make_train(straight, 20.0, true)
	var b := self.make_train(straight, 160.0, false)
	var movement: TrainMovement = a.movement
	self.check(is_equal_approx(movement.get_signal_authority(), INF), "Without signals there is no signal limit")
	self.check(absf(movement.get_movement_authority() - 180.0) < 0.5, "Without signals the authority runs to the buffer")

	var s1 := self.add_signal(straight, 100.0, RailSignalData.Facing.NODES_INCREASE)
	self.check(not self.clear_for(s1, increase, [a, b]), "A train in the block ahead sets the signal to stop")
	self.check(absf(movement.get_movement_authority() - 73.0) < 0.5, "A stop signal limits the authority to its stopping point")

	var s2 := self.add_signal(straight, 130.0, RailSignalData.Facing.NODES_INCREASE)
	self.check(self.clear_for(s1, increase, [a, b]), "The block ends at the next signal for the same direction")
	self.check(not self.clear_for(s2, increase, [a, b]), "The next signal protects the occupied block")
	self.check(absf(movement.get_movement_authority() - 103.0) < 0.5, "A clear signal lets the train run on to the next stop signal")
	self.rails.signals.signals.erase(s2)

	s1.facing = RailSignalData.Facing.NODES_DECREASE
	self.check(absf(movement.get_movement_authority() - 180.0) < 0.5, "A signal for the other direction is ignored")
	self.check(not self.clear_for(s1, decrease, [a, b]), "The opposite block sees the train behind the signal")
	s1.facing = RailSignalData.Facing.BOTH
	self.check(absf(movement.get_movement_authority() - 73.0) < 0.5, "A signal for both directions applies")
	s1.facing = RailSignalData.Facing.NODES_INCREASE

	## Drive A at full target speed: it brakes to a stand before the signal.
	movement.start()
	movement.speed.target = 1.0
	self.simulate(movement, 90.0)
	var front: float = movement.get_front_distance()
	self.check(front > 60.0 and front + 5.0 < 100.0, "The train stops short of the stop signal (front at %.2f)" % front)
	self.check(is_zero_approx(movement.speed_mps) and not movement.derailed, "The train stands at the signal without derailing")

	## Once B is gone the block clears and A proceeds past the signal.
	GlobalState.trains.erase(b)
	self.simulate(movement, 30.0)
	self.check(movement.get_front_distance() > 110.0, "The train passes the signal once the block is clear")

	## Through a switch, the block follows the current setting.
	var s3 := self.add_signal(approach, 50.0, RailSignalData.Facing.NODES_INCREASE)
	var c := self.make_train(branch, 30.0, false)
	fork.setting.current.connected = straight.num
	self.check(self.clear_for(s3, increase, [c]), "A train on the branch does not occupy a block set for the straight")
	fork.setting.current.connected = branch.num
	self.check(not self.clear_for(s3, increase, [c]), "A train on the branch occupies a block set for the branch")

	## Placing and removing through the tool keeps the store, labels and erase guard in step.
	var tool := RailSignalTool.new()
	tool.rails = self.rails
	self.add_child(tool)
	var placement: Dictionary = tool.placement_at(Vector3(1, 0, -40), Vector3.FORWARD)
	self.check(placement.get("track_num") == approach.num and absf(placement.get("offset", -1.0) - 40.0) < 0.5, "Placement finds the nearest track and offset")
	self.check(placement.get("facing") == RailSignalData.Facing.NODES_INCREASE, "Placement faces the view direction along the track")
	var placed: RailSignalData = tool.place(placement, "", placement.facing)
	self.check(placed != null and tool.get_node_or_null("RailSignal_%d" % placed.num) != null, "Placing shows the signal's labels")
	self.check(tool.nearest_signal(Vector3(3, 0, -42)) == placed, "The nearest signal within reach is found for removal")
	self.check(tool.nearest_signal(Vector3(30, 0, -42)) == null, "No signal is found out of reach")
	self.check(tool.remove(placed) and self.rails.signals.get_by_num(placed.num) == null, "Removing drops the signal from the store")
	self.check(tool.get_node_or_null("RailSignal_%d" % placed.num) == null, "Removing detaches the labels at once")
	self.check(not tool.remove(placed), "Removing twice reports failure")
	self.rails.signals.remove(s3)
	self.rails.signals.remove(s1)
	self.check(not self.rails._track_has_dependencies(approach), "A track without signals can be erased again")

	for train: Train3D in self.added_trains:
		GlobalState.trains.erase(train)
		train.free()
	## Loaders outside the tree are not freed at exit; they would leak with all their track data.
	Managers.rails = null
	Managers.forks = null
	self.rails.free()
	self.forks.free()
	print("Rail signal tests: %d failures" % self.failures)
	self.get_tree().quit(0 if self.failures == 0 else 1)
