@icon("res://assets/icons/icon_town_white.png")
class_name WorldTowns extends Node

@export var world_scene: WorldMapScene

@export_storage var towns: Array[TownData]:
	get(): 
		var towns_list: Array[TownData] = []
		for town_center: Node in self.get_children():
			if town_center is TownCenter:
				towns_list.append(town_center.town)
		return towns_list

@export_storage var town_centers: Array[TownCenter]:
	get(): 
		var towns_center_list: Array[TownCenter] = []
		for town_center: Node in self.get_children():
			if town_center is TownCenter:
				towns_center_list.append(town_center)
		return towns_center_list
