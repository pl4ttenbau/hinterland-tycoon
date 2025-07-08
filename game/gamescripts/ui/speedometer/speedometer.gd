class_name SpeedometerControl extends Control

const LINE_ROTATION_ZERO := -35.0
const LINE_ROTATION_MAX := 35.0

@export_storage var current_vehicle: RailVehicle

@export_storage var current_speed: float = 0.0:
	set(value):
		current_speed = value
		self.adjust_speedometer()
	get():
		return current_speed

func _enter_tree() -> void:
	self.visible = false
	# connect to vehicle signals
	SignalBus.vehicle_entered.connect(Callable(self, "_vehicle_entered"))
	SignalBus.vehicle_exited.connect(Callable(self, "_vehicle_exited"))
	
func adjust_speedometer():
	var angle: float = self.current_speed * self.get_angle_range() + LINE_ROTATION_ZERO
	self.get_speed_line().rotation_degrees = angle
	
#region Vehicle Callbacks
func _vehicle_entered(vehicle: RailVehicle):
	# set current vehicle & speed
	self.current_vehicle = vehicle
	self.current_speed = self.current_vehicle.motor.current_speed_percentage
	# connect to motor speed sifnal
	vehicle.motor.speed.changed.connect(Callable(self, "_on_motor_speed_changed"))
	# and show control
	self.visible = true
	
func _vehicle_exited():
	# disconnect signals
	self.current_vehicle.motor.speed.changed.disconnect(Callable(self, "_on_motor_speed_changed"))
	# clear current speed & vehicle & hide
	self.current_vehicle = null
	self.current_speed = 0.0
	self.visible = false
	
func _on_motor_speed_changed(speed: float):
	self.current_speed = speed
#endregion
	
#region Getters
func get_speed_line() -> Line2D:
	return $SpeedLine
	
func get_angle_range() -> float:
	return absf(LINE_ROTATION_ZERO) + absf(LINE_ROTATION_MAX)
#endregion
