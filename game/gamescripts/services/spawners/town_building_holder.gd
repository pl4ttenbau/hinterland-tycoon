@icon("res://assets/icons/icon_house_white.png")
class_name TownBuildingHolder extends Node

func _enter_tree() -> void:
	SignalBus.towns_loaded.connect(Callable(self, "_towns_loaded"))
	
func _towns_loaded():
	self.load_preplaced_town_buildings()
		
func load_preplaced_town_buildings():
	var map_house_container := self.get_map_houses_container()
	for child: Node in map_house_container.get_children():
		if child is OuterResBld:
			pass
	
func get_map_houses_container() -> Node:
	var map_container: TerrainContainer = GlobalState.terrain
	if ! map_container:
		Loggie.error("Cannot collect townm buildings: Terrain data not loaded")
		return null
	return map_container.get_child(2)
