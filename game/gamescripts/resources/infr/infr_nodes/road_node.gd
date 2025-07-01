class_name RoadNode extends BasicInfrNodeData

@export_storage var parent_track: RoadData
# @export var specialNode: RailNodeSpecial

static func of(_index: int, _pos: Vector3, _road_obj: RoadData) -> RoadNode:
	var instance: RoadNode = RoadNode.new()
	instance.parent_track = _road_obj
	instance.index = _index
	instance.position = _pos
	return instance
