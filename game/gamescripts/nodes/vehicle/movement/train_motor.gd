@icon("uid://1bbvrckmpv38")
class_name TrainMotor extends Node

const MAX_ABS_SPEED: float = .12

signal started()
signal stopped()
signal reversing()

#region Properties
@export_storage var speed: VehicleSpeed

@export var current_speed_percentage: float = 0.0:
	set(value): self.speed.current = value
	get(): return self.speed.current

@export var is_started: bool = false

@export var is_reversed: bool = false:
	get(): return is_reversed
	set(value):
		is_reversed = value
		self.reversing.emit()

@export var running_time: int:
	get():
		if self.is_started && self.running_msec >= 0:
			return Time.get_ticks_msec() - self.running_msec
		return -1

@export var direction: Enums.PathDirection

## engine ticks since this motor was started
@export var running_msec: int = -1
#endregion

#region Initialization
static func of(_dir: Enums.PathDirection) -> TrainMotor:
	var _inst = TrainMotor.new()
	_inst.direction = _dir
	_inst.speed = VehicleSpeed.new()
	return _inst
#endregion

#region Start & Stop
func start() -> bool:
	self.is_started = true
	self.started.emit()
	self.speed.target = 1.0
	# count ticks since start
	self.running_msec = Time.get_ticks_msec()
	return true

func stop() -> void:
	self.is_started = false
	self.current_speed_percentage = 0.0
	self.stopped.emit()
	# also stop tick counting
	self.running_msec = -1
#endregion

#region Callbacks
func on_motor_tick():
	if self.speed:
		self.speed.adjust_to_target_speed()
#endregion

#region Getters
func get_current_speed() -> float:
	return current_speed_percentage * MAX_ABS_SPEED
#endregion
