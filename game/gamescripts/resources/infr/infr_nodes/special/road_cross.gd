class_name RoadCross extends Resource

@export var connecting_roads: Array[int]
@export var parent_node: RoadNode

func _init(_node: RoadNode, _connected_roads: Array[int]):
	self.parent_node = _node
	self.connecting_roads = _connected_roads
