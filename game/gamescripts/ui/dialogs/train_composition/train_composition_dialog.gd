## Builds a train composition and submits it to the depot for purchase.
@warning_ignore("missing_tool")
class_name TrainCompositionDialog extends ModalGameDialog

const VEHICLE_ROW_SCENE_PATH = "res://scenes/ui/dialogs/train_composition/vehicle_row.tscn"

@export var vehicle_rows: TrainVehicleListDto = TrainVehicleListDto.new()

var purchase: Callable
var _selected_vehicle_type: String


func _ready() -> void:
	dialog_key = "ComposeTrainDialog"
	%AddVehicleButton.pressed.connect(_on_add_vehicle_pressed)
	%SpawnTrainButton.pressed.connect(_on_spawn_pressed)
	%AddableVehiclesList.selection_changed.connect(_on_vehicle_selected)
	vehicle_rows.updated.connect(_rebuild_rows)
	_rebuild_rows()


## The heading is part of the scene. Only the rows are generated from the draft.
func _rebuild_rows() -> void:
	var price: int = vehicle_rows.purchase_price()
	%SpawnTrainButton.disabled = price < 0
	%SpawnTrainButton.text = "Buy train · %s" % CompanyData.format_cash(price) if price >= 0 else "Buy train"
	%PurchaseError.hide()
	for child: Node in %TrainVehicleList.get_children():
		if child is TrainCompositionVehicleRow:
			child.queue_free()
	var row_scene := load(VEHICLE_ROW_SCENE_PATH) as PackedScene
	for train_veh: TrainVehicleDto in vehicle_rows.rows:
		var row := row_scene.instantiate() as TrainCompositionVehicleRow
		row.train_veh = train_veh
		row.parent_list = vehicle_rows
		%TrainVehicleList.add_child(row)


func _on_vehicle_selected(vehicle_type: String) -> void:
	_selected_vehicle_type = vehicle_type


func _on_add_vehicle_pressed() -> void:
	if not _selected_vehicle_type.is_empty():
		vehicle_rows.append(TrainVehicleDto.of(vehicle_rows.rows.size(), _selected_vehicle_type))


func _on_spawn_pressed() -> void:
	if _closing or not purchase.is_valid():
		return
	var error: String = purchase.call(vehicle_rows)
	if not error.is_empty():
		%PurchaseError.text = error
		%PurchaseError.show()
		return
	diag_result = vehicle_rows
	close_all()
