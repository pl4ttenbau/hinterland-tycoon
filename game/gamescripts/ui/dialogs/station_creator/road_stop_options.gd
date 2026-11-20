## Which side of the road gets a shelter.
class_name RoadStopOptions extends VBoxContainer

signal direction_changed(direction: Enums.RoadStopDirection)

@onready var _side: OptionButton = %RoadSide

func _ready() -> void:
	_side.item_selected.connect(_on_road_side_item_selected)

## The visible labels are player-relative. The item IDs still go straight to
## the builder and the road router as stable directions along the road.
func setup(right_direction: int, direction: int) -> void:
	var increasing := Enums.RoadStopDirection.ROAD_NODES_INCREASE
	var decreasing := Enums.RoadStopDirection.ROAD_NODES_DECREASE
	var left: int = decreasing if right_direction == increasing else increasing
	_side.add_item("Left", left)
	_side.add_item("Right", right_direction)
	_side.add_item("Both sides", Enums.RoadStopDirection.BOTH_DIRECTIONS)
	_side.select(_side.get_item_index(direction))

func direction() -> Enums.RoadStopDirection:
	return _side.get_selected_id() as Enums.RoadStopDirection

func focus() -> void:
	_side.grab_focus()

func _on_road_side_item_selected(_index: int) -> void:
	direction_changed.emit(direction())
