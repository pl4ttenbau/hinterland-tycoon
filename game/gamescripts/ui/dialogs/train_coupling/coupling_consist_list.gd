## The selected consist, front to rear, with an optional split marker.
class_name CouplingConsistList extends VBoxContainer

signal vehicle_selected(vehicle: Vehicle3D)

var _displayed: Array[Vehicle3D] = []
var _displayed_cut: int = -1

@onready var heading: Label = %Heading
@onready var list: ItemList = %Vehicles

func _ready() -> void:
	list.item_selected.connect(_on_vehicles_item_selected)

## Rebuilds only when the consist or the split preview changed, so the
## periodic refresh does not reset scrolling.
func show_consist(train: Train3D, selected: Vehicle3D, cut: int) -> void:
	if _displayed == train.vehicles and _displayed_cut == cut:
		return
	_displayed = train.vehicles.duplicate()
	_displayed_cut = cut
	heading.text = "Selected consist  ·  %s" % TrainCouplingText.count(train.count())
	list.clear()
	for index: int in range(train.count()):
		if index == cut:
			var divider: int = list.add_item("──────── Split here ────────")
			list.set_item_selectable(divider, false)
		var vehicle: Vehicle3D = train.vehicles[index]
		var row: int = TrainCouplingText.add_vehicle_row(list, vehicle, _end_label(train, index))
		if vehicle == selected:
			list.select(row)
	list.ensure_current_is_visible.call_deferred()

func focus_list() -> void:
	list.grab_focus()

func _end_label(train: Train3D, index: int) -> String:
	if train.count() == 1:
		return "Front / rear"
	if index == 0:
		return "Front"
	if index == train.count() - 1:
		return "Rear"
	return ""

func _on_vehicles_item_selected(row: int) -> void:
	vehicle_selected.emit(list.get_item_metadata(row) as Vehicle3D)
