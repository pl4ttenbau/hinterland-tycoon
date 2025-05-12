class_name RailTrack extends Node3D

@onready var spawner = %Rails
const rail_scene_path = "res://scenes/subscenes/rail_path_mesh_3d.tscn"

var num: int
var offset: Vector3
var vertices: Array[Vector3] = []
var nodes: Array[RailNode] = []
@export_storage var scene_node: Node3D
@export var path_3d: Path3D

signal created(track: RailTrack)

func _init():
	Loggie.info("RailTrack object creating..")
	
func build_path() -> void:
	var path = Path3D.new()
	path.curve = Curve3D.new()
	for point: Vector3 in self.vertices:
		path.curve.add_point(point)
	self.path_3d = path
	
func spawn() -> OuterRailTrack:
	if !self.path_3d: self.build_path()
	# instanciate Container from PackedScene
	var scene: Resource = ResourceLoader.load(rail_scene_path)
	var _container: OuterRailTrack = scene.instantiate()
	_container.set_track(self)
	# build path3d
	var path3d: Path3D = _container.get_path_3d()
	for point in self.vertices:
		path3d.curve.add_point(point)
	path3d.set_curve(self.path_3d.curve)
	path3d.curve_changed.emit()
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
		if rail_node_dict.has("special"):
			var json_special: Dictionary = rail_node_dict.get("special")
			var special: RailNodeSpecial = RailNodeSpecial.of(json_special.nodeType)
			rail_node_obj.specialNode = special
		_track.add_node(rail_node_obj)
		node_index += 1
	
func add_node(rail_node: RailNode):
	self.nodes.append(rail_node) 
	self.vertices.append(rail_node.position)
	
func get_rail_node(_i: int) -> RailNode:
	return self.nodes.get(_i)

func _to_string() -> String:
	return "<RailTrack %d vertices=%d>" % [self.num, self.vertices.size()]
