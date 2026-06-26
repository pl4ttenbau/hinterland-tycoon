@tool
class_name VehicleDrivingParticles extends Node3D

signal effect_strength_changed(val: float)

@export_range(0, 1, 0.025) var effect_strength: float:
	set(value):
		self.effect_strength_changed.emit(value)
		effect_strength = value

@export var child_particles: Array[GPUParticles3D]

@export var locomotive: Vehicle3D

func _ready() -> void:
	var signal_callable: Callable = Callable(self, "_on_effect_strength_changed")
	if !self.effect_strength_changed.is_connected(signal_callable):
		self.effect_strength_changed.connect(signal_callable)
	if !Engine.is_editor_hint():
		if self.locomotive:
			var train_motor: TrainMotor = self.locomotive.train3d.motor
			var motor_speed_callable: Callable = Callable(self, "_on_motor_current_speed_changed")
			if !train_motor.speed.changed.is_connected(motor_speed_callable):
				train_motor.speed.changed.connect(motor_speed_callable)

#region Callbacks
func _on_effect_strength_changed(_val: float):
	for child_particle: Node in self.child_particles:
		if child_particle is GPUParticles3D:
			child_particle.amount_ratio = _val

func _on_motor_current_speed_changed(motor_speed: float):
	self.effect_strength = motor_speed
#endregion
