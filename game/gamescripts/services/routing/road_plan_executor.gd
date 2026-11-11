## Drive visits and execute their ordered stop actions once after coming to rest.
class_name RoadPlanExecutor extends RefCounted

## Lifecycle state is separate from the vehicle's manual/automatic input source.
var running: bool = false
var current_point: int = 0
var status: String = "Not started"
var _plan: RoadRoutePlan
var _network := RoadPathfinder.new()
var _servicing_visit: bool = false
## Temporary navigation substep, never a visit: current_point stays unchanged.
## Keeping the approach until completion also lets manual interruption replan.
var _turn_approach: RoadUTurnPlanner.Approach
var _turn_started: bool = false

#region Execution lifecycle
## Keep the endpoint detour visible instead of reporting the pending stop as the
## immediate driving target. The movement controller need not inspect plan state.
func driving_status() -> String:
	return "Driving to road end for a U-turn" if _turn_approach != null else "Driving to point %d" % (current_point + 1)

## Freeze a validated plan so editing cannot change a segment that is already being driven.
func start(vehicle: RoadVehicle3D) -> bool:
	if not is_instance_valid(Managers.roads):
		status = "Road network is unavailable."
		return false
	_network.build(Managers.roads.storage.get_all(), vehicle.vehicle_obj.veh_type.usable_infr.subtype)
	var stops: Dictionary = _stops()
	status = vehicle.route_plan.validate(_network, Managers.roads.storage, stops, GlobalState.road_depots, GameTypes.resource_types, vehicle.vehicle_obj.veh_type.capacity, Managers.roads.markers)
	if not status.is_empty():
		return false
	_plan = vehicle.route_plan.duplicate(true)
	vehicle.clear_route()
	_turn_approach = null
	_turn_started = false
	current_point = 0
	_servicing_visit = false
	running = true
	return _begin_visit(vehicle)

func stop(vehicle: RoadVehicle3D, message: String = "Stopped") -> void:
	running = false
	_servicing_visit = false
	_turn_approach = null
	_turn_started = false
	status = message
	vehicle.clear_route()

## Called only while the automatic driver owns control. Manual takeover preserves progress.
func tick(vehicle: RoadVehicle3D) -> void:
	if not running or vehicle.player_driving:
		return
	if _tick_uturn(vehicle):
		return
	if _servicing_visit:
		if vehicle.linear_velocity.length() <= RoadRouteTransferService.MAX_SERVICE_SPEED:
			if _finish_visit(vehicle):
				_begin_visit(vehicle)
	elif not vehicle.route.is_valid():
		stop(vehicle, "Driving path is no longer available.")
	elif vehicle._arrived:
		if not _plan.points[current_point].actions.is_empty():
			_hold_for_actions(vehicle)
		elif _finish_visit(vehicle):
			_begin_visit(vehicle)

#endregion

#region Visit advancement
## Actions run in authored order. A failed action holds the vehicle at this visit;
## prior successful actions stay applied and are never retried automatically.
func _finish_visit(vehicle: RoadVehicle3D) -> bool:
	var point: RoadRoutePoint = _plan.points[current_point]
	for index: int in range(point.actions.size()):
		var result: RoadRouteTransferResult = RoadRouteTransferService.execute(vehicle, point, point.actions[index], _stops())
		if not result.error.is_empty():
			stop(vehicle, "Point %d, action %d: %s" % [current_point + 1, index + 1, result.error])
			return false
	current_point += 1
	if current_point >= _plan.points.size():
		stop(vehicle, "Plan complete")
		return false
	return true

func _begin_visit(vehicle: RoadVehicle3D) -> bool:
	_servicing_visit = false
	while running:
		var point: RoadRoutePoint = _plan.points[current_point]
		var node: RoadNode = point.resolve(Managers.roads.storage, _stops(), GlobalState.road_depots, Managers.roads.markers)
		if node == null:
			stop(vehicle, "Route point no longer exists.")
			return false
		# A starting depot is usually ten metres behind its parked vehicle.
		var radius: float = 12.5 if point.kind == RoadRoutePoint.Kind.DEPOT else 3.0
		if _at_visit(vehicle, node, radius):
			if not point.actions.is_empty():
				_hold_for_actions(vehicle)
				return true
			if not _finish_visit(vehicle):
				return status == "Plan complete"
			continue
		return _assign_visit_path(vehicle, point, node)

	return false

## Starting a plan near its first stop must still wait for automatic control and
## a stationary vehicle. Clearing the driving curve applies the parking brake.
func _hold_for_actions(vehicle: RoadVehicle3D) -> void:
	_servicing_visit = true
	vehicle.clear_route()
	status = "Servicing point %d of %d" % [current_point + 1, _plan.points.size()]

## A single-side marker is served only when facing its permitted approach direction.
func _at_visit(vehicle: RoadVehicle3D, node: RoadNode, radius: float) -> bool:
	if vehicle.global_position.distance_to(node.position) > radius:
		return false
	if node is RoadRouteAnchor and node.arrival_direction != 0:
		var curve: Curve3D = node.parent_track.curve
		var tangent: Vector3 = curve.sample_baked(minf(node.curve_offset + 0.1, curve.get_baked_length())) - curve.sample_baked(maxf(0, node.curve_offset - 0.1))
		return vehicle.global_basis.z.dot(tangent.normalized()) * node.arrival_direction > 0.5
	return true

