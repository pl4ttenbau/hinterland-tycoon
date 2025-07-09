class_name VehicleSpeed extends RefCounted

<<<<<<< Updated upstream
=======
enum EnumDirection { FORWADS, BACKWARDS }

>>>>>>> Stashed changes
signal changed(value: float)

@export_storage var current: float = 0.0:
	set(value):
		current = value
		self.changed.emit(value)
	get():
		return current

@export_storage var target: float 

@export_storage var direction: EnumDirection = EnumDirection.FORWADS

func adjust_to_target_speed():
	var speed_diff := self.target - self.current
	if speed_diff > 0:
		self.current += .01
	elif self.current < 0:
		self.current -= 0.01
