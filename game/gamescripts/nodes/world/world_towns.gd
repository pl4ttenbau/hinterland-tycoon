@icon("res://assets/icons/icon_town_white.png")
class_name WorldTowns extends Node

@export var world_scene: WorldMapScene

@export_storage var towns: Array[TownData]:
	get(): 
		var towns_list: Array[TownData] = []
		for town_center: Node in self.get_children():
			if town_center is Town3D:
				towns_list.append(town_center.town)
		return towns_list

@export_storage var town_centers: Array[Town3D]:
	get(): 
		var towns_center_list: Array[Town3D] = []
		for town_center: Node in self.get_children():
			if town_center is Town3D:
				towns_center_list.append(town_center)
		return towns_center_list
