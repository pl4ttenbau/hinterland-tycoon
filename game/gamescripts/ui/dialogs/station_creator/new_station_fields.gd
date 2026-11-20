## Name and town for a brand-new interchange.
class_name NewStationFields extends VBoxContainer

signal submitted()

@onready var _name: LineEdit = %StationName
@onready var _town: OptionButton = %StationTown

func _ready() -> void:
	_name.text_submitted.connect(_on_station_name_submitted)

## Suggests a name and preselects the town nearest to the placement.
func setup(default_name: String, origin: Vector3) -> void:
	_name.text = default_name
	var nearest_distance: float = INF
	var position: Vector2 = Vector2(origin.x, origin.z)
	for town: TownData in GlobalState.towns:
		_town.add_item(town.town_name, town.num)
		var distance: float = position.distance_squared_to(town.pos_xz)
		if distance < nearest_distance:
			nearest_distance = distance
			_town.select(_town.item_count - 1)

func has_towns() -> bool:
	return _town.item_count > 0

func station_name() -> String:
	return _name.text

## -1 when no town is selected.
func town_num() -> int:
	return _town.get_selected_id() if _town.selected >= 0 else -1

func focus() -> void:
	_name.grab_focus()
	_name.select_all()

func _on_station_name_submitted(_text: String) -> void:
	submitted.emit()
