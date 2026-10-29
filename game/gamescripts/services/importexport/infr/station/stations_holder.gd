@icon("res://assets/icons/icon_station_white.png")
class_name StationsHolder extends Node

const MAP_STATIONS_FILEPATH_FORMAT := "res://world/%s/jsondata/stations.json"
const STATION_3D_SCENE_PATH = "res://scenes/subscenes/infr/station/rail_station_3d.tscn"

@export var node_stations_storage: NodeStationLinkStore = NodeStationLinkStore.new()

@export var stations_objs: Array[RailStationData] = []
@export var stations_by_num: Dictionary = {}

func _enter_tree() -> void:
	Managers.stations = self
	Managers.towns.towns_registered.connect(Callable(self, "_on_map_towns_loaded"))
	SignalBus.stations_loaded.connect(Callable(self, "_on_stations_loaded"))
	
#region RailStationData & RailStation3D
## here the station parents, RailStationData & RailStation3D are created
func load_stations():
	Loggie.info("Loading stations..")
	var full_json_path := MAP_STATIONS_FILEPATH_FORMAT % GlobalState.selected_map_name
	var stations_arr_string: String = FileAccess.get_file_as_string(full_json_path)
	for station_dict in JSON.parse_string(stations_arr_string):
		var station_obj: RailStationData = RailStationData.of_dict(station_dict)
		self.stations_objs.append(station_obj)
		stations_by_num.set(station_obj.num, station_obj)
	# connect RailNodeStations to parents
	self.connect_node_stations_to_parents()
	# save in global state & inform signal bus
	GlobalState.station_objs = self.stations_objs

## spawns new RailStation3D instances
func create_3d_stations():
	for station_obj: RailStationData in self.stations_objs:
		self.create_station_3d(station_obj)

func create_station_3d(station_obj: RailStationData):
	var instance: RailStation3D = load(STATION_3D_SCENE_PATH).instantiate()
	instance.station = station_obj
	self.add_child(instance, true)
	instance.name = RailStation3D.STATION_NAME_FORMAT % [station_obj.town_name, station_obj.station_name]

func connect_node_stations_to_parents():
	for track: RailTrackData in Managers.rails.track_storage.get_all():
		for rail_node_station: NodeStationLinkData in track.node_stations:
			var parent_num: int = rail_node_station.parent_station_num
			var parent := RailStationData.get_by_num(parent_num)
			parent.connect_node_station(rail_node_station)

func get_station_3d_with_num(_station_num: int) -> RailStation3D:
	for any_child: Node in self.get_children():
		if any_child is RailStation3D:
			if any_child.station.num == _station_num:
				return any_child as RailStation3D
	Loggie.warn("Cannot find RailStation3D object for station num %d" % _station_num)
	return null
#endregion

#region Node Station Links
## called from RailNodeData.parse_and_add_special
func add_station_link_from_node(node_station_link: NodeStationLinkData):
	# add to track & global station list
	var station_track: RailTrackData = node_station_link.parent_node.parent_track
	station_track.node_stations.append(node_station_link)
	Managers.stations.node_stations_storage.add(node_station_link)

## Station objects are created with the rail tracks, but instanciated one by one here
## this only happens, after the parents - RailStationData - are loaded & spawned in scene tree
## after this, station initialization has been completely finished
func spawn_station_links():
	Loggie.info("Spawning stations..")
	for track: RailTrackData in Managers.rails.track_storage.get_all():
		for node_station_link: NodeStationLinkData in track.node_stations:
			var outer_station: NodeStationLink3D = self.spawn_station_link(node_station_link)
			outer_station.adjust_rotation_from_track()
	SignalBus.node_station_links_spawned.emit()

func spawn_station_link(node_station_link: NodeStationLinkData) -> NodeStationLink3D:
	var station_link_3d: NodeStationLink3D = node_station_link.spawn()
	self.node_stations_storage.add_container(station_link_3d)
	# add to parent station
	var station_3d: RailStation3D = self.get_station_3d_with_num(node_station_link.parent_station_num)
	station_3d.add_child(station_link_3d, true)
	return station_link_3d
#endregion

#region Vehicle At Station
func get_station_around_pos(vec3: Vector3) -> RailStationData:
	for station: RailStationData in GlobalState.station_objs:
		if vec3.distance_squared_to(station.position) < 100:
			return station
	return null
#endregion

#region Callbacks
func _on_stations_loaded(_stations: Array[RailStationData]) -> void:
	self.spawn_station_links()

func _on_map_towns_loaded(_map_towns: Array[TownData]):
	self.load_stations()
	self.create_3d_stations()
	SignalBus.stations_loaded.emit(self.stations_objs)
#endregion
