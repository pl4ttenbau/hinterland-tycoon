class_name VehicleSpeed extends RefCounted

const SPEED_CHANGE: float = .005

signal changed(value: float)

@export_storage var current: float = 0.0:
	set(value):
		current = value
		self.changed.emit(value)
	get():
		return current

@export_storage var target: float 

func adjust_to_target_speed():
	var speed_diff := self.target - self.current
	if speed_diff > 0:
		self.current += SPEED_CHANGE
	elif speed_diff < 0:
		self.current -= SPEED_CHANGE
