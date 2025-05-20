class_name RailFork extends Resource

@export var connectiveTracks: Array
@export var railNode: RailNode
@export var nodeType: String

static func of(_node: RailNode, _connected_tracks: Array) -> RailFork:
	var instance: RailFork = RailFork.new()
	instance.railNode = _node
	instance.connectiveTracks = _connected_tracks
	instance.nodeType = "SWITCH"
	return instance
