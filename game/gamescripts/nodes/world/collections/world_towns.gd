@tool
@icon("res://assets/icons/icon_town_white.png")
class_name WorldTowns extends Node

const TOWN_ROOT_SCENE_PATH = "res://scenes/subscenes/town/town_root.tscn"

@export var world_scene: WorldMapScene

#region Town & -Center Child Getters
func get_town3ds() -> Array[Town3D]:
	var town3d_arr: Array[Town3D] = []
	for any_child: Node in self.get_children():
			if any_child is Town3D: town3d_arr.append(any_child as Town3D)
	return town3d_arr
	
func get_town_objs() -> Array[TownData]:
	var town_obj_arr: Array[TownData] = []
	for town3d: Town3D in self.get_town3ds():
		if town3d.town != null: town_obj_arr.append(town3d.town)
	return town_obj_arr
#endregion

#region Editor Methods
@export_group("Editor Actions")
@export_tool_button("Add Town", "ToolAddNode")
var add_town = Callable(self, "do_add_new_town")

func do_add_new_town():
	# create new Town3D
	var town3d: Town3D = load(TOWN_ROOT_SCENE_PATH).instantiate()
	# and add to self
	self.add_child(town3d)
	# add TownData
	town3d.town = TownData.with_num(self._get_latest_unused_town_number())
	# set owner (important: must be added as child first!)
	town3d.owner = self

## we are assuming the Town3D children are all numbered in order here
func _get_latest_unused_town_number() -> int:
	# collect all children that are Town3Ds
	var town_data_chilren: Array[TownData] = self.get_town_objs()
	# none: return 1
	if town_data_chilren.is_empty(): return 1
	# return number of latest one +1
	return town_data_chilren[-1].num -1
	
#endregion
