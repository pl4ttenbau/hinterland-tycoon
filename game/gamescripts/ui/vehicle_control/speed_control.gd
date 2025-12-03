class_name SpeedControl extends Control

@export var curr_vehicle: RailVehicle3D

func _enter_tree() -> void:
	self.gui_input.connect(Callable(self, "_on_gui_input"))
	# vehicle signals
	SignalBus.vehicle_entered.connect(Callable(self, "_on_vehicle_entered"))
	SignalBus.vehicle_exited.connect(Callable(self, "_on_vehicle_exited"))

func set_vehicle_speed(speed_percent: float):
	if ! self.curr_vehicle:
		Loggie.warn("Cannot set vehicle speed: is not sitting inside anything")
		return
	var speed_float: float = 1 - (speed_percent / 100)
	Loggie.info("Setting vehicle speed perc: %f" % speed_float)
	self.curr_vehicle.motor.speed.target = speed_float
	# set handle pos
	$ControlHandle.position.y = speed_percent

#region Callables
func _on_gui_input(ev: InputEvent):
	if ev is InputEventMouseButton && ev.pressed == true && ev.button_index == MOUSE_BUTTON_LEFT:
		var speed_perc = ev.position.y
		self.set_vehicle_speed(speed_perc)

func _on_vehicle_entered(veh3d: RailVehicle3D):
	self.curr_vehicle = veh3d
	
func _on_vehicle_exited():
	self.curr_vehicle = null
#endregion
