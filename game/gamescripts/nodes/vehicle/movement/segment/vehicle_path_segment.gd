class_name VehiclePathSegment extends Resource

@export var infr_domain: Enums.InfrDomain
@export var track_num: int

@export var movement_dir: Enums.PathDirection

@export var continues: bool = false
@export var next: VehiclePathSegment
@export var previous: VehiclePathSegment

@export var start_node: RailNodeData
@export var end_node: RailNodeData

static func of_rail(_track_num: int, _dir: Enums.PathDirection) -> VehiclePathSegment:
	var inst: VehiclePathSegment = VehiclePathSegment.new()
	inst.infr_domain = Enums.InfrDomain.RAIL
	inst.track_num = _track_num
	inst.movement_dir = _dir
	# look for start and end node
	inst.start_node = inst.get_first_node_directionally(_dir)
	inst.end_node = inst.get_last_node_directionally(_dir)
	
	return inst

func as_rail_track() -> RailTrackData:
	return RailTrackData.get_by_num(self.track_num)

func reverse():
	self.movement_dir = PathCurveUtils.get_reversed_direction(self.movement_dir)
	# switch start & end node
	var old_start_node: RailNodeData = self.start_node
	var old_end_node: RailNodeData = self.end_node
	self.start_node = old_end_node
	self.end_node = old_start_node

#region Section Nodes
## returns list of this Segment's rail nodes, ordered in this Segment's movement direction
func get_nodes_directionally() -> Array[RailNodeData]:
	var rail_nodes: Array[RailNodeData] = self.as_rail_track().nodes
	var sorted_node_list: Array[RailNodeData] = []
	if self.movement_dir == Enums.PathDirection.TRACK_NODES_DECREASE:
		 # iterate & add backwards
		for i in self.as_rail_track().nodes.size():
			sorted_node_list.append(rail_nodes[-i-1])
	else:
		return rail_nodes # add forwards
	return sorted_node_list

## dont get confused here - the last node backwards is 0, the last node forwards is length - 1
func get_last_node_directionally(track_dir: Enums.PathDirection) -> RailNodeData:
	var rail_nodes: Array[RailNodeData] = self.as_rail_track().nodes
	if track_dir == Enums.PathDirection.TRACK_NODES_DECREASE:
		return rail_nodes[0]
	else:
		return rail_nodes[rail_nodes.size() -1]

func get_first_node_directionally(track_dir: Enums.PathDirection) -> RailNodeData:
	var rail_nodes: Array[RailNodeData] = self.as_rail_track().nodes
	if track_dir == Enums.PathDirection.TRACK_NODES_DECREASE:
		return rail_nodes[rail_nodes.size() -1]
	else:
		return rail_nodes[0]
#endregion
