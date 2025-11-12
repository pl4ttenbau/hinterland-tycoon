@icon("res://assets/icons/icon_house_white.png")
class_name WorldTowns extends Node

@export var world_scene: TerrainContainer

func get_towns() -> Array[TownData]:
	var towns: Array[TownData] = []
	for town_center: TownCenter in self.get_children():
		towns.append(town_center.town)
	return towns
