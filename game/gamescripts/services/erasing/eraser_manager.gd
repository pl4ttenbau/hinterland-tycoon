## Session entry point for world erasure. The network loaders own the mutations.
class_name EraserManager extends Node

enum Operation { SEGMENT, SPAN, NODE, JUNCTION }

signal erase_requested(target: AbstractInfrLine, operation: Operation, from_index: int, to_index: int)
signal erase_finished(target: AbstractInfrLine, operation: Operation, result: Error)

var rails: RailsLoader
var roads: RoadsLoader


func _ready() -> void:
	erase_requested.connect(erase)


## SEGMENT takes its start index. SPAN takes both ends. NODE and JUNCTION take
## the selected node index. Callers can use the result or listen for completion.
func erase(target: AbstractInfrLine, operation: Operation, from_index: int, to_index: int = -1) -> Error:
	var result: Error = ERR_INVALID_PARAMETER
	if target is RailTrackData and is_instance_valid(rails):
		match operation:
			Operation.SEGMENT: result = rails.erase_segment(target, from_index)
			Operation.SPAN: result = rails.erase_span(target, from_index, to_index)
			Operation.NODE: result = rails.erase_node(target, from_index)
			Operation.JUNCTION: result = rails.erase_fork(target, from_index)
	elif target is RoadData and is_instance_valid(roads):
		match operation:
			Operation.SEGMENT: result = roads.erase_segment(target, from_index)
			Operation.SPAN: result = roads.erase_span(target, from_index, to_index)
			Operation.NODE: result = roads.erase_node(target, from_index)
			Operation.JUNCTION: result = roads.erase_cross(target, from_index)
	erase_finished.emit(target, operation, result)
	return result
