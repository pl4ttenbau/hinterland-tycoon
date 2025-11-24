@icon("res://assets/icons/icon_gears_white.png")
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
	Loggie.info("Connected %d town buildings with stations" % connected_total_buildings)
	
func reassign_town_buildings_to_stations(town: TownData) -> int:
	var connected_town_buildings: int = 0
	for res_bld_container: OuterResBld in town.res_bld_containers:
		var closest_station_obj := self.find_closest_station_to_bld(res_bld_container)
		# self.has_made_initial_connections = true
		if closest_station_obj:
			Loggie.info("Connect House %s to station %s" % [res_bld_container.name, closest_station_obj.parent_station.station_name])
			res_bld_container.res_bld_obj.connected_station = closest_station_obj
			closest_station_obj.parent_station.connected_town = town
			connected_town_buildings += 1
	return connected_town_buildings
			
func find_closest_station_to_bld(res_bld: OuterResBld) -> RailNodeStationData:
	var closest_station_obj: RailNodeStationData
	var closest_station_distance: float = 9999
	for station: RailStationData in GlobalState.station_objs:
		for node_station: RailNodeStationData in station.node_stations:
			var dist = res_bld.global_position.distance_to(node_station.position)
			if dist <= 200 && dist < closest_station_distance:
				closest_station_distance = dist
				closest_station_obj = node_station
	return closest_station_obj

#region Callbacks
func _on_stations_loaded(_stations: Array[RailStationData]):
	self.has_stations_loaded = true
	# self.connect_stations_to_residences()
	
func _on_residences_placed():
	self.has_buildings_placed = true
	# self.connect_stations_to_residences()
	
func _on_rails_spawned(_containers: Array[OuterRailTrack]):
	self.connect_stations_to_residences()
#endregion
