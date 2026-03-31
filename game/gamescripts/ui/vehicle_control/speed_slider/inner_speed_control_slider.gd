@icon("res://assets/icons/icon_speedometer_ui.png")
class_name SpeedControl extends Control

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

func _enter_tree() -> void:
	self.gui_input.connect(Callable(self, "_on_gui_input"))
	# vehicle signals
	SignalBus.train_entered.connect(Callable(self, "_on_train_entered"))
	SignalBus.train_exited.connect(Callable(self, "_on_train_exited"))

func set_vehicle_speed(speed_percent: float):
	var speed_float := self._clamp_speed(1 - (speed_percent / 100))
	Loggie.info("Setting vehicle speed perc: %f" % speed_float)
	self.curr_speed.target = speed_float
	
func _set_handle_position(speed_float: float):
	# set handle pos
	$ControlHandle.position.y = 111 - (111 * speed_float)
	
func _clamp_speed(input_f: float) -> float:
	if input_f > 1: return 1
	elif input_f < 0: return 0
	return input_f

#region Callables
func _on_gui_input(ev: InputEvent):
	if ev is InputEventMouseButton && ev.pressed == true && ev.button_index == MOUSE_BUTTON_LEFT:
		var speed_perc = ev.position.y
		self.set_vehicle_speed(speed_perc)

func _on_train_entered(veh3d: Train3D):
	self.curr_train = veh3d
	self.curr_speed.target_changed.connect(Callable(self, "_on_target_speed_changed"))
	
func _on_train_exited():
	self.curr_speed.target_changed.disconnect(Callable(self, "_on_target_speed_changed"))
	self.curr_train = null
	
func _on_target_speed_changed(target_speed_perc: float):
	self._set_handle_position(target_speed_perc)
#endregion
