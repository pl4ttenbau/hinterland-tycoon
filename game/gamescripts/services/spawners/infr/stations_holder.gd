@icon("res://assets/icons/icon_station_white.png")
class_name StationsHolder extends Node

@export var stations: Array[RailStationData] = []
@export var outer_stations: Array[OuterRailStation] = []

func _enter_tree() -> void:
	Managers.stations = self
	SignalBus.rails_spawned.connect(Callable(self, "_on_rails_rails_spawned"))

#region Spawning
## Station objects are created with the rail tracks, but instanciated one by one here
func spawn_stations():
	Loggie.info("Spawning stations..")
	for station_obj: RailStationData in GlobalState.stations:
		var container: OuterRailStation = spawn_station(station_obj)
		container.adjust_rotation_from_track()
	SignalBus.stations_spawned.emit()
	
func spawn_station(station_obj: RailStationData) -> OuterRailStation:
	station_obj.num = RailStationData.next_station_num()
	var outer_station: OuterRailStation = station_obj.spawn()
	# container._name_nodes()
	self.outer_stations.append(outer_station)
	self.add_child(outer_station, true)
	return outer_station
#endregion

#region Goods Spawning
func spawn_rnd_passenger():
	var rnd_start_bld = GlobalState.res_blds.pick_random() as ResidenceBuildingData
	var start_station: RailStationData = rnd_start_bld.connected_station
	if start_station:
		var spawned_res = SpawnedResource.new("passenger")
		spawned_res.target_location = GlobalState.res_blds.pick_random()
		start_station.add_resource(spawned_res)
#endregion
	
#region Callbacks
func _on_rails_rails_spawned(_rails: Array[OuterRailTrack]) -> void:
	self.spawn_stations()
	
func _on_station_timer_tick():
	self.spawn_rnd_passenger()
#endregion
