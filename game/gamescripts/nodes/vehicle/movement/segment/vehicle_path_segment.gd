class_name VehiclePathSegment extends Resource

@export var infr_domain: Enums.InfrDomain

@export var track_num: int

@export var movement_dir: Enums.PathDirection

@export var continues: bool = false

@export var next: VehiclePathSegment

@export var previous: VehiclePathSegment

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
		 # iterate & add backwards
		for i in self.get_nodes_per_rail().size():
			sorted_node_list.append(rail_nodes[-i-1])
	else:
		# add forwards
		return rail_nodes 
	return sorted_node_list

## dont get confused here - the last node backwards is 0, the last node forwards is length - 1
func get_last_node_directionally(track_dir: Enums.PathDirection) -> RailNodeData:
	var rail_nodes: Array[RailNodeData] = self.get_nodes_per_rail()
	if track_dir == Enums.PathDirection.TRACK_NODES_DECREASE:
		return rail_nodes[0]
	else:
		return rail_nodes[rail_nodes.size() -1]
#endregion

func get_dir_enum_name(dir_enum: Enums.PathDirection) -> String:
	if dir_enum == Enums.PathDirection.TRACK_NODES_INCREASE: return "forwards"
	elif dir_enum == Enums.PathDirection.TRACK_NODES_DECREASE: return "backwards"
	else: return "stopped"
