@icon("res://assets/icons/nodes_3d/icon_house.svg")
class_name StationBuilding3D extends Node3D

@export var rail_stop_3d: RailStop3D

## Called before the station enters the tree. Its sign and catchment are siblings.
func hide_building() -> void:
	hide()
	for shape: CollisionShape3D in find_children("*", "CollisionShape3D", true, false):
		shape.disabled = true
