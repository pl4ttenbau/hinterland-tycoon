class_name VehicleMotor extends Node

#region Properties
@export var max_speed: float = .7

@export_storage var speed: VehicleSpeed

@export var current_speed_percentage: float = 0.0:
	set(value):
		self.speed.current = value
	get(): return self.speed.current

@export var is_started: bool = false

@export var running_time: int:
	get():
		if self.is_started && self.started_at >= 0:
			return Time.get_ticks_msec() - self.started_at
		return -1

## engine ticks since this motor was started
@export var started_at: int = -1

signal started()
signal stopped()
signal speed_changed(percentage: float)
#endregion

static func of(_vehicle: RailVehicle) -> VehicleMotor:
	var _inst = VehicleMotor.new()
	_inst.speed = VehicleSpeed.new()
	return _inst
	
func _physics_process(delta: float) -> void:
	Time.get_ticks_msec()

func start() -> bool:
	self.is_started = true
	self.started.emit()
	self.speed.target = 1.0
	# count ticks since start
	self.started_at = Time.get_ticks_msec()
	return true
	
func stop() -> void:
	self.is_started = false
	self.current_speed_percentage = 0.0
	self.stopped.emit()
	# also stop tick counting
	self.started_at = -1
	
func on_motor_tick():
	if self.speed:
		self.speed.adjust_to_target_speed()
		
func set_on_connected_track(end_node: RailNodeData):
	if end_node.fork && end_node.fork.setTo:
		var next_track_num = end_node.fork.setTo
		Loggie.info("Switching to track with num %d" % next_track_num)

#region Getters
func get_current_speed() -> float:
	return current_speed_percentage * max_speed
	
func get_speed_vector() -> Vector3:
	return Vector3(0, 0, -self.get_current_speed())
#endregion
