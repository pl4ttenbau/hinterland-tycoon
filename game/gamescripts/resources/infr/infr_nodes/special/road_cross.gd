class_name RoadCross extends Resource

@export var connectiveRoads: Array
@export var roadNode: RailNode
@export var nodeType: String

static func of(_node: RailNode, _connected_tracks: Array) -> RailFork:
	var instance: RailFork = RailFork.new()
	instance.railNode = _node
	instance.connectiveTracks = _connected_tracks
	instance.nodeType = "SWITCH"
	return instance
