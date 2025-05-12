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
	return instance
