class_name RailNode extends Node3D

@export_storage var parent_track: RailTrack
@export var index: int
@export var last: RailNode
@export var next: RailNode
@export var trackType: String
@export var specialNode: RailNodeSpecial

static func of(_index: int, _pos: Vector3, _trackType: String, _track: RailTrack) -> RailNode:
	var instance: RailNode = RailNode.new()
	instance.parent_track = _track
	instance.index = _index
	instance.position = _pos
	instance.trackType = _trackType
	instance.set_previous_node(_index, _track)
	return instance
	
func set_previous_node(_index: int, _track: RailTrack):
	var last_node: RailNode = _track.get_rail_node(_index -1)
	self.last = last_node

func parse_and_add_special(rail_node_dict: Dictionary):
	if rail_node_dict.has("special"):
		var json_special: Dictionary = rail_node_dict.get("special")
		self.specialNode = RailNodeSpecial.of(json_special.nodeType)
