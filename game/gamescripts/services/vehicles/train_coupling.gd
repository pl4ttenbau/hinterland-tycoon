## Changes consist membership while retaining the placed vehicles and their rail poses.
class_name TrainCoupling extends RefCounted

const COUPLING_RANGE_METRES: float = 0.75
const CONTACT_OVERLAP_METRES: float = 0.25
const PLACEMENT_TOLERANCE_METRES: float = 0.85

class Connection:
	var other: Train3D
	var own_end: Vehicle3D
	var facing_end: Vehicle3D
	var at_front: bool
	var reverse_order: bool
	var gap: float

class Placement:
	var source: ActiveRailVehiclePath
	var anchor_distance: float
	var reversed: bool

class JoinPlan:
	var connection: Connection
	var error: String
	var surviving: Train3D
	var retiring: Train3D
	var ordered: Array[Vehicle3D]
	var placement: Placement

static func available(train: Train3D) -> bool:
	return is_instance_valid(train) and train.is_inside_tree() and not train.is_queued_for_deletion() \
		and train.train_obj != null and not train.vehicles.is_empty() \
		and train.movement != null and train.movement.active_path != null and is_instance_valid(Managers.vehicles) \
		and train in Managers.vehicles.trains

## Front and rear follow the ordered consist, independent of the selected driving direction.
static func nearby(train: Train3D, at_front: bool) -> Connection:
	if not available(train):
		return null
	var own_end: Vehicle3D = train.vehicles.front() if at_front else train.vehicles.back()
	var segment: VehiclePathSegment = train.movement.get_vehicle_segment(own_end)
	var track: RailTrackData = segment.as_rail_track()
	var own_position: float = track.curve.get_closest_offset(own_end.global_position)
	var sign_out: float = _outward_sign(train, own_end, at_front)
	var closest: Connection
	for other: Train3D in Managers.vehicles.trains:
		if other == train or not available(other):
			continue
		for other_front: bool in [true, false]:
			var facing: Vehicle3D = other.vehicles.front() if other_front else other.vehicles.back()
			if other.movement.get_vehicle_segment(facing).track_num != segment.track_num:
				continue
			var facing_sign: float = _outward_sign(other, facing, other_front)
			if facing_sign == sign_out:
				continue
			var centre_distance: float = (track.curve.get_closest_offset(facing.global_position) - own_position) * sign_out
			var gap: float = centre_distance - (own_end.vehicle_obj.veh_type.length_metres \
				+ facing.vehicle_obj.veh_type.length_metres) * 0.5
			if gap < -CONTACT_OVERLAP_METRES or gap > COUPLING_RANGE_METRES:
				continue
			if closest != null and absf(closest.gap) <= absf(gap):
				continue
			closest = Connection.new()
			closest.other = other
			closest.own_end = own_end
			closest.facing_end = facing
			closest.at_front = at_front
			closest.reverse_order = at_front == other_front
			closest.gap = gap
	return closest

static func _outward_sign(train: Train3D, vehicle: Vehicle3D, at_front: bool) -> float:
	var segment: VehiclePathSegment = train.movement.get_vehicle_segment(vehicle)
	var increasing: bool = segment.movement_dir == Enums.PathDirection.TRACK_NODES_INCREASE
	var front_sign: float = 1.0 if increasing != train.movement.is_reversed else -1.0
	return front_sign if at_front else -front_sign

static func split_error(train: Train3D, ahead: Vehicle3D, behind: Vehicle3D) -> String:
	if not available(train) or not is_instance_valid(ahead) or not is_instance_valid(behind) \
		or ahead.train3d != train or behind.train3d != train or behind.num_in_train != ahead.num_in_train + 1:
		return "That joint is no longer available."
	if not train.movement.is_parked():
		return "Bring the train to a stop before uncoupling."
	return ""

