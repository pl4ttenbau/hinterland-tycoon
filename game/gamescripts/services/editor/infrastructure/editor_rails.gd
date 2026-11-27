@icon("res://assets/icons/nodes_3d/icon_rail_track.svg")
@tool
## EditorRails: holds the map's saved rail tracks as reference lines (EditorInfrLine3D), one per record
## in world/<map>/jsondata/tracks.json.
##
## A marker class only. The lines are put here by "Load Rails JSON" on the EditorObjects root
## (WorldEditorObjects → InfrJsonStore.load_world), which replaces them with an undoable action, and
## found again through this type (InfrJsonStore.reference_container_for). A full save never writes them
## back; a single line can be written with its "Save Single" button.
class_name GeneratedRailLines extends Node3D
