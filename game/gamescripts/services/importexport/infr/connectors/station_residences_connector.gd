@icon("res://assets/icons/icon_connect_white.png")
class_name StationResidencesConnector extends Node

@export var has_stations_loaded: bool = false
@export var has_buildings_placed: bool = false
@export var has_made_initial_connections: bool = false

func connect_stations_to_residences() -> void:
	if has_buildings_placed and has_stations_loaded and not has_made_initial_connections:
		reassign_all_buildings_to_stations()

func reassign_all_buildings_to_stations() -> void:
	if not is_instance_valid(Managers.interchanges):
		return
	for interchange: InterchangeData in Managers.interchanges.interchanges:
		interchange.connections.clear_houses()
	for town: TownData in GlobalState.towns:
		reassign_town_buildings_to_stations(town)
	has_made_initial_connections = true

func reassign_town_buildings_to_stations(town: TownData) -> int:
	var count: int = 0
	for house: Residence3D in town.res_bld_containers:
		if _connect_residence(house):
			count += 1
	return count

func _connect_residence(house: Residence3D) -> bool:
	if house.res_bld_obj == null:
		return false
	var data: ResidenceBuildingData = house.res_bld_obj
	_clear_residence_connection(house, data)
	var access: Dictionary = Managers.interchanges.find_access(house.global_position)
	if access.is_empty():
		return false
	data.connected_interchange = access.interchange
	data.reachable_stops.assign(access.stops)
	access.interchange.connections.connect_house(house, data.reachable_stops)
	# Compatibility only: passenger spawning uses reachable_stops for both modes.
	for stop: AbstractStation in data.reachable_stops:
		if stop is RailStationData and not stop.node_stations.is_empty():
			data.connected_station = stop.node_stations[0]
			break
	return true

func _clear_residence_connection(house: Residence3D, data: ResidenceBuildingData) -> void:
	# Remove former membership even when the building has lost all coverage.
	if data.connected_interchange != null:
		var old: StationConnections = data.connected_interchange.connections
		for index: int in range(old.houses.size() - 1, -1, -1):
			if old.houses[index].house == house:
				old.houses.remove_at(index)
	data.connected_interchange = null
	data.reachable_stops.clear()
	data.connected_station = null

func _on_stops_linked() -> void:
	has_stations_loaded = true
	connect_stations_to_residences()

func _on_stations_loaded(_stations: Array[RailStationData]) -> void:
	_on_stops_linked()

func _on_residences_placed() -> void:
	has_buildings_placed = true
	connect_stations_to_residences()

func _on_rails_spawned(_containers: Array[RailTrack3D]) -> void:
	connect_stations_to_residences()
