class_name EmptyWorldContainer extends Node3D

func _ready() -> void:
	SignalBus.scene_ready.emit(self)
