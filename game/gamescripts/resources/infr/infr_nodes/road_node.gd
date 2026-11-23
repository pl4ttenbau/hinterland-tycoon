@icon("icon_infr_node_white")
class_name RoadNode extends AbstractInfrNode

@export var cross: RoadCross

static func of(_index: int, _pos: Vector3, _road_obj: RoadData) -> RoadNode:
	var instance: RoadNode = RoadNode.new()
	instance.parent_line = _road_obj
	instance.index = _index
	instance.position = _pos
	return instance
