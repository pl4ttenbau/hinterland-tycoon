@icon("res://assets/icons/icon_house_white.png")
class_name TownBuildingHolder extends Node

@export var placed_buildings: Array[OuterResBld] = []

func _enter_tree() -> void:
	Managers.town_buildings = self
	SignalBus.towns_loaded.connect(Callable(self, "_on_towns_loaded"))
	SignalBus.towns_spawned.connect(Callable(self, "_on_towns_spawned"))
		
func load_preplaced_town_buildings():
	var map_house_container := self.get_map_houses_container()
	for child: Node in map_house_container.get_children():
		if child is OuterResBld:
			var outer_bld: OuterResBld = child as OuterResBld
			var res_bld_type := self.get_res_bld_type(outer_bld.placed_res_bld_type)
			outer_bld.res_bld = ResidenceBuildingData.new(outer_bld.placed_town_num, res_bld_type)
			outer_bld.res_bld.num = OuterResBld.next_num()
			# assign to town
			var town := self.get_town_by_num(outer_bld.placed_town_num)
			town.res_buildings.append(outer_bld)
			# save here as well
			self.placed_buildings.append(outer_bld)

#region Getters 
## the pre-placed buildings are in "TerrainContainer/Houses"
func get_map_houses_container() -> Node:
	var map_container: TerrainContainer = GlobalState.terrain
	if ! map_container:
		Loggie.error("Cannot collect town buildings: Terrain data not loaded")
		return null
	return map_container.get_child(2)
	
func get_res_bld_type(key: String) -> ResBldType:
	return GameTypes.get_res_bld_type(key)

func get_town_by_num(_num: int) -> TownData:
	for town: TownData in GlobalState.towns:
		if town.num == _num: return town
	return null
#endregion
	
#region Signal Callbacks
func _on_towns_loaded():
	self.load_preplaced_town_buildings()
#endregion
