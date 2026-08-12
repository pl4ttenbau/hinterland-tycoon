@tool
class_name HinterlandEditorStateData extends Node

signal world_opening(world: WorldMapScene)
signal world_opened(world: WorldMapScene)

@export var open_world_key: String

@export var world_scene: WorldMapScene

@export var terrain3d: Terrain3D

@export var open_world: WorldMapScene:
	set(value):
		open_world = value
		self.world_opening.emit(value)
