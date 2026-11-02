@icon("res://assets/icons/icon_station_white.png")
class_name RoadStopsLoader extends Node

const SCENE_PATH := "res://scenes/subscenes/infr/station/bus_stop_3d.tscn"

signal stops_spawned()

## Road widths are not yet authored as infrastructure data. This is a visible,
## adjustable shelter offset, not a lane width or a movement/pathfinding rule.
@export var roadside_offset_metres: float = 4.0

var stops: Array[RoadStationData] = []
var by_num: Dictionary = {}
var containers_by_num: Dictionary = {}
var is_loaded: bool = false

func load_stops(catalog: InterchangesLoader = null) -> Error:
	if self.is_loaded:
		return OK
	if catalog == null:
		catalog = Managers.interchanges
	if catalog == null or not catalog.is_loaded or Managers.roads == null:
		return ERR_UNCONFIGURED
	var error: Error = _validate_road_anchors(catalog.stop_definitions)
	if error != OK:
		return error
	for definition: Dictionary in catalog.stop_definitions:
		if definition["domain"] == "ROAD":
			error = _load_road_stop(definition, catalog)
			if error != OK:
				return error
	self.is_loaded = true
	return OK

func _validate_road_anchors(definitions: Array[Dictionary]) -> Error:
	for definition: Dictionary in definitions:
		if definition["domain"] != "ROAD":
			continue
		var road: RoadData = Managers.roads.storage._by_id.get(int(definition["roadNum"]))
		if road == null or int(definition["nodeIndex"]) >= road.nodes.size():
			return ERR_INVALID_DATA
	return OK

func _load_road_stop(definition: Dictionary, catalog: InterchangesLoader) -> Error:
	var stop: RoadStationData = RoadStationData.of_dict(definition)
	var error: Error = catalog.register_stop(stop, int(definition["interchangeNum"]))
	if error != OK:
		return error
	var road: RoadData = Managers.roads.storage._by_id[stop.road_num]
	stop.position = road.nodes[stop.node_index].position
	self.stops.append(stop)
	self.by_num[stop.num] = stop
	return OK

func spawn_stops() -> void:
	for stop: RoadStationData in self.stops:
		if self.containers_by_num.has(stop.num):
			continue
		var view: BusStop3D = load(SCENE_PATH).instantiate()
		view.name = "BusStop_%d" % stop.num
		view.station = stop
		self.add_child(view)
		var road: RoadData = Managers.roads.storage._by_id[stop.road_num]
		view.configure_road_layout(self._heading(road, stop.node_index), self.roadside_offset_metres)
		self.containers_by_num[stop.num] = view
	self.stops_spawned.emit()

func _heading(road: RoadData, node_index: int) -> Vector3:
	if road.curve == null:
		road.build_curve()
	var offset: float = road.curve.get_closest_offset(road.nodes[node_index].rel_position)
	var length: float = road.curve.get_baked_length()
	var heading: Vector3 = road.curve.sample_baked(minf(length, offset + 0.2), true) \
		- road.curve.sample_baked(maxf(0.0, offset - 0.2), true)
	heading.y = 0.0
	return heading.normalized() if not heading.is_zero_approx() else Vector3.FORWARD

func _on_map_towns_loaded(_towns: Array[TownData]) -> void:
	if self.is_loaded:
		self.spawn_stops()
