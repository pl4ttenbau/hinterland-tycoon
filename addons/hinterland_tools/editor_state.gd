@tool
class_name HinterlandEditorStateData extends Node

signal world_opening(world: WorldMapScene)
signal world_opened(world: WorldMapScene)

static var instance: HinterlandEditorStateData

@export var open_world_key: String

@export var world_scene: WorldMapScene

@export var terrain3d: Terrain3D

@export var open_world: WorldMapScene:
	set(value):
		open_world = value
		self.world_opening.emit(value)

func _enter_tree() -> void:
	if !HinterlandEditorStateData.instance && Engine.is_editor_hint():
		HinterlandEditorStateData.instance = self
