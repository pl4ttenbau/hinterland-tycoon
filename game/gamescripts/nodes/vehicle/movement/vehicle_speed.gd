class_name VehicleSpeed extends RefCounted

signal changed(value: float)
signal target_changed(value: float)
signal brake_changed(applied: bool)

## Overrides traction without discarding the driver's selected target speed.
@export_storage var brake_applied: bool = false:
	set(value):
		if brake_applied == value:
			return
		brake_applied = value
		self.brake_changed.emit(value)

@export_storage var current: float = 0.0:
	set(value):
		current = value
		self.changed.emit(value)
	get():
		return current

## Normalized selected speed; a newly created train initially requests full speed.
@export_storage var target: float = 1.0:
	set(value):
		target = value
		self.target_changed.emit(value)
	get(): return target
