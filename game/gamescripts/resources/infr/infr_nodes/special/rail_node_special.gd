@tool
class_name RailNodeSpecial extends Resource

@export_storage var railNode: RailNode
@export var nodeType: String
@export var connectiveTracks: Array[int]

static func of(_nodeType: String, _railNode: RailNode = null) -> RailNodeSpecial:
	var instance = RailNodeSpecial.new()
	instance.nodeType = _nodeType
	instance.railNode = _railNode
	return instance
