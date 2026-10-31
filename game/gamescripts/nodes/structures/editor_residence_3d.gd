@tool
@icon("res://assets/icons/nodes_3d/icon_residence_editor.svg")
class_name EditorResidence3D extends Node3D

## Authoring data only. Children contain the shared model and optional Door marker.
@export var placed_res_bld_type: String
@export var placed_town_num: int

## Replace only the runtime instance; preserve authored children and their overrides.
func create_runtime() -> Residence3D:
	if Engine.is_editor_hint() or not is_inside_tree():
		return null
	var residence := Residence3D.new()
	residence.name = self.name
	residence.transform = self.transform
	residence.visible = self.visible
	residence.placed_res_bld_type = self.placed_res_bld_type
	residence.placed_town_num = self.placed_town_num
	self.replace_by(residence, true)
	self.queue_free()
	return residence
