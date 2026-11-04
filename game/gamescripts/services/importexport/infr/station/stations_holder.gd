@icon("res://assets/icons/icon_station_white.png")
class_name StationsHolder extends Node

const STATION_3D_SCENE_PATH = "res://scenes/subscenes/infr/station/rail_station_3d.tscn"

@export var node_stations_storage: NodeStationLinkStore = NodeStationLinkStore.new()

@export var stations_objs: Array[RailStationData] = []
@export var stations_by_num: Dictionary = {}
var is_loaded: bool = false

#region RailStationData & RailStation3D
## here the station parents, RailStationData & RailStation3D are created
func load_stations(catalog: InterchangesLoader = null) -> Error:
	if self.is_loaded:
		return OK
	if catalog == null:
		catalog = Managers.interchanges
	if catalog == null or not catalog.is_loaded or Managers.rails == null:
		return ERR_UNCONFIGURED
	# Validate all anchors before any stop can replace an existing node link.
	var error: Error = _validate_rail_anchors(catalog.stop_definitions)
	if error != OK:
		return error
	for definition: Dictionary in catalog.stop_definitions:
		if definition["domain"] == "RAIL":
			error = _load_rail_stop(definition, catalog)
			if error != OK:
				return error
	GlobalState.station_objs = self.stations_objs
	self.is_loaded = true
	return OK

func _validate_rail_anchors(definitions: Array[Dictionary]) -> Error:
	for definition: Dictionary in definitions:
		if definition["domain"] != "RAIL":
			continue
		var track: RailTrackData = Managers.rails.track_storage._by_id.get(int(definition["trackNum"]))
		if track == null or not track.has_node_index(int(definition["nodeIndex"])) \
				or track.nodes[int(definition["nodeIndex"])].station != null:
			return ERR_INVALID_DATA
	return OK

func _load_rail_stop(definition: Dictionary, catalog: InterchangesLoader) -> Error:
	var station: RailStationData = RailStationData.of_dict(definition)
	if station == null:
		return ERR_INVALID_DATA
	var error: Error = catalog.register_stop(station, int(definition["interchangeNum"]))
	if error != OK:
		return error
	self.stations_objs.append(station)
	self.stations_by_num[station.num] = station
	var track: RailTrackData = Managers.rails.track_storage._by_id[station.track_num]
	var node: RailNodeData = track.nodes[station.node_index]
	# Preserve the authored stop ID on the adapter used by rail signs/catchments.
	var link := NodeStationLinkData.of(node, station.num)
	link.num = station.num
	link.hide_building = station.hide_building
	node.station = link
	station.connect_node_station(link)
	self.add_station_link_from_node(link)
	return OK

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
	# Data and interchange membership were resolved before terrain/town spawning.
	if not self.is_loaded:
		return
	self.create_3d_stations()
	SignalBus.stations_loaded.emit(self.stations_objs)
#endregion

func _exit_tree() -> void:
	# Rail resources can outlive their scene through global/editor references.
	# Detach our session-owned adapters instead of leaving stale station links.
	for link: NodeStationLinkData in self.node_stations_storage.get_all():
		if link.parent_node != null:
			if link.parent_node.station == link:
				link.parent_node.station = null
			var track := link.parent_node.parent_track as RailTrackData
			if track != null:
				track.node_stations.erase(link)
		link.parent_station = null
		link.parent_node = null
		link.station3d = null
	for station: RailStationData in self.stations_objs:
		station.node_stations.clear()
	self.stations_objs.clear()
	self.stations_by_num.clear()