static func split(train: Train3D, ahead: Vehicle3D, behind: Vehicle3D) -> String:
	var problem: String = split_error(train, ahead, behind)
	if not problem.is_empty():
		return problem
	var cut: int = behind.num_in_train
	var front: Array[Vehicle3D] = train.vehicles.slice(0, cut)
	var rear: Array[Vehicle3D] = train.vehicles.slice(cut)
	## The cab and its train-level inventory stay together.
	var keep_front: bool = train.locomotive == null or train.locomotive in front
	var keep: Array[Vehicle3D] = front if keep_front else rear
	var detach: Array[Vehicle3D] = rear if keep_front else front
	var detached: Train3D = load(Train3D.EMPTY_SCENE_PATH).instantiate()
	detached.train_obj = TrainData.new()
	var parked := detached.movement
	parked.is_reversed = train.movement.is_reversed
	parked.active_path = train.movement.active_path.copy_for(parked)
	detached.add_child(parked.active_path)
	parked.m_passed_since_start = train.movement.get_vehicle_distance(detach.front())
	parked.update_segment_progress()
	parked.speed.target = 0.0
	parked.speed.brake_applied = true
	var station := train.current_station
	var keep_distance: float = train.movement.get_vehicle_distance(keep.front())
	## A pending depot rollout must not resume under the newly split consist.
	train.movement.cancel_rollout()
	Managers.vehicles.register_train(detached)
	train.movement.m_passed_since_start = keep_distance
	detached.replace_consist(detach)
	train.replace_consist(keep)
	train.movement.update_segment_progress()
	if detached.locomotive != null:
		parked.start()
	if is_instance_valid(station):
		station.refresh_train(train)
		station.refresh_train(detached)
	return ""

static func _is_occupied(train: Train3D) -> bool:
	return is_instance_valid(GlobalState.player) and GlobalState.player.control.current_train() == train

## Plan against the live railway for both the dialog and the final transaction.
static func plan_join(train: Train3D, at_front: bool, expected: Connection = null) -> JoinPlan:
	var plan := JoinPlan.new()
	var connection: Connection = nearby(train, at_front)
	plan.connection = connection
	if expected != null and (connection == null or not is_instance_valid(expected.facing_end) \
		or not is_instance_valid(expected.own_end) or not is_instance_valid(expected.other) \
		or connection.facing_end != expected.facing_end or connection.own_end != expected.own_end \
		or connection.other != expected.other or connection.reverse_order != expected.reverse_order):
		plan.error = "The facing vehicles changed. Choose the coupling again."
		return plan
	if connection == null:
		plan.error = "That coupling is no longer available."
		return plan
	if not train.movement.is_parked() or not connection.other.movement.is_parked():
		plan.error = "Bring both trains to a stop before coupling."
		return plan

	## A dialog following a detached wagon can couple back onto the occupied cab.
	plan.surviving = train
	plan.retiring = connection.other
	if _is_occupied(connection.other):
		plan.surviving = connection.other
		plan.retiring = train
		at_front = connection.at_front == connection.reverse_order
	var target: GoodsInventory = plan.surviving.get_inventory()
	var source: GoodsInventory = plan.retiring.get_inventory()
	if source.storage.current_storage > 0.0 \
		and target.storage.current_storage + source.storage.current_storage > target.amount_max + 0.00001:
		plan.error = "Unload some of the trains' stock before coupling. The joined train has one inventory."
		return plan

	var attached: Array[Vehicle3D] = plan.retiring.vehicles.duplicate()
	if connection.reverse_order:
		attached.reverse()
	var retained: Array[Vehicle3D] = plan.surviving.vehicles
	plan.ordered = attached + retained if at_front else retained + attached
	plan.placement = _plan_placement(plan.surviving.movement, retained.front(), plan.ordered)
	if plan.placement == null:
		## The other route may hold track history that the selected train has never traversed.
		plan.placement = _plan_placement(plan.retiring.movement, retained.front(), plan.ordered, connection.reverse_order)
	if plan.placement == null:
		plan.error = "The joined consist cannot fit on the current rail route."
	return plan

