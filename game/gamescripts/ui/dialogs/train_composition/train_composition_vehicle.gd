## A row sends its reorder or remove request to the shared draft.
class_name TrainCompositionVehicleRow extends Control

@export var train_veh: TrainVehicleDto
@export var parent_list: TrainVehicleListDto


func _ready() -> void:
	if train_veh == null or parent_list == null:
		return
	%VehicleTypeText.text = train_veh.veh_type_obj.display_name
	%BtnUp.pressed.connect(_on_move_up)
	%BtnDown.pressed.connect(_on_move_down)
	%BtnRemove.pressed.connect(_on_remove)


func _on_move_up() -> void:
	parent_list.move_up(parent_list.rows.find(train_veh))


func _on_move_down() -> void:
	parent_list.move_down(parent_list.rows.find(train_veh))


func _on_remove() -> void:
	parent_list.remove(parent_list.rows.find(train_veh))
