class_name RoadCross extends Resource

@export var connecting_roads: Array[int] = []

## Held weakly: the node owns its cross (node.cross), so a strong back-reference
## would form a cycle and leak both. Not exported, the mapper sets it.
var parent_node: RoadNode:
	set(value):
		_parent_node = weakref(value) if value != null else null
		if value != null:
			value.cross = self
	get():
		return _parent_node.get_ref() if _parent_node != null else null
var _parent_node: WeakRef = null

static func of(_node: RoadNode, _connected_roads: Array[int]):
	var inst := RoadCross.new()
	# 2 way link with parent node
	inst.parent_node = _node
	# connecting roads
	inst.connecting_roads = _connected_roads
	return inst
