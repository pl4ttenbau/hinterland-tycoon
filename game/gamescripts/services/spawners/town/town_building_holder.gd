@icon("res://assets/icons/icon_house_white.png")
class_name TownBuildingHolder extends Node

@export var placed_buildings: Array[OuterResBld] = []

func _enter_tree() -> void:
	Managers.town_buildings = self
	SignalBus.towns_loaded.connect(Callable(self, "_on_towns_loaded"))
	SignalBus.towns_spawned.connect(Callable(self, "_on_towns_spawned"))
	SignalBus.map_spawned.connect(Callable(self, "_on_map_spawned"))
		
func load_preplaced_town_buildings():
	for child: Node in self.get_map_houses_container().get_children():
		if child is OuterResBld:
			self.place_preplaced_res_bld(child as OuterResBld)
			
func place_preplaced_res_bld(outer_bld: OuterResBld):
	var res_bld_type := self.get_res_bld_type(outer_bld.placed_res_bld_type)
	outer_bld.res_bld = ResidenceBuildingData.new(outer_bld.placed_town_num, res_bld_type)
	outer_bld.res_bld.num = OuterResBld.next_num()
	# assign to town
	var town := get_res_bld_town_obj(outer_bld)
	if town: 
		town.res_bld_containers.append(outer_bld)
		self.placed_buildings.append(outer_bld) # save here as well

#region Getters 
## the pre-placed buildings are in "TerrainContainer/Houses"
func get_map_houses_container() -> Node:
	var map_container: WorldContainer = GlobalState.world_container
	if ! map_container:
		Loggie.error("Cannot collect town buildings: Terrain data not loaded")
		return null
	return map_container.get_child(2)
	
func get_res_bld_type(key: String) -> ResBldType:
	return GameTypes.get_res_bld_type(key)
	
func get_res_bld_town_obj(outer_bld: OuterResBld) -> TownData:
	var town := TownData.get_town_by_num(outer_bld.placed_town_num)
	if ! town:
		Loggie.error("Cannot spawn pre-placed building in Town %s: not found" % outer_bld.placed_town_num)
	return town
#endregion
	
#region Signal Callbacks
func _on_towns_loaded():
	pass
	
func _on_map_spawned(_terrain_container: WorldContainer):
	self.load_preplaced_town_buildings()
#endregion