## Recheck the exact pair and calculate placement again before changing either consist.
static func join(train: Train3D, expected: Connection) -> String:
	if expected == null:
		return "That coupling is no longer available."
	var plan: JoinPlan = plan_join(train, expected.at_front, expected)
	if not plan.error.is_empty():
		return plan.error
	_apply_join(plan)
	return ""

static func _apply_join(plan: JoinPlan) -> void:
	var train: Train3D = plan.surviving
	var other: Train3D = plan.retiring
	var station := other.current_station
	var was_unpowered: bool = train.locomotive == null
	train.movement.cancel_rollout()
	if plan.connection.reverse_order:
		for vehicle: Vehicle3D in other.vehicles:
			vehicle.faces_rear = not vehicle.faces_rear
	_apply_placement(train, plan.placement)
	train.replace_consist(plan.ordered)
	train.movement.place_vehicles()
	if was_unpowered and train.locomotive != null:
		train.movement.speed.brake_applied = true
		train.movement.start()
	train.get_inventory().absorb_stock(other.get_inventory())
	other.replace_consist([])
	if is_instance_valid(station):
		station.refresh_train(other)
		station.refresh_train(train)
	Managers.vehicles.unregister_train(other)
	other.movement.stop()
	other.movement.active_path.retire()
	other.queue_free()

## Keep the selected vehicles stationary and close only the small gap at the joint.
static func _plan_placement(controller: TrainMovement, anchor: Vehicle3D, ordered: Array[Vehicle3D],
		flip_order: bool = false) -> Placement:
	var route: ActiveRailVehiclePath = controller.active_path
	var reversed: bool = controller.is_reversed != flip_order
	var step: float = 1.0 if reversed else -1.0
	var anchor_distance: float = controller.get_vehicle_distance(anchor) if anchor.train3d == controller.train \
		else route.curve.get_closest_offset(route.to_local(anchor.global_position))
	var offsets: Array[float] = [0.0]
	for index: int in range(1, ordered.size()):
		offsets.append(offsets.back() + (ordered[index - 1].vehicle_obj.veh_type.length_metres \
			+ ordered[index].vehicle_obj.veh_type.length_metres) * 0.5)
	var first_distance: float = anchor_distance - offsets[ordered.find(anchor)] * step
	var route_length: float = route.curve.get_baked_length()
	for index: int in range(ordered.size()):
		var distance: float = first_distance + offsets[index] * step
		if distance < -0.001 or distance > route_length + 0.001:
			return null
		var vehicle: Vehicle3D = ordered[index]
		var segment: VehiclePathSegment = route.segments[route.get_segment_index(distance)]
		if segment.track_num != vehicle.train3d.movement.get_vehicle_segment(vehicle).track_num:
			return null
		if controller.get_rail_transform(distance).origin.distance_to(vehicle.global_position) > PLACEMENT_TOLERANCE_METRES:
			return null
	var placement := Placement.new()
	placement.source = route
	placement.anchor_distance = clampf(first_distance, 0.0, route_length)
	placement.reversed = reversed
	return placement

static func _apply_placement(train: Train3D, placement: Placement) -> void:
	var controller := train.movement
	if controller.active_path != placement.source:
		controller.active_path.retire()
		controller.active_path = placement.source.copy_for(controller)
		train.add_child(controller.active_path, true)
		## Keep the selected cab's driving direction when adopting the other route.
		if controller.is_reversed != placement.reversed:
			placement.anchor_distance = controller.active_path.curve.get_baked_length() - placement.anchor_distance
			controller.active_path.reverse_route()
			placement.reversed = controller.is_reversed
	controller.m_passed_since_start = placement.anchor_distance
	controller.is_reversed = placement.reversed
	controller.update_segment_progress()
