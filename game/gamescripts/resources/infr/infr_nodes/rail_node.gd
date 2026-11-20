@icon("res://assets/icons/icon_infr_node_white.png")
class_name RailNodeData extends AbstractInfrNode

@export var fork: RailNodeForkData
@export var station: NodeStationLinkData

static func of(_index: int, _pos: Vector3, _track: RailTrackData) -> RailNodeData:
	var instance := RailNodeData.new()
	instance.parent_track = _track
	instance.index = _index
	instance.position = _pos
	return instance
