@icon("res://assets/icons/icon_connect_white.png")
class_name StationResidencesConnector extends Node

@export var has_stations_loaded: bool = false
@export var has_buildings_placed: bool = false
@export var has_made_initial_connections: bool = false

func _enter_tree() -> void:
	SignalBus.stations_loaded.connect(Callable(self, "_on_stations_loaded"))
	SignalBus.town_buildings_spawned.connect(Callable(self, "_on_residences_placed"))
	SignalBus.rails_spawned.connect(Callable(self, "_on_rails_spawned"))
	
func connect_stations_to_residences():
	if !self.has_buildings_placed || !self.has_stations_loaded: return
	if self.has_made_initial_connections: return
	self.reassign_all_buildings_to_stations()
	self.has_made_initial_connections = true
	
func reassign_all_buildings_to_stations():
	Loggie.info("Connecting stations to residences..")
	var connected_total_buildings: int = 0
	for town: TownData in GlobalState.towns:
		var connected_new = self.reassign_town_buildings_to_stations(town)
		connected_total_buildings += connected_new
	self.has_made_initial_connections = true
	Loggie.info("Connected %d town buildings with stations" % connected_total_buildings)
	
func reassign_town_buildings_to_stations(town: TownData) -> int:
	var connected_town_buildings: int = 0
	for outer_res_bld: Residence3D in town.res_bld_containers:
		var closest_node_station := RailNodeStationData.find_closest_station_to_bld(outer_res_bld)
		if closest_node_station:
			self.connect_residence_to_station(outer_res_bld, closest_node_station, town)
			connected_town_buildings += 1
	return connected_town_buildings
	
func connect_residence_to_station(outer_res_bld: Residence3D, closest_node_station: RailNodeStationData,
		res_bld_town: TownData):
	outer_res_bld.res_bld_obj.connected_station = closest_node_station
	closest_node_station.parent_station.connected_town = res_bld_town

#region Callbacks
func _on_stations_loaded(_stations: Array[RailStationData]):
	self.has_stations_loaded = true
	# self.connect_stations_to_residences()
	
func _on_residences_placed():
	self.has_buildings_placed = true
	# self.connect_stations_to_residences()
	
func _on_rails_spawned(_containers: Array[RailTrack3D]):
	self.connect_stations_to_residences()
#endregion
