class_name RailTrack extends Node3D

@onready var spawner = %Rails
const rail_scene_path = "res://scenes/subscenes/rail_path_mesh_3d.tscn"

@export_storage var num: int
@export_storage var offset: Vector3
@export_storage var vertices: Array[Vector3] = []
@export_storage var nodes: Array[RailNode] = []
@export_storage var scene_node: Node3D
@export_storage var curve: Curve3D
@export_storage var stations: Array[RailStation] = []

signal created(track: RailTrack)

func _init():
	Loggie.info("RailTrack object creating..")
	
func _to_string() -> String:
	return "RailTrack@%d" % self.num
	
func build_path() -> void:
	self.curve = Curve3D.new()
	for point: Vector3 in self.vertices:
		self.curve.add_point(point)
	
func spawn() -> OuterRailTrack:
	if ! self.curve: 
		self.build_path()
	# instanciate Container from PackedScene
	var scene: Resource = preload(rail_scene_path)
	var _container: OuterRailTrack = scene.instantiate()
	_container.set_track(self)
	_container.get_path_3d().set_curve(self.curve) # set path 3d
	add_to_group("Rails") # add to rails group
	return _container
	
static func from_json(_track_dict: Dictionary) -> RailTrack:
	var track_instance: RailTrack = RailTrack.new()
	track_instance.num = int(_track_dict.num)
	track_instance.offset = WorldUtils.vec3_from_float_arr(_track_dict.offset)
	track_instance.name = "RailTrack" + str(track_instance.num)
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
	
func add_node(rail_node: RailNode):
	self.nodes.append(rail_node) 
	self.vertices.append(rail_node.position)
	
func get_rail_node(_i: int) -> RailNode:
	if _i > 0:
		return self.nodes.get(_i)
	return null
