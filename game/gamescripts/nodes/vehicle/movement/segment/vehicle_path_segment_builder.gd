## Builds the next route segment from the current switch settings.
class_name VehiclePathSegmentBuilder extends RefCounted

static func find_next_segment(current_segment: VehiclePathSegment) -> VehiclePathSegment:
	var next_track_num: int = get_next_track_num_from_node(current_segment.end_node)
	var next_dir: Enums.PathDirection = get_next_dir_at_fork(next_track_num, current_segment.end_node)
	if next_track_num >= 0 && next_dir != Enums.PathDirection.STOP:
		var next_linked_segment: VehiclePathSegment = VehiclePathSegment.of_rail(next_track_num, next_dir)
		if not InfrType.rail_gauges_compatible(current_segment.as_rail_track().infr_type_key, next_linked_segment.as_rail_track().infr_type_key):
			return null
		Loggie.info("Continuing %s on track %d" % [PathCurveUtils.get_dir_enum_name(next_dir), next_track_num])
		next_linked_segment.previous = current_segment
		# connect to previous
		current_segment.next = next_linked_segment
		current_segment.continues = true
		return next_linked_segment
	return null

static func get_first_segment(movement: TrainMovement) -> VehiclePathSegment:
	var veh_parking_node: RailNodeData = movement.last_node
	var first_track_num = veh_parking_node.parent_track.num
	var motor_direction: Enums.PathDirection = movement.direction
	return VehiclePathSegment.of_rail(first_track_num, motor_direction)

#region Find Next
## if given node has a fork with a setting, returns track num that said fork is set to
static func get_next_track_num_from_node(segment_end: RailNodeData) -> int:
	## A buffer or unconnected endpoint is a normal end of route.
	if segment_end == null or segment_end.fork == null:
		return -1
	var fork_parent: NewRailForkData = segment_end.fork.junction
	if fork_parent == null or fork_parent.setting.current == null:
		return -1
	var next_track_num: int = fork_parent.setting.get_next_track_from_track(segment_end.parent_track.num)
	if next_track_num < 0:
		Loggie.error("Cannot continue from node %d at track %d: fork hasnt any setting" % [segment_end.parent_track.num, segment_end.index])
		return -1
	return next_track_num

## Entering the next track at its first node travels with increasing node order, at its last node against it.
static func get_next_dir_at_fork(next_track_num: int, segment_end: RailNodeData) -> Enums.PathDirection:
	if next_track_num <= -1 or segment_end == null or segment_end.fork == null or segment_end.fork.junction == null:
		return Enums.PathDirection.STOP
	var next_leg: RailNodeForkData = segment_end.fork.junction.get_node_fork(next_track_num)
	if next_leg == null:
		return Enums.PathDirection.STOP
	if next_leg.railNode.is_last():
		return Enums.PathDirection.TRACK_NODES_DECREASE
	return Enums.PathDirection.TRACK_NODES_INCREASE
#endregion
