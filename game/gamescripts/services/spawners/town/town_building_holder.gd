## loads buildings from map "Houses" node, registers them and places them below OuterTown
@icon("res://assets/icons/icon_house_white.png")
class_name TownBuildingHolder extends Node

@export var placed_buildings: Array[OuterResBld] = []

# Loading State
@export var has_map_spawned: bool = true
@export var has_res_bld_types_loaded: bool = false

func _enter_tree() -> void:
	Managers.town_buildings = self
	SignalBus.map_spawned.connect(Callable(self, "_on_map_spawned"))
	SignalBus.res_bld_types_loaded.connect(Callable(self, "_on_res_bld_types_loaded"))
	Managers.towns.towns_registered.connect(Callable(self, "_on_map_towns_loaded"))
	
func load_preplaced_town_buildings():
	## abort if res bld types or map isnt loaded yet
	# if !self.has_res_bld_types_loaded: return
	Loggie.info("spawning pre-placed ResBlds...")
	for child: Node in self.get_map_houses_container().get_children():
		if child is OuterResBld:
			self.place_preplaced_res_bld(child as OuterResBld)
	SignalBus.town_buildings_spawned.emit()
			
func place_preplaced_res_bld(outer_bld: OuterResBld):
	var res_bld_type := ResBldType.get_by_key(outer_bld.placed_res_bld_type)
	outer_bld.res_bld_obj = ResidenceBuildingData.new(outer_bld.placed_town_num, res_bld_type)
	outer_bld.res_bld_obj.num = OuterResBld.next_num()
	# assign to town
	var town := get_res_bld_town_obj(outer_bld)
	if town: 
		self.register_res_bld(outer_bld, town)

func register_res_bld(outer_bld: OuterResBld, parent_town: TownData):
	self.placed_buildings.append(outer_bld) # save here as well
	parent_town.add_res_bld(outer_bld)

#region Getters 
## the pre-placed buildings are in "WorldMapScene/Houses"
func get_map_houses_container() -> Node:
	var map_container: WorldMapScene = GlobalState.world_container
	if ! map_container:
		Loggie.error("Cannot collect town buildings: Terrain data not loaded")
		return null
	return map_container.find_child("Houses")
	
func get_res_bld_town_obj(outer_bld: OuterResBld) -> TownData:
	var town := TownData.get_town_by_num(outer_bld.placed_town_num)
	if ! town:
		Loggie.error("Cannot spawn pre-placed building %s in Town %s: not found" % [outer_bld.name, outer_bld.placed_town_num])
	return town
#endregion
	
#region Signal Callbacks
func _on_map_spawned(_terrain_container: WorldMapScene):
	self.has_map_spawned = true
	self.load_preplaced_town_buildings()
	
func _on_res_bld_types_loaded():
	self.has_res_bld_types_loaded = true
	self.load_preplaced_town_buildings()
	
func _on_map_towns_loaded(_towns: Array[TownData]):
	self.load_preplaced_town_buildings()
#endregion
