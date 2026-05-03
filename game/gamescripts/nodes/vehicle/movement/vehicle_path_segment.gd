class_name VehiclePathSegment extends RefCounted

@export var infr_domain: Enums.InfrDomain

@export var track_num: int

@export var movement_dir: Enums.PathDirection

static func of_rail(_track_num: int, _dir: Enums.PathDirection) -> VehiclePathSegment:
	var inst: VehiclePathSegment = VehiclePathSegment.new()
	inst.infr_domain = Enums.InfrDomain.RAIL
	inst.track_num = _track_num
	inst.movement_dir = _dir
	return inst

func as_rail_track() -> RailTrackData:
	return RailTrackData.get_by_num(self.track_num)

#region Senction Nodes
## returns list of this Segment's rail nodes, in the order they are defined, originally inm JSON
func get_nodes_per_rail() -> Array[RailNodeData]:
	return self.as_rail_track().nodes

## returns list of this Segment's rail nodes, ordered in this Segment's movement direction
func get_nodes_directionally() -> Array[RailNodeData]:
	var rail_nodes: Array[RailNodeData] = self.get_nodes_per_rail()
	var sorted_node_list: Array[RailNodeData] = []
	if self.movement_dir == Enums.PathDirection.TRACK_NODES_DECREASE:
		for i in self.get_nodes_per_rail().size(): # iterate & add backwards
			sorted_node_list.append(rail_nodes[-i-1])
	else:
		return rail_nodes # add forwards
	return sorted_node_list

## dont get confused here - the last node backwards is 0, the last node forwards is length - 1
func get_last_node_directionally(track_dir: Enums.PathDirection) -> RailNodeData:
	var rail_nodes: Array[RailNodeData] = self.get_nodes_per_rail()
	if track_dir == Enums.PathDirection.TRACK_NODES_DECREASE:
		return rail_nodes[0]
	else:
		return rail_nodes[rail_nodes.size() -1]
#endregion

#region Find Next
func find_next_segment() -> VehiclePathSegment:
	var segment_end: RailNodeData = self.get_last_node_directionally(self.movement_dir)
	var next_track_num: int = self.get_next_track_num_from_node(segment_end)
	var next_dir: Enums.PathDirection = self.get_next_dir_at_fork(next_track_num, segment_end.position)
	if next_track_num >= 0 && next_dir != Enums.PathDirection.STOP:
		Loggie.info("Continuing %s on track %d" % [self.get_dir_enum_name(next_dir), next_track_num])
		return VehiclePathSegment.of_rail(next_track_num, next_dir)
	return null

func get_next_track_num_from_node(segment_end: RailNodeData) -> int:
	if !segment_end || !segment_end.fork:
		Loggie.error("Cannot continue from node %d at track %d: no fork found" % [segment_end.parent_track.num, segment_end.index])
		return -1
	if !segment_end.fork.set_to:
		Loggie.error("Cannot continue from node %d at track %d: fork hasnt any setting" % [segment_end.parent_track.num, segment_end.index])
		return -1
	return segment_end.fork.set_to

func get_next_dir_at_fork(next_track_num: int, fork_pos: Vector3) -> Enums.PathDirection:
	if next_track_num < 0:
		return Enums.PathDirection.STOP
	var next_track: RailTrackData = RailTrackData.get_by_num(next_track_num)
	for rail_node: RailNodeData in next_track.nodes:
		if rail_node.position == fork_pos:
			if rail_node.is_last(): return Enums.PathDirection.TRACK_NODES_DECREASE
	return Enums.PathDirection.TRACK_NODES_INCREASE
#endregion

func get_dir_enum_name(dir_enum: Enums.PathDirection) -> String:
	if dir_enum == Enums.PathDirection.TRACK_NODES_INCREASE: return "forwards"
	elif dir_enum == Enums.PathDirection.TRACK_NODES_DECREASE: return "backwards"
	else: return "stopped"
