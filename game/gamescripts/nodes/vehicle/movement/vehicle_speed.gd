class_name VehicleSpeed extends RefCounted

const SPEED_CHANGE_PER_TICK: float = .005
## Service brake: twice the normal slowdown rate, still applied over time.
const BRAKE_RATE_MULTIPLIER: float = 2.0

var _ramp_start: float = 0.0
var _ramp_target: float = INF
var _ramp_progress: float = 0.0
var _last_adjusted_speed: float = INF

signal changed(value: float)
signal target_changed(value: float)
signal brake_changed(applied: bool)

## Overrides traction without discarding the driver's selected target speed.
@export_storage var brake_applied: bool = false:
	set(value):
		if brake_applied == value:
			return
		brake_applied = value
		self._ramp_target = INF
		self.brake_changed.emit(value)

@export_storage var current: float = 0.0:
	set(value):
		current = value
		self.changed.emit(value)
	get():
		return current

@export_storage var target: float:
	set(value):
		target = value
		self.target_changed.emit(value)
	get(): return target

func adjust_to_target_speed():
	var effective_target: float = 0.0 if brake_applied else self.target
	if self.current == effective_target:
		return
	# Retarget from the actual speed, including after an external speed change.
	if effective_target != _ramp_target or self.current != _last_adjusted_speed:
		self._ramp_start = self.current
		self._ramp_target = effective_target
		self._ramp_progress = 0.0
	# Keep the former travel time, but interpolate speed quadratically in time.
	var distance := absf(_ramp_target - _ramp_start)
	var rate: float = SPEED_CHANGE_PER_TICK * (BRAKE_RATE_MULTIPLIER if brake_applied else 1.0)
	self._ramp_progress = minf(1.0, _ramp_progress + rate / distance)
	self.current = lerpf(_ramp_start, _ramp_target, _ramp_progress * _ramp_progress)
	self._last_adjusted_speed = self.current
