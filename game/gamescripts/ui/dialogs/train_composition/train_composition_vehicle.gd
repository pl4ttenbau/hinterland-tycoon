class_name TrainCompositionVehicleRow extends Control

@export var train_veh: TrainVehicleDto:
	get(): return train_veh
	set(value):
		train_veh = value
		%VehicleTypeText.text = value.veh_type_obj.display_name
		
@export var parent_list: TrainVehicleListDto

func _ready() -> void:
	%BtnUp.pressed.connect(Callable(self, "_on_btn_up_pressed"))
	%BtnDown.pressed.connect(Callable(self, "_on_btn_down_pressed"))
	%BtnRemove.pressed.connect(Callable(self, "on_btn_remove_pressed"))

#region Callbacks
func _on_btn_up_pressed():
	self.veh_list.move_up(self.index)

func _on_btn_down_pressed():
	self.veh_list.move_down(self.index)

func on_btn_remove_pressed():
	self.veh_list.remove(self.index)
#endregion
