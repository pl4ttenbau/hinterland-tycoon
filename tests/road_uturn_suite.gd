## Reuse the same isolated road, vehicle and stop fixture as transfer integration.
extends "res://tests/road_route_transfer_suite.gd"

func suite_name() -> String:
	return "Road U-turn tests"

func test_names() -> Array[StringName]:
	return [&"test_planning", &"test_geometry", &"test_manual_handoff", &"test_obstacles", &"test_source_removal", &"test_both_road_ends", &"test_returning_passengers"]

# Opposite targets require an endpoint detour; ordinary bends remain physical.
func test_planning() -> bool:
	var path: Path3D = Managers.roads.storage.get_container_by_num(100).get_path_3d()
	var backwards: Array[Dictionary] = [{"path": path, "from": 50.0, "to": 20.0}]
	var turn: RoadUTurnPlanner.Approach = RoadUTurnPlanner.prepare(backwards, Vector3.FORWARD)
	check(turn != null and turn.offset == 100 and turn.segments[0].to == 100, "A target behind the car first sends it to the far road end")
	var forwards: Array[Dictionary] = [{"path": path, "from": 50.0, "to": 90.0}]
	turn = RoadUTurnPlanner.prepare(forwards, Vector3.BACK)
	check(turn != null and turn.offset == 0, "Opposite initial heading chooses the start endpoint instead")
	check(RoadUTurnPlanner.prepare(forwards, Vector3.FORWARD) == null, "Normal forward travel does not receive a turn")
	var cusp: Array[Dictionary] = [{"path": path, "from": 50.0, "to": 100.0}, {"path": path, "from": 100.0, "to": 20.0}]
	turn = RoadUTurnPlanner.prepare(cusp, Vector3.FORWARD)
	check(turn != null and turn.offset == 100 and turn.segments.size() == 1, "Internal endpoint reversals split before the returning segment")
	check(road.nodes.size() == 4, "U-turn planning never adds authored road nodes")
	var body: RoadVehicle3D = _vehicle()
	body.position = Vector3(0, 0.6, -50)
	check(not body.begin_automatic_uturn(path, 100), "Movement controller rejects a turn requested in the middle of the road")
	body.free()
	return true

# The narrow curve has continuous entry/exit headings and preserves body height.
func test_geometry() -> bool:
	var path: Path3D = Managers.roads.storage.get_container_by_num(100).get_path_3d()
	for endpoint: float in [0.0, 100.0]:
		var direction: Vector3 = Vector3.BACK if endpoint == 0 else Vector3.FORWARD
		var start := Transform3D(Basis.looking_at(direction, Vector3.UP, true), Vector3(0, 0.6, -2 if endpoint == 0 else -98))
		var turn := RoadVehicleUTurn.new()
		check(turn.build(start, path, endpoint, 1.25), "Curve builds at either endpoint")
		var length: float = turn.curve.get_baked_length()
		check(turn.sample(0).is_equal_approx(start), "Entry pose is preserved without a jump")
		check(turn.sample(length).origin.distance_to(start.origin) < 0.05, "Turn rejoins the road at its entry offset")
		check(turn.sample(length).basis.z.dot(-direction) > 0.99, "Turn exits facing the returning direction")
		check(length > 5 and length < 30, "Small gameplay radius produces a bounded manoeuvre")
		check(not RoadVehicleUTurn.new().build(start, path, 50, 1.25), "An interior point cannot be used as a road-end turn")
	return true

func _turning_vehicle() -> RoadVehicle3D:
	var body: RoadVehicle3D = _vehicle()
	body.position = Vector3(0, 0.6, -98)
	body.rotation.y = PI
	return body

# Interrupt the scripted curve, restoring physics at the current pose and speed.
func test_manual_handoff() -> bool:
	var body: RoadVehicle3D = _turning_vehicle()
	var path: Path3D = Managers.roads.storage.get_container_by_num(100).get_path_3d()
	body.freeze = false
	var original_mode: RigidBody3D.FreezeMode = body.freeze_mode
	var steering: float = body.steering_limit
	check(body.begin_automatic_uturn(path, 100), "Stationary automatic vehicle begins its assisted turn")
	for step: int in range(5):
		body._drive_automatic_uturn(0.1)
	var pose: Transform3D = body.global_transform
	body.set_player_driving(true)
	check(not body.is_automatic_uturning() and not body.freeze and body.freeze_mode == original_mode, "Manual takeover restores the exact physics configuration")
	check(body.global_transform.is_equal_approx(pose), "Manual takeover preserves the current turn pose")
	check(body.linear_velocity.length() > 0 and body.linear_velocity.length() <= body.automatic_uturn_speed * 1.1, "Manual takeover retains walking-speed tangent momentum")
	body.apply_driver_input(1, 0, 0, 1)
	check(body.steering_limit == steering and absf(body.steering) <= steering + 0.00001, "Manual steering keeps its original radius limit")
	check(not body.begin_automatic_uturn(path, 100), "Manual driving cannot enter assisted turning")
	body.free()
	return true

