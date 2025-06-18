class_name RailFork extends Resource

@export var connectiveTracks: Array
@export var railNode: RailNode
@export var setTo: int

static func of(_node: RailNode, _connected_tracks: Array) -> RailFork:
	var instance: RailFork = RailFork.new()
	instance.railNode = _node
	instance.connectiveTracks = _connected_tracks
	instance.nodeType = "SWITCH"
	return instance

static func of_dict(fork_dict: Dictionary, parent: RailNode) -> RailFork:
	var inst: RailFork = RailFork.new()
	inst.railNode = parent
	inst.connectiveTracks = fork_dict.get("connectiveTracks") as Array
	inst.setTo = fork_dict.get("setTo", null)
	return inst
