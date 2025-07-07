class_name VehicleMotor extends Node

@export var max_speed: float = .7

@export var current_speed_percentage = 0:
	set(value):
		current_speed_percentage = value
		self.speed_changed.emit(value)

@export var is_started: bool = false

signal started()
signal stopped()
signal speed_changed(percentage: float)

static func of(_vehicle: RailVehicle) -> VehicleMotor:
	var _inst = VehicleMotor.new()
	return _inst

func get_current_speed() -> float:
	return current_speed_percentage * max_speed
	
func get_speed_vector() -> Vector3:
	return Vector3(0, 0, -self.get_current_speed())

func start() -> bool:
	self.is_started = true
	self.current_speed_percentage = 1.0
	self.started.emit()
	return true
	
func stop() -> void:
	self.is_started = false
	self.current_speed_percentage = 0.0
	self.stopped.emit()
