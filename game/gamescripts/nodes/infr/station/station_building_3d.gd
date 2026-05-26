@icon("res://assets/icons/icon_house_3d.png")
class_name StationBuilding3D extends Node3D

@export var node_link_3d: NodeStationLink3D

func hide_building():
	for any_child in self.get_children():
		if any_child is GeometryInstance3D:
			any_child.visible = false
		elif any_child is CollisionShape3D:
			any_child.disabled = true
