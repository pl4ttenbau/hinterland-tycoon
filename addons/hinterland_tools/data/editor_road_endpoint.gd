@tool
## A road endpoint in world space, used for editor junction matching and JSON updates.
class_name EditorRoadEndpoint extends RefCounted

var road_num: int
var endpoint: int
var node_index: int
var position: Vector3

func _init(number: int, end: int, world_position: Vector3, index: int = -1) -> void:
	road_num = number
	endpoint = end
	position = world_position
	node_index = index
