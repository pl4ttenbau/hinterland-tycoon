class_name WorldScene extends Node3D

func _ready() -> void:
	SignalBus.scene_ready.emit(self)
