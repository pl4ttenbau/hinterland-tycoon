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

@export var parent_track: AbstractTrack

#region Neighbours
func get_previous() -> AbstractInfrNode:
	if self.parent_track == null or self.index <= 0:
		return null
	return self.parent_track.get_node_at(self.index - 1)

func get_next() -> AbstractInfrNode:
	if self.parent_track == null or self.index < 0:
		return null
	return self.parent_track.get_node_at(self.index + 1)

func is_first() -> bool:
	return self.index == 0

func is_last() -> bool:
	return self.parent_track != null and self.index == self.parent_track.node_count() - 1
#endregion

## Distance along the parent curve, in metres.
func offset() -> float:
	return self.parent_track.node_offset(self.index)
