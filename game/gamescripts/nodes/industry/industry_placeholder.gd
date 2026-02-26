@tool
@icon("res://assets/icons/icon_industry.png")
class_name IndustryPlaceholder extends Marker3D

@export var num: int
@export var type_key: String
@export var ind_name: String

func _init() -> void:
	self.gizmo_extents = 10.0
