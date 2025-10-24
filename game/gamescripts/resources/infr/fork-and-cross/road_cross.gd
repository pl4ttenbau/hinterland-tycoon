class_name RoadCross extends Resource

@export var connecting_roads: Array[int] = []

@export var parent_node: RoadNode:
	set(value):
		parent_node = value
		value.cross = self
	get(): return parent_node

static func of(_node: RoadNode, _connected_roads: Array[int]):
	var inst := RoadCross.new()
	# 2 way link with parent node
	inst.parent_node = _node
	# connecting roads
	inst.connecting_roads = _connected_roads
	return inst
