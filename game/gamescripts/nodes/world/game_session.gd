@icon("res://assets/icons/icon_game_session.svg")
class_name GameSession extends Node3D

signal scene_root_ready()

func _ready() -> void:
	self.scene_root_ready.emit()
	SignalBus.scene_root_ready.emit()
