class_name RailTrack extends AbstractTrack

const SCENE_PATH = "res://scenes/subscenes/infr/rail_path_mesh_3d.tscn"

@export_storage var container: OuterRailTrack
@export var nodes: Array[RailNode] = []
@export_storage var stations: Array[RailStationResource] = []
@export_storage var forks: Array[RailFork] = []

signal created(track: RailTrack)

func _init():
	super(Enums.EntityTypes.RAIL)
	
func _to_string() -> String:
	return "RailTrack_%d" % self.num
	
func spawn() -> OuterRailTrack:
	if ! self.curve: self.build_path()
	# instanciate Container from PackedScene
	var scene: Resource = preload(SCENE_PATH)
	var _container: OuterRailTrack = scene.instantiate()
	_container.set_track(self)
	self.container = _container
	# add_to_group("Rails") # add to rails group
	return _container
	
static func from_json(_track_dict: Dictionary) -> RailTrack:
	var track_instance: RailTrack = RailTrack.new()
	track_instance.num = int(_track_dict.num)
	track_instance.infr_type_key = _track_dict.get("type")
	track_instance.offset = WorldUtils.vec3_from_float_arr(_track_dict.offset)
	# track_instance.name = "RailTrack" + str(track_instance.num)
	add_points_from_json(_track_dict, track_instance)
	track_instance.created.emit(track_instance)
	return track_instance
	
static func add_points_from_json(_json_track: Dictionary, _track: RailTrack):
	var node_index: int = 0
	for rail_node_dict: Dictionary in _json_track.points:
		var vec3: Vector3 = WorldUtils.vec3_from_float_arr(rail_node_dict.pos)
		var rail_node_obj: RailNode = RailNode.of(node_index, vec3, 
			"RAIL_750MM", _track)
		rail_node_obj.parse_and_add_special(rail_node_dict)
		_track.add_node(rail_node_obj)
		node_index += 1
	
# == ADD CHILD NODES ==
func add_node(rail_node: RailNode):
	self.nodes.append(rail_node) 
	self.vertices.append(rail_node.position)
	
func add_fork(rail_fork: RailFork):
	self.forks.append(rail_fork)
	
func get_rail_node(_i: int) -> RailNode:
	if _i > 0 && _i < self.nodes.size():
		return self.nodes.get(_i)
	return null

func get_end_pos() -> Vector3:
	var last_i: int = self.nodes.size() -1
	return self.nodes[last_i].position
	
func has_node_with_index(_index: int) -> bool:
	var last_i: int = self.nodes.size() -1
	return _index >= 0 && _index <= last_i
