class_name RailNode extends Node3D

@export var index: int
@export var last: RailNode
@export var next: RailNode
@export var trackType: String
@export var specialNode: RailNodeSpecial

static func of(_index: int, _pos: Vector3, _trackType: String) -> RailNode:
	var instance: RailNode = RailNode.new()
	instance.index = _index
	instance.position = _pos
	instance.trackType = _trackType
	return instance
