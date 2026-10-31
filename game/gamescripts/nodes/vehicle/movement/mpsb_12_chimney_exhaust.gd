@tool
extends "res://addons/steam_exhaust/steam_exhaust.gd"
## MPSB 12 bridge: sample world motion on the same physics tick as Train3D.
## The motor currently exposes target speed and brake state, not boiler pressure;
## these are used as an artistic estimate of exhaust effort.

@export var locomotive: Vehicle3D
@export_range(0.0, 1.0, 0.01) var idle_exhaust_strength: float = 0.4
@export_range(0.0, 1.0, 0.01) var cruise_load: float = 0.45

var _previous_physics_position: Vector3
var _motion_sample_ready: bool = false


func _ready() -> void:
	auto_velocity = false
	_previous_physics_position = global_position
	if not Engine.is_editor_hint():
		_update_motor_effort()
	super._ready()
	# Preserve the original MPSB 12 particle render layer (bit 7).
	_plume.layers = 64


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or delta <= 0.0:
		return
	var movement: Vector3 = global_position - _previous_physics_position
	_previous_physics_position = global_position
	if not _motion_sample_ready or movement.length() > teleport_distance:
		vehicle_velocity = Vector3.ZERO
		_motion_sample_ready = true
		reset_trail()
	else:
		vehicle_velocity = movement / delta
	_update_motor_effort()


func _update_motor_effort() -> void:
	engine_load = 0.0
	if is_instance_valid(locomotive) and is_instance_valid(locomotive.train3d):
		var train: Train3D = locomotive.train3d
		var train_motor: TrainMotor = train.motor
		if is_instance_valid(train_motor) and train_motor.is_started and not train.derailed:
			var speed: VehicleSpeed = train_motor.speed
			if speed != null:
				if speed.brake_applied or speed.target < speed.current - 0.005:
					engine_load = 0.05
				elif speed.target > speed.current + 0.005:
					engine_load = 0.9
				elif speed.current > 0.005:
					engine_load = cruise_load
	exhaust_strength = lerpf(idle_exhaust_strength, 1.0, engine_load)
