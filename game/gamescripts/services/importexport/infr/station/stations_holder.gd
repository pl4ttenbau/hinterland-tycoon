@icon("res://assets/icons/icon_station_white.png")
class_name StationsHolder extends Node

const STATION_3D_SCENE_PATH = "res://scenes/subscenes/infr/station/rail_station_3d.tscn"

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
	# Validate all anchors before any stop is registered, so a bad record leaves no partial network.
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
		var place: LineAnchor = LineAnchor.from_dict(definition)
		if track == null or place == null or not place.is_valid_on(track):
			return ERR_INVALID_DATA
	return OK

func _load_rail_stop(definition: Dictionary, catalog: InterchangesLoader) -> Error:
	var station: RailStationData = StopMapper.rail_stop_from_dict(definition)
	if station == null:
		return ERR_INVALID_DATA
	var error: Error = catalog.register_stop(station, int(definition["interchangeNum"]))
	if error != OK:
		return error
	_register_rail_stop(station)
	return OK

## Index the stop and resolve its world position from its track and anchor. The anchor is normalized
## here, once the track exists: records may name any node, the invariant wants the nearest one.
func _register_rail_stop(station: RailStationData) -> void:
	var track: RailTrackData = Managers.rails.track_storage._by_id[station.track_num]
	station.anchor = station.anchor.normalized(track)
	station.position = station.anchor.position_on(track)
	stations_objs.append(station)
	stations_by_num[station.num] = station

func create_3d_stations() -> void:
	for station_obj: RailStationData in stations_objs:
		create_station_3d(station_obj)

func add_runtime_stop(station: RailStationData, building: RailPlatform3D) -> void:
	_register_rail_stop(station)
	create_station_3d(station)
	spawn_platform(station, building)

func create_station_3d(station_obj: RailStationData):
	var instance: RailStation3D = load(STATION_3D_SCENE_PATH).instantiate()
	instance.station = station_obj
	# Inventory discovery and transfer both use the station view's position.
	instance.station_pos = station_obj.position
	self.add_child(instance, true)
	instance.name = RailStation3D.STATION_NAME_FORMAT % [station_obj.town_name, station_obj.station_name]

func get_station_3d_with_num(_station_num: int) -> RailStation3D:
	for any_child: Node in self.get_children():
		if any_child is RailStation3D:
			if any_child.station.num == _station_num:
				return any_child as RailStation3D
	Loggie.warn("Cannot find RailStation3D object for station num %d" % _station_num)
	return null

## The rail stops on one track, e.g. to keep the track from being erased or edited under them.
func stops_on_track(track_num: int) -> Array[RailStationData]:
	var found: Array[RailStationData] = []
	for station: RailStationData in self.stations_objs:
		if station.track_num == track_num:
			found.append(station)
	return found
#endregion

#region Platforms
## Platforms are spawned once the RailStation3D parents exist (create_3d_stations, after the towns).
func spawn_platforms():
	Loggie.info("Spawning stations..")
	for station: RailStationData in self.stations_objs:
		self.spawn_platform(station)
	SignalBus.rail_stops_spawned.emit()

## The platform view of one stop, placed under its RailStation3D and turned to the track.
func spawn_platform(station: RailStationData, building: RailPlatform3D = null) -> RailStop3D:
	var platform: RailStop3D = RailStop3D.of(station, building)
	station.platform_view = platform
	var station_3d: RailStation3D = self.get_station_3d_with_num(station.num)
	platform.position = station_3d.to_local(station.position)
	station_3d.add_child(platform, true)
	platform.adjust_rotation_from_track()
	return platform
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
	self.spawn_platforms()

func _on_map_towns_loaded(_map_towns: Array[TownData]):
	# Data and interchange membership were resolved before terrain/town spawning.
	if not self.is_loaded:
		return
	self.create_3d_stations()
	SignalBus.stations_loaded.emit(self.stations_objs)
#endregion

func _exit_tree() -> void:
	# Stops can outlive their scene through global/editor references; drop the views they point to.
	for station: RailStationData in self.stations_objs:
		station.platform_view = null
	self.stations_objs.clear()
	self.stations_by_num.clear()
