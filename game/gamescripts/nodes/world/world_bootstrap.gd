class_name WorldBootstrap extends Node3D

signal scene_root_ready()

func _ready() -> void:
	self.scene_root_ready.emit()
	SignalBus.scene_root_ready.emit()

func find_world_map() -> WorldMapScene:
	return SearchObjectByType.find_node_by_type(WorldMapScene, true)
