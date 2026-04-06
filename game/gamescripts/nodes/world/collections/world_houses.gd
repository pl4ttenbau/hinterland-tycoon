@tool
@icon("res://assets/icons/icon_house_white.png")
class_name WorldHouses extends Node

@export var world_scene: WorldMapScene

@export_storage var houses: Array[Residence3D]:
	get(): 
		var outer_res_blds: Array[Residence3D] = []
		for outer_res_bld: Node in NodeTreeUtils.get_all_children(self):
			if outer_res_bld is Residence3D:
				outer_res_blds.append(outer_res_bld)
		return outer_res_blds

@export_tool_button("Generate Town Folders")
var gen_folders = Callable(self, "do_generate_town_folders")

@export_tool_button("Sort Houses To Towns")
var sort_houses = Callable(self, "do_sort_to_towns")

func do_generate_town_folders():
	var world_towns: WorldTowns = self._get_town_container()
	for town_obj: TownData in world_towns.get_town_objs():
		var node_name: String = "%d_%s" % [town_obj.num, town_obj.town_name]
		# create child node
		var town_folder: Node = Node.new()
		town_folder.name = node_name
		self.add_child(town_folder)
		town_folder.owner = EditorInterface.get_edited_scene_root()

func _get_town_container() -> WorldTowns:
	return $"../Towns" as WorldTowns

func do_sort_to_towns():
	for direct_child: Node in self.get_children():
		if direct_child is Residence3D && direct_child.placed_town_num:
			var town_folder: Node = self.find_town_folder(direct_child.placed_town_num)
			if town_folder:
				direct_child.reparent(town_folder)

func find_town_folder(town_num: int) -> Node:
	for direct_child in self.get_children():
		if direct_child.name.begins_with("%d_" % town_num):
			return direct_child
	return null
