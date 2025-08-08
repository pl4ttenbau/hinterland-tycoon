@icon("res://assets/icons/icon_station_white.png")
class_name StationsHolder extends Node

@export var stations: Array[RailStationData] = []

func _enter_tree() -> void:
	Managers.stations = self
	SignalBus.rails_spawned.connect(Callable(self, "_on_rails_rails_spawned"))

#region Spawning
## Station objects are created with the rail tracks, but instanciated one by one here
func spawn_stations():
	Loggie.info("Spawning stations..")
	for station_obj: RailStationData in GlobalState.stations:
		var container: OuterRailStation = spawn_station(station_obj)
		container.rotate_to_prev_node()
		container.rotate(Vector3(0, 1, 0), 90)
	SignalBus.stations_spawned.emit()
	
func spawn_station(station_obj: RailStationData) -> OuterRailStation:
	station_obj.num = RailStationData.next_station_num()
	var container: OuterRailStation = station_obj.spawn()
	# container._name_nodes()
	self.add_child(container, true)
	return container
#endregion

#region Goods Spawning
func spawn_rnd_passenger():
	var rnd_start_bld := GlobalState.res_blds.pick_random() as ResidenceBuildingData
	var start_town_name := TownData.get_town_by_num(rnd_start_bld.town_num).town_name

	var start_station: RailStationData = rnd_start_bld.connected_station
	if !start_station:
		Loggie.warn("skip passenger spawning in \"%s\": not connected to any station" % start_town_name) 
		return
	var spawned_res = SpawnedResource.new("passenger")
	start_station.add_resource(spawned_res)
	spawned_res.target_location = GlobalState.res_blds.pick_random()
	Loggie.info("Spawn passengers in town %s" % start_town_name)
#endregion
	
#region Callbacks
func _on_rails_rails_spawned(_rails: Array[OuterRailTrack]) -> void:
	spawn_stations()
	
func _on_station_timer_tick():
	self.spawn_rnd_passenger()
#endregion
