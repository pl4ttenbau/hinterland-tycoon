@icon("res://assets/icons/icon_rail_track_white.png")
class_name RailTrackData extends AbstractTrack

@export var nodes: Array[RailNodeData] = []

# child objects
@export var stations: Array[RailStationData] = []
@export var forks: Array[RailNodeForkData] = []

@export var start_pos: Vector3

func _init():
	super(Enums.EntityTypes.RAIL)
	
func _to_string() -> String:
	return "RailTrack_%d" % self.num

static func get_by_num(_rail_num: int) -> RailTrackData:
	return Managers.rails.track_storage.get_by_num(_rail_num)
	
#region Add Nodes
func add_node(rail_node: RailNodeData):
	self.nodes.append(rail_node) 
	self.vertices.append(rail_node.position)
	
func add_fork(rail_fork: RailNodeForkData):
	self.forks.append(rail_fork)
#endregion

#region Get Nodes
func get_rail_node(_i: int) -> RailNodeData:
	if _i >= 0 && _i < self.nodes.size():
		return self.nodes.get(_i)
	return null
	
func get_end_node() -> RailNodeData:
	var last_i: int = self.nodes.size() -1
	return self.nodes[last_i]

func get_end_pos() -> Vector3:
	var last_i: int = self.nodes.size() -1
	return self.nodes[last_i].position
#endregion
	
func has_node_index(_index: int) -> bool:
	var last_i: int = self.nodes.size() -1
	return _index >= 0 && _index <= last_i

func build_path() -> void:
	# if self.curve: return
	self.curve = Curve3D.new()
	self.curve.up_vector_enabled = true
	for point: Vector3 in self.vertices:
		self.curve.add_point(point)
