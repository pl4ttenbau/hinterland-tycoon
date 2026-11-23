## One shape node of a rail track or road; never used directly.
@abstract
class_name AbstractInfrNode extends Resource

@export var index: int

## World position. Rail and road curves both use world coordinates.
@export var position: Vector3

@export var handle_in: Vector3
@export var handle_out: Vector3

## Authored dead end, e.g. where a rail buffer stands.
@export var is_end: bool = false

## Held weakly: the line owns its nodes, so a strong back-reference would form
## a cycle and leak both. Not exported, the loader sets it.
var parent_line: AbstractInfrLine:
	set(value):
		_parent_line = weakref(value) if value != null else null
	get():
		return _parent_line.get_ref() if _parent_line != null else null
var _parent_line: WeakRef = null

#region Neighbours
func get_previous() -> AbstractInfrNode:
	if self.parent_line == null or self.index <= 0:
		return null
	return self.parent_line.get_node_at(self.index - 1)

func get_next() -> AbstractInfrNode:
	if self.parent_line == null or self.index < 0:
		return null
	return self.parent_line.get_node_at(self.index + 1)

func is_first() -> bool:
	return self.index == 0

func is_last() -> bool:
	return self.parent_line != null and self.index == self.parent_line.node_count() - 1
#endregion

## Distance along the parent curve, in metres.
func offset() -> float:
	return self.parent_line.node_offset(self.index)
