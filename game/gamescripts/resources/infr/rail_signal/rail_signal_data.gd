## A block signal at a distance along one rail track. It protects one or both directions of travel.
class_name RailSignalData extends Resource

enum Facing { NODES_INCREASE, NODES_DECREASE, BOTH }

@export var num: int
@export var signal_name: String
@export var track_num: int
## Distance along the track curve, measured from the track's first node.
@export var offset: float
@export var facing: Facing = Facing.NODES_INCREASE

## Whether a train travelling in `direction` along the track has to obey this signal.
func protects(direction: Enums.PathDirection) -> bool:
	match self.facing:
		Facing.BOTH:
			return direction != Enums.PathDirection.STOP
		Facing.NODES_INCREASE:
			return direction == Enums.PathDirection.TRACK_NODES_INCREASE
		_:
			return direction == Enums.PathDirection.TRACK_NODES_DECREASE

## The directions of travel this signal shows an aspect for.
func get_directions() -> Array[Enums.PathDirection]:
	var directions: Array[Enums.PathDirection] = []
	for direction: Enums.PathDirection in [Enums.PathDirection.TRACK_NODES_INCREASE, Enums.PathDirection.TRACK_NODES_DECREASE]:
		if self.protects(direction):
			directions.append(direction)
	return directions
