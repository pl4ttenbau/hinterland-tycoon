@tool
@icon("res://assets/icons/nodes_3d/icon_industry.svg")
class_name IndustryPlaceholder extends Marker3D

@export var num: int
@export var type_key: String:
	set(value):
		type_key = value
		_notify_supply_checker()
@export var ind_name: String:
	set(value):
		ind_name = value
		_notify_supply_checker()

func _init() -> void:
	self.gizmo_extents = 10.0

## Inspector edits and undo/redo use these setters. Let the map container defer
## and combine refreshes instead of rebuilding warnings during property changes.
func _notify_supply_checker() -> void:
	if Engine.is_editor_hint() and get_parent() is WorldIndustries:
		(get_parent() as WorldIndustries).refresh_supply_warnings()
