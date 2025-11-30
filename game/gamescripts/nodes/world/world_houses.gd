@icon("res://assets/icons/icon_house_white.png")
class_name WorldHouses extends Node

@export var world_scene: WorldMapScene

@export_storage var houses: Array[OuterResBld]:
	get(): 
		var outer_res_blds: Array[OuterResBld] = []
		for outer_res_bld: Node in self.get_children():
			if outer_res_bld is OuterResBld:
				outer_res_blds.append(outer_res_bld)
		return outer_res_blds
