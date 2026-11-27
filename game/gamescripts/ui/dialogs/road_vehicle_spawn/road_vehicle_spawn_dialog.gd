## Road-only vehicle purchase at a depot. No itinerary is assigned.
class_name RoadVehicleSpawnDialog extends ConfirmDialog

const SCENE_PATH := "res://scenes/ui/dialogs/road_vehicle_spawn/road_vehicle_spawn_dialog.tscn"

var depot: RoadDepotData
var _types: Array[RoadVehicleTypeData] = []

@onready var _description: Label = %DepotDescription
@onready var _list: ItemList = %VehicleList
@onready var _preview: RoadVehicleTypePreview = %VehiclePreview
@onready var _spawn_button: Button = %OkButton

static func create(source_depot: RoadDepotData) -> RoadVehicleSpawnDialog:
	var dialog := (load(SCENE_PATH) as PackedScene).instantiate() as RoadVehicleSpawnDialog
	dialog.depot = source_depot
	return dialog

func _ready() -> void:
	# 1. Wiring. Buy vehicle (OK) is wired by ConfirmDialog.
	_list.item_selected.connect(_on_vehicle_selected)
	# 2. Content: the depot, then the road vehicle types with the first one selected.
	_description.text = "%s\nSpawn 10 m along the road, facing away from the depot." % depot.depot_name
	_populate_vehicles()

## The shared catalog also contains trains; only road types appear here.
func _populate_vehicles() -> void:
	if GameTypes.ensure_initialized() == OK:
		for type: VehicleTypeData in GameTypes.vehicle_types:
			if type is RoadVehicleTypeData:
				_types.append(type)
				_list.add_item(type.display_name)
	_spawn_button.disabled = _types.is_empty()
	if not _types.is_empty():
		_list.select(0)
		_on_vehicle_selected(0)
	_list.grab_focus()

func _on_vehicle_selected(index: int) -> void:
	_preview.show_type(_types[index])
	clear_status()

## Buys the selected type at the depot and closes with the new vehicle's number.
## Fails without spending when the company cannot pay or the spawn spot is taken.
func submit() -> String:
	var selected: PackedInt32Array = _list.get_selected_items()
	if selected.is_empty():
		return "Choose a vehicle."
	if not is_instance_valid(Managers.vehicles):
		return "Vehicle spawning is unavailable."
	var vehicle: RoadVehicle3D = Managers.vehicles.spawn_road_vehicle_at_depot(_types[selected[0]].key, depot)
	if vehicle == null:
		return Managers.vehicles.last_road_spawn_error
	close_with(vehicle.vehicle_obj.num)
	return ""
