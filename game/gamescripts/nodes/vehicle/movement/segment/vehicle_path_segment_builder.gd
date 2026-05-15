class_name VehiclePathSegmentBuilder extends Node

@export var train: Train3D

@export var train_dir: Enums.PathDirection

static func of(_train: Train3D, _train_dir: Enums.PathDirection) -> VehiclePathSegmentBuilder:
	var builder: VehiclePathSegmentBuilder = VehiclePathSegmentBuilder.new()
	builder.train = _train
	builder.train_dir = _train_dir
	return builder

static func find_next_segment(current_segment: VehiclePathSegment) -> VehiclePathSegment:
	var segment_end: RailNodeData = current_segment.get_last_node_directionally(current_segment.movement_dir)
	var next_track_num: int = get_next_track_num_from_node(segment_end)
	var next_dir: Enums.PathDirection = get_next_dir_at_fork(next_track_num, segment_end.position)
	if next_track_num >= 0 && next_dir != Enums.PathDirection.STOP:
		Loggie.info("Continuing %s on track %d" % [current_segment.get_dir_enum_name(next_dir), next_track_num])
		var next_linked_segment: VehiclePathSegment = VehiclePathSegment.of_rail(next_track_num, next_dir)
		next_linked_segment.previous = current_segment
		# connect to previous
		current_segment.next = next_linked_segment
		current_segment.continues = true
		return next_linked_segment
	return null

#region Find Next
## if given node has a fork with a setting, returns track num that said fork is set to
static func get_next_track_num_from_node(segment_end: RailNodeData) -> int:
	if !segment_end || !segment_end.fork:
		Loggie.error("Cannot continue from node %d at track %d: no fork found" % [segment_end.parent_track.num, segment_end.index])
		return -1
	if !segment_end.fork.set_to:
		Loggie.error("Cannot continue from node %d at track %d: fork hasnt any setting" % [segment_end.parent_track.num, segment_end.index])
		return -1
	return segment_end.fork.set_to

static func get_next_dir_at_fork(next_track_num: int, fork_pos: Vector3) -> Enums.PathDirection:
	if next_track_num < 0:
		return Enums.PathDirection.STOP
	var next_track: RailTrackData = RailTrackData.get_by_num(next_track_num)
	for rail_node: RailNodeData in next_track.nodes:
		if rail_node.position == fork_pos:
			if rail_node.is_last(): return Enums.PathDirection.TRACK_NODES_DECREASE
	return Enums.PathDirection.TRACK_NODES_INCREASE
#endregion
