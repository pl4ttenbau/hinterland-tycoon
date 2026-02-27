@tool
@icon("res://assets/icons/icon_editor.png")
class_name EditorObjectContainer extends Node3D

@export var rails_parent: Node
@export var roads_parent: Node

const TRACK_PARENT_NODE_NAME = "EditorInfrRailTracks"
const ROAD_PARENT_NODE_NAME = "EditorInfrRoadWays"

#region Initializaion
func _ready():
	if ! Engine.is_editor_hint(): 
		self._ingame_ready()
	else: 
		self._editor_ready()

func _editor_ready():
	pass
	
func _ingame_ready():
	self.visible = false
#endregion

func _get_configuration_warnings() -> PackedStringArray:
	if !$EditorInfr:
		return ["EditorInfr (GeneratedInfrContainer) child node missing"]
	return []
