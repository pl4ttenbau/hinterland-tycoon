@tool
class_name RailNodeSpecial extends Node3D

@export var nodeType: String
@export var connectiveTrack: int

static func of(_nodeType: String) -> RailNodeSpecial:
	var instance = RailNodeSpecial.new()
	instance.nodeType = _nodeType
	return instance
