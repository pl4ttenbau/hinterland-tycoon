@icon("res://assets/icons/icon_station_white.png")
class_name StationsHolder extends Node

@export var stations: Array[RailStationData] = []
@export var outer_stations: Array[OuterRailStation] = []

static var MAX_INDUSTRY_DIST = 200

func _enter_tree() -> void:
	Managers.stations = self
	SignalBus.industries_spawned.connect(Callable(self, "_on_industries_spawned"))

#region Spawning
## Station objects are created with the rail tracks, but instanciated one by one here
func spawn_stations():
	Loggie.info("Spawning stations..")
	for station_obj: RailStationData in GlobalState.stations:
		var outer_station := self.spawn_station(station_obj)
		outer_station.adjust_rotation_from_track()
	self.connect_industries()
	SignalBus.stations_spawned.emit()
	
func spawn_station(station_obj: RailStationData) -> OuterRailStation:
	station_obj.num = RailStationData.next_station_num()
	var outer_station: OuterRailStation = station_obj.spawn()
	# container._name_nodes()
	self.outer_stations.append(outer_station)
	self.add_child(outer_station, true)
	return outer_station
#endregion

#region Connections
func connect_industries():
	Loggie.info("Connecting industries ..")
	for industry: IndustryData in GlobalState.industries:
		var closest_station: RailStationData = null
		var closest_distance: float = 99999
		for station: RailStationData in GlobalState.stations:
			var sq_dist: float = industry.pos.distance_squared_to(station.position)
			if sq_dist <= closest_distance:
				closest_station = station
				closest_distance = sq_dist
		if closest_station && closest_distance > MAX_INDUSTRY_DIST:
			closest_station.connect_industry(industry)
#endregion

#region Goods Spawning
func spawn_rnd_passenger():
	var rnd_start_bld = GlobalState.res_blds.pick_random() as ResidenceBuildingData
	var start_station: RailStationData = rnd_start_bld.connected_station
	if start_station:
		var spawned_res = SpawnedGood.new("passenger", 1)
		spawned_res.target_location = GlobalState.res_blds.pick_random()
		start_station.add_spawned_good(spawned_res)
#endregion
	
#region Callbacks
func _on_industries_spawned() -> void:
	self.spawn_stations()
	
func _on_station_timer_tick():
	self.spawn_rnd_passenger()
#endregion
