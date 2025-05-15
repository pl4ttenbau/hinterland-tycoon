@tool
class_name RailNodeSpecial extends RefCounted

@export var nodeType: String
@export var connectiveTracks: Array[int]

static func of(_nodeType: String) -> RailNodeSpecial:
	var instance = RailNodeSpecial.new()
	instance.nodeType = _nodeType
	return instance
