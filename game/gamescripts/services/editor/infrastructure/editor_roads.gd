@icon("res://assets/icons/nodes_3d/icon_road.svg")
@tool
## EditorRoads: holds the map's saved roads as reference lines (EditorInfrLine3D), one per record in
## world/<map>/jsondata/roads.json.
##
## A marker class only, like GeneratedRailLines: "Load Roads JSON" on the EditorObjects root fills it
## (WorldEditorObjects → InfrJsonStore.load_world), and InfrJsonStore.reference_container_for finds it.
## Older scenes still hold their roads in "0__49"-style group nodes from the former generator; loading
## the JSON again replaces those with a flat list.
class_name GeneratedRoadWays extends Node3D
