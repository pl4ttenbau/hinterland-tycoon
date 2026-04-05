@icon("res://assets/icons/icon_speedometer_ui.png")
class_name OuterSpeedControlSlider extends CenterContainer

@export var curr_train: Train3D:
	get():
		if !curr_train:
			Loggie.warn("Cannot set vehicle speed: is not sitting inside anything")
		return curr_train
	set(value):
		curr_train = value
		
@export_storage var curr_speed: VehicleSpeed:
	get():
		return self.curr_train.motor.speed

func _ready() -> void:
	%VSlider.drag_ended.connect(Callable(self, "_on_drag_ended"))
		# vehicle signals
	SignalBus.train_entered.connect(Callable(self, "_on_train_entered"))
	SignalBus.train_exited.connect(Callable(self, "_on_train_exited"))

#region Callbacks
func _on_drag_ended(val_changed: bool):
	if val_changed:
		var target_speed_perc: float = %VSlider.value
		self.curr_speed.target = target_speed_perc
	
func _on_train_entered(veh3d: Train3D):
	self.curr_train = veh3d
	self.curr_speed.target_changed.connect(Callable(self, "_on_target_speed_changed"))
	
func _on_train_exited():
	self.curr_speed.target_changed.disconnect(Callable(self, "_on_target_speed_changed"))
	self.curr_train = null
#endregion