## The physical driver stops before the end of its curve. Compensate for that
## stop margin so depot arrivals still remain ten metres from the building.
func _assign_visit_path(vehicle: RoadVehicle3D, point: RoadRoutePoint, node: RoadNode) -> bool:
	var segments: Array[Dictionary] = _segments_to(vehicle, node)
	var turn: RoadUTurnPlanner.Approach = RoadUTurnPlanner.prepare(segments, vehicle.global_basis.z)
	if turn != null:
		return _assign_turn_approach(vehicle, turn)
	var trim: float = maxf(0.0, 10.0 - vehicle.dimensions_metres.z * 0.55) if point.kind == RoadRoutePoint.Kind.DEPOT else 0.0
	if segments.is_empty() or not vehicle.route.assign_segments(segments, trim):
		stop(vehicle, "No drivable path from the current position. Move back onto a connected road.")
		return false
	vehicle._arrived = false
	status = "Driving to point %d of %d" % [current_point + 1, _plan.points.size()]
	return true

## A reversal first follows ordinary wheel physics to the road end. Only the
## short turnaround is scripted; the target visit and its actions remain pending.
func _assign_turn_approach(vehicle: RoadVehicle3D, turn: RoadUTurnPlanner.Approach) -> bool:
	_turn_approach = turn
	_turn_started = false
	var margin: float = vehicle.dimensions_metres.z * 0.55
	var assigned: bool = vehicle.route.assign_segments(turn.segments)
	var endpoint: Vector3 = turn.path.to_global(turn.path.curve.sample_baked(turn.offset))
	if (assigned and vehicle.route.remaining() <= margin + 0.4) or (not assigned and vehicle.global_position.distance_to(endpoint) <= margin + 1):
		vehicle.clear_route()
		vehicle._arrived = true
	elif not assigned:
		stop(vehicle, "No drivable approach to the road end for a U-turn.")
		return false
	else:
		vehicle._arrived = false
	status = "Driving to road end for a U-turn"
	return true

## The movement controller owns curve advancement. Replan from the actual exit
## pose after completion or manual interruption, without advancing the visit.
func _tick_uturn(vehicle: RoadVehicle3D) -> bool:
	if _turn_approach == null:
		return false
	if _turn_started:
		# Active curves are advanced by RoadVehicle3D before this executor ticks.
		# Inactive here means completed or manually interrupted: resolve afresh.
		if not vehicle.is_automatic_uturning():
			_turn_approach = null
			_turn_started = false
			_begin_visit(vehicle)
		return true
	if not vehicle._arrived:
		return false
	if vehicle.linear_velocity.length() > 0.2:
		return true
	if vehicle.begin_automatic_uturn(_turn_approach.path, _turn_approach.offset):
		_turn_started = true
	else:
		stop(vehicle, "Could not create the automatic road-end U-turn.")
	return true
#endregion

#region Driving-path construction
## Attach the current road offset to the graph, choosing the lowest total arc cost.
func _segments_to(vehicle: RoadVehicle3D, destination: RoadNode) -> Array[Dictionary]:
	var start: Dictionary = _nearest_road_position(vehicle)
	var nearest: RoadWay3D = start.road
	if nearest == null or float(start.distance) > vehicle.route_recovery_distance:
		return []
	var offset: float = start.offset
	var anchor: RoadRouteAnchor = RoadRouteAnchor.at(nearest.road, offset)
	return _make_segments(nearest.get_path_3d(), offset, _network.find_path(anchor, destination))

## Project onto rendered road curves; do not teleport or attach a far-off car.
func _nearest_road_position(vehicle: RoadVehicle3D) -> Dictionary:
	var nearest: RoadWay3D
	var offset: float = 0.0
	var distance: float = INF
	for road: RoadWay3D in Managers.roads.storage.get_containers():
		var path: Path3D = road.get_path_3d()
		var candidate: float = path.curve.get_closest_offset(path.to_local(vehicle.global_position))
		var error: float = vehicle.global_position.distance_to(path.to_global(path.curve.sample_baked(candidate)))
		if error < distance:
			nearest = road
			offset = candidate
			distance = error
	return {"road": nearest, "offset": offset, "distance": distance}

## Preserve curved geometry within roads; crossing edges only join coincident anchors.
func _make_segments(start: Path3D, offset: float, nodes: Array[RoadNode]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if nodes.is_empty():
		return result
	result.append({"path": start, "from": offset, "to": _offset(nodes[0])})
	for index: int in range(1, nodes.size()):
		var from: RoadNode = nodes[index - 1]
		var to: RoadNode = nodes[index]
		if from.parent_track == to.parent_track:
			var road: RoadWay3D = Managers.roads.storage.get_container_by_num(from.parent_track.num)
			if road == null:
				return []
			result.append({"path": road.get_path_3d(), "from": _offset(from), "to": _offset(to)})
	return result

func _offset(node: RoadNode) -> float:
	return RoadRouteAnchor.offset_of(node)

func _stops() -> Dictionary:
	return Managers.interchanges.stops_by_num if is_instance_valid(Managers.interchanges) else {}

#endregion
