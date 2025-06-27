class_name RailTrackData extends AbstractTrack

const SCENE_PATH = "res://scenes/subscenes/infr/rail_path_mesh_3d.tscn"

@export var nodes: Array[RailNodeData] = []
@export_storage var stations: Array[RailStationData] = []
@export_storage var forks: Array[RailForkData] = []

signal created(track: RailForkData)

func _init():
	super(Enums.EntityTypes.RAIL)
	
func _to_string() -> String:
	return "RailTrack_%d" % self.num
	
static func from_json(_track_dict: Dictionary) -> RailTrackData:
	var track_instance := RailTrackData.new()
	track_instance.num = int(_track_dict.num)
	track_instance.infr_type_key = _track_dict.get("type")
	track_instance.offset = WorldUtils.vec3_from_float_arr(_track_dict.offset)
	# track_instance.name = "RailTrack" + str(track_instance.num)
	add_points_from_json(_track_dict, track_instance)
	track_instance.created.emit(track_instance)
	return track_instance
	
static func add_points_from_json(_json_track: Dictionary, _track: RailTrackData):
	var node_index: int = 0
	for rail_node_dict: Dictionary in _json_track.points:
		var vec3: Vector3 = WorldUtils.vec3_from_float_arr(rail_node_dict.pos)
		var rail_node_obj := RailNodeData.of(node_index, vec3, "RAIL_750MM", _track)
		rail_node_obj.parse_and_add_special(rail_node_dict)
		_track.add_node(rail_node_obj)
		node_index += 1
	
# == ADD CHILD NODES ==
func add_node(rail_node: RailNodeData):
	self.nodes.append(rail_node) 
	self.vertices.append(rail_node.position)
	
func add_fork(rail_fork: RailForkData):
	self.forks.append(rail_fork)
	
func get_rail_node(_i: int) -> RailNodeData:
	if _i > 0 && _i < self.nodes.size():
		return self.nodes.get(_i)
	return null

func get_end_pos() -> Vector3:
	var last_i: int = self.nodes.size() -1
	return self.nodes[last_i].position
	
func has_node_index(_index: int) -> bool:
	var last_i: int = self.nodes.size() -1
	return _index >= 0 && _index <= last_i
