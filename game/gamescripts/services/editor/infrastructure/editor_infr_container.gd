@tool
@icon("res://assets/icons/nodes_3d/icon_data.svg")
## EditorInfr: groups the map's reference infrastructure in the EditorObjects scene, with an EditorRails
## (GeneratedRailLines) and an EditorRoads (GeneratedRoadWays) child. Loading and saving happen on the
## EditorObjects root and the lines themselves; this node only keeps the layout and hides itself in game.
class_name GeneratedInfrContainer extends Node3D

func _ready() -> void:
	## Authoring geometry only. In game the map's real tracks and roads are spawned from JSON instead.
	if not Engine.is_editor_hint():
		self.visible = false

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not get_node_or_null("EditorRails") is GeneratedRailLines:
		warnings.append("EditorRails (GeneratedRailLines) child node missing")
	if not get_node_or_null("EditorRoads") is GeneratedRoadWays:
		warnings.append("EditorRoads (GeneratedRoadWays) child node missing")
	return warnings
