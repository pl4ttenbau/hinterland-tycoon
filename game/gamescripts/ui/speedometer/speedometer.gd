class_name SpeedometerControl extends Control

const LINE_ROTATION_ZERO := -35.0
const LINE_ROTATION_MAX := 35.0

@export_storage var current_vehicle: RailVehicle

@export_storage var current_speed: float = 0.0:
	set(value):
		current_speed = value
		self.adjust_speedometer()

func _enter_tree() -> void:
	self.visible = false
	# connect to vehicle signals
	SignalBus.vehicle_entered.connect(Callable(self, "_vehicle_entered"))
	SignalBus.vehicle_exited.connect(Callable(self, "_vehicle_exited"))

func _ready() -> void:
	pass # Replace with function body.

func _process(delta: float) -> void:
	if self.visible && self.current_vehicle:
		self.current_speed = self.current_vehicle.motor.current_speed_percentage
	
func adjust_speedometer():
	var angle: float = self.current_speed * self.get_angle_range() + LINE_ROTATION_ZERO
	self.get_speed_line().rotation_degrees = angle
	
#region Vehicle Callbacks
func _vehicle_entered(vehicle: RailVehicle):
	self.current_vehicle = vehicle
	self.visible = true
	
func _vehicle_exited():
	self.current_vehicle = null
	self.current_speed = 0.0
	self.visible = false
#endregion
	
#region Getters
func get_speed_line() -> Line2D:
	return $SpeedLine
	
func get_angle_range() -> float:
	return absf(LINE_ROTATION_ZERO) + absf(LINE_ROTATION_MAX)
#endregion
