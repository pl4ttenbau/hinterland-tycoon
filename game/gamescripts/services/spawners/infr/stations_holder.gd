@icon("res://assets/icons/icon_station_white.png")
class_name StationsHolder extends Node

const MAP_STATIONS_FILEPATH_FORMAT := "res://world/%s/jsondata/stations.json"

@export var node_stations: Array[RailNodeStationData] = []
@export var outer_stations: Array[OuterRailStation] = []

@export var stations_objs: Array[RailStationData] = []
@export var stations_by_num: Dictionary = {}

@export var towns: Array[TownData]

static var MAX_INDUSTRY_DIST = 200

func _enter_tree() -> void:
	Managers.stations = self
	Managers.towns.towns_registered.connect(Callable(self, "_on_map_towns_loaded"))
	SignalBus.industries_spawned.connect(Callable(self, "_on_industries_spawned"))
	
#region Loading
func load_stations():
	Loggie.info("Loading stations..")
	var full_json_path := MAP_STATIONS_FILEPATH_FORMAT % GlobalState.selected_map_name
	var stations_arr_string: String = FileAccess.get_file_as_string(full_json_path)
	for station_dict in JSON.parse_string(stations_arr_string):
		var station_obj: RailStationData = RailStationData.of_dict(station_dict)
		self.stations_objs.append(station_obj)
		stations_by_num.set(station_obj.num, station_obj)
	# connect RailNodeStations to parents
	self.connect_node_stations()
	# save in global state & inform signal bus
	GlobalState.station_objs = self.stations_objs
	SignalBus.stations_loaded.emit(self.stations_objs)
	
func connect_node_stations():
	for track: RailTrackData in Managers.rails.track_storage.get_all():
		for rail_node_station: RailNodeStationData in track.node_stations:
			var parent_num: int = rail_node_station.station_num
			var parent := RailStationData.get_by_num(parent_num)
			parent.connect_node_station(rail_node_station)
#endregion

#region Spawning
## Station objects are created with the rail tracks, but instanciated one by one here
func spawn_stations():
	Loggie.info("Spawning stations..")
	for station_obj: RailNodeStationData in GlobalState.node_stations:
		# var outer_station := self.spawn_station(station_obj)
		# outer_station.adjust_rotation_from_track()
		pass
	#self.connect_industries()
	SignalBus.stations_spawned.emit()
	
func spawn_station(station_obj: RailNodeStationData) -> OuterRailStation:
	station_obj.num = RailNodeStationData.next_station_num()
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
		var closest_station: RailNodeStationData = null
		var closest_distance: float = 99999
		for station: RailNodeStationData in GlobalState.node_stations:
			var sq_dist: float = industry.pos.distance_squared_to(station.position)
			if sq_dist <= closest_distance:
				closest_station = station
				closest_distance = sq_dist
		if closest_station && closest_distance > MAX_INDUSTRY_DIST:
			closest_station.connect_industry(industry)
#endregion

#region Goods Spawning
func spawn_rnd_passenger():
	if ! GlobalState.loaded_map: return
	var rnd_start_bld = GlobalState.res_blds.pick_random() as ResidenceBuildingData
	var start_station: RailNodeStationData = rnd_start_bld.connected_station
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

func _on_map_towns_loaded(map_towns: Array[TownData]):
	self.towns = map_towns
	self.load_stations()
#endregion