# A frozen kinematic body still checks its full chassis against an obstruction.
func test_obstacles() -> bool:
	var body: RoadVehicle3D = _turning_vehicle()
	var path: Path3D = Managers.roads.storage.get_container_by_num(100).get_path_3d()
	check(body.begin_automatic_uturn(path, 100), "Obstacle fixture begins its curve")
	var obstacle := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1, 4, 1)
	collision.shape = shape
	obstacle.add_child(collision)
	obstacle.position = body.global_position + Vector3.UP
	host.add_child(obstacle)
	await tree.physics_frame
	var pose: Transform3D = body.global_transform
	body._drive_automatic_uturn(0.1)
	check(body.global_transform.is_equal_approx(pose) and body._uturn.progress == 0, "Blocked turn holds both pose and progress")
	check("blocked" in body.plan_execution.status, "Blocked turn reports its reason")
	obstacle.free()
	await tree.physics_frame
	body._drive_automatic_uturn(0.1)
	check(body._uturn.progress > 0, "Clearance lets the same curve resume")
	body.clear_route()
	check(not body.is_automatic_uturning() and body.freeze and body.freeze_mode == RigidBody3D.FREEZE_MODE_STATIC, "Stopping restores a previously frozen body's mode")
	body.free()
	return true

# Removing infrastructure during a turn must release kinematic control safely.
func test_source_removal() -> bool:
	var body: RoadVehicle3D = _turning_vehicle()
	var path := Path3D.new()
	path.curve = road.curve.duplicate()
	host.add_child(path)
	check(body.begin_automatic_uturn(path, 100), "Temporary road begins a turn")
	path.free()
	body._drive_automatic_uturn(0.1)
	check(not body.is_automatic_uturning() and body.freeze and body.freeze_mode == RigidBody3D.FREEZE_MODE_STATIC, "Removed road releases assisted control and restores prior physics settings")
	check("no longer available" in body.plan_execution.status, "Removed road reports a clear failure")
	body.free()
	return true

# Real physics travels to the far end before reversing, then turns at the other
# end for the second visit. This verifies the curve-to-wheel handoff both ways.
func test_both_road_ends() -> bool:
	var depot := RoadDepotData.new()
	depot.road_num = road.num
	depot.road_pos = "START"
	var body: RoadVehicle3D = Managers.vehicles.spawn_road_vehicle_at_depot("trabant_601_green", depot)
	if body == null:
		return false
	body.position.z = -50
	var first := RoadRoutePoint.new()
	first.road_num = road.num
	first.node_index = 0
	var last := RoadRoutePoint.new()
	last.road_num = road.num
	last.node_index = 1
	body.route_plan.points = [first, last]
	check(body.plan_execution.start(body), "Behind-target itinerary starts")
	body._drive_route(1.0 / 60.0)
	check("road end" in body.plan_execution.status, "Normal driver preserves the endpoint-detour status")
	var turns: int = 0
	var was_turning: bool = false
	var farthest: float = body.position.z
	for frame: int in range(6000):
		await tree.physics_frame
		var turning: bool = body.is_automatic_uturning()
		if turning and not was_turning:
			turns += 1
		was_turning = turning
		farthest = minf(farthest, body.position.z)
		if body.plan_execution.status == "Plan complete":
			break
	check(body.plan_execution.status == "Plan complete", "Both endpoint turns complete without manual intervention: " + body.plan_execution.status)
	check(turns == 2 and farthest < -95, "Car visits the road end instead of turning in the middle")
	check(not body.freeze and not body.is_automatic_uturning() and body.position.y > 0, "Wheel physics and support resume after the turns")
	check(body.position.z < -25 and body.position.z > -31, "Returning car reaches the actual final visit")
	body.free()
	return true

# Load/unload executes only at visits, never at the temporary U-turn approach.
func test_returning_passengers() -> bool:
	var a: RoadStationData = _stop(70, 1)
	var b: RoadStationData = _stop(71, 3)
	a.get_inventory_view().get_inventory().change_stack(&"passenger", 71, 4)
	b.get_inventory_view().get_inventory().change_stack(&"passenger", 70, 4)
	var depot := RoadDepotData.new()
	depot.road_num = road.num
	depot.road_pos = "START"
	var body: RoadVehicle3D = Managers.vehicles.spawn_road_vehicle_at_depot("trabant_601_green", depot)
	if body == null:
		return false
	body.route_plan.points = [
		_point(70, [_action(RoadRouteAction.Kind.LOAD, [&"passenger"], [71])]),
		_point(71, [_action(RoadRouteAction.Kind.UNLOAD, [&"passenger"], [71]), _action(RoadRouteAction.Kind.LOAD, [&"passenger"], [70])]),
		_point(70, [_action(RoadRouteAction.Kind.UNLOAD, [&"passenger"], [70])])]
	var changes: Array[int] = [0]
	body.get_inventory().goods_change.connect(func(): changes[0] += 1)
	check(body.plan_execution.start(body), "Passenger return service starts")
	for frame: int in range(6000):
		await tree.physics_frame
		if body.plan_execution.status == "Plan complete":
			break
	check(body.plan_execution.status == "Plan complete", "Passenger service returns after its U-turn: " + body.plan_execution.status)
	check(changes[0] == 4 and body.get_inventory().amount_used == 0, "Exactly two pickups and two completed trips occur")
	check(a.get_inventory_view().get_inventory().amount_used == 0 and b.get_inventory_view().get_inventory().amount_used == 0, "No passengers are stranded or duplicated by the turn")
	body.free()
	return true
