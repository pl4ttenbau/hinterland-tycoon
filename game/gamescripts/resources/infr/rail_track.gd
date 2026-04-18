@icon("res://assets/icons/icon_rail_track_white.png")
@warning_ignore("missing_tool")
class_name RailTrackData extends AbstractTrack

@export var nodes: Array[RailNodeData] = []
@export var hideFill: bool = false

# child objects
@export var node_stations: Array[NodeStationLinkData] = []
@export var forks: Array[RailNodeForkData] = []

const NEAR_DISTANCE_MAX: float = 100.0

func _init():
	super(Enums.EntityTypes.RAIL)

static func get_by_num(_rail_num: int) -> RailTrackData:
	return Managers.rails.track_storage.get_by_num(_rail_num)
	
#region Add Nodes
func add_node(rail_node: RailNodeData, update: bool):
	self.nodes.append(rail_node) 
	self.vertices.append(rail_node.position)
	if update:
		self.track_changed.emit()
		self.build_curve()
	
func add_fork(rail_fork: RailNodeForkData):
	self.forks.append(rail_fork)
#endregion

func build_curve() -> void:
	# if self.curve: return
	self.curve = Curve3D.new()
	self.curve.up_vector_enabled = true
	# add points to curve (optionally with curve handles)
	for node: RailNodeData in self.nodes:
		self.curve.add_point(node.position, node.handle_in, node.handle_out)
	self.curve_built.emit(self.curve)
	# generate AABB & smoothe
	self.abs_aabb = InfrUtils.get_aabb(self.vertices)
	InfrUtils.smooth_curve3d(self.curve)

#region Distance Check
func is_near(pos: Vector3) -> bool:
	if self.get_start_pos().distance_to(pos) <= NEAR_DISTANCE_MAX:
		return true
	elif self._get_center().distance_to(pos) <= NEAR_DISTANCE_MAX:
		return true
	elif self.get_end_pos().distance_to(pos) <= NEAR_DISTANCE_MAX:
		return true
	return false
#endregion

#region Get Nodes
func get_rail_node(_i: int) -> RailNodeData:
	if _i >= 0 && _i < self.nodes.size():
		return self.nodes.get(_i)
	return null
	
func get_end_node() -> RailNodeData:
	var last_i: int = self.nodes.size() -1
	return self.nodes[last_i]

func has_node_index(_index: int) -> bool:
	var last_i: int = self.nodes.size() -1
	return _index >= 0 && _index <= last_i

func get_node_forks() -> Array[RailNodeForkData]:
	var node_forks: Array[RailNodeForkData] = []
	if self.nodes[0].fork:
		node_forks.append(self.nodes[0].fork)
	if self.get_end_node().fork:
		node_forks.append(self.get_end_node().fork)
	return node_forks
#endregion

#region Directional Node Getters
## iterate through all track nodes forwards or backwards & add them into an array
func get_nodes_directionally(track_dir: Enums.PathDirection) -> Array[RailNodeData]:
	var node_list: Array[RailNodeData] = []
	if track_dir == Enums.PathDirection.TRACK_NODES_DECREASE:
		for i in self.nodes.size(): # iterate & add backwards
			node_list.append(self.nodes[-i-1])
	else:
		for node: RailNodeData in self.nodes: # iterate & add forwards
			node_list.append(node)
	return node_list

## dont get confused here - the last node backwards is 0, the last node forwards is length - 1
func get_last_node_directionally(track_dir: Enums.PathDirection) -> RailNodeData:
	if track_dir == Enums.PathDirection.TRACK_NODES_DECREASE:
		return self.nodes[0]
	else:
		return self.nodes[self.nodes.size() -1]
#endregion

func _to_string() -> String:
	return "RailTrack_%d" % self.num
