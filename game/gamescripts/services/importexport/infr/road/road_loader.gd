@icon("res://assets/icons/icon_road_white.png")
class_name RoadsLoader extends Node

const JSON_PATH_FORMAT = "res://world/%s/jsondata/roads.json"
const NODES_GROUP = "Roads"
const MAX_VISIBLE_DIST := 200

@export var storage: RoadStore = RoadStore.new()
@export var markers: RoadMarkerStore = RoadMarkerStore.new()

func _ready() -> void:
	var tool: Node = load("res://game/gamescripts/nodes/marker/road_marker_tool.gd").new()
	tool.roads = self
	add_child(tool)

signal network_changed()

var network_revision: int = 0

signal roads_loaded(_roads: Array[RoadData])
signal roads_spawned(_roads: Array[RoadWay3D])

#region Road Loading
func load_roads() -> void:
	var full_json_path := JSON_PATH_FORMAT % GlobalState.selected_map_name
	var roads_arr_str: String = FileAccess.get_file_as_string(full_json_path)
	for json_road in JSON.parse_string(roads_arr_str):
		self.storage.add(RoadMapper.road_from_data_json(json_road))
	self.roads_loaded.emit(self.storage.get_all())
	SignalBus.roads_loaded.emit(self.storage.get_all())
#endregion

#region Road Spawning
func spawn_roads():
	for road in self.storage.get_all():
		spawn_road(road)
	# emit signals
	self.roads_spawned.emit(self.storage.get_containers())
	SignalBus.roads_spawned.emit()

func spawn_road(road: RoadData):
	var instanciated: RoadWay3D = RoadWay3D.of(road)
	if instanciated == null:
		return
	add_child(instanciated, true)
	self.storage.add_container(instanciated)
	SignalBus.road_spawned.emit(instanciated)
#endregion

#region Callbacks
func _on_world_spawned(_container: WorldMapScene):
	spawn_roads()

func _on_map_selected(_selected_map: MapData):
	self.load_roads()
#endregion


## A segment is the span between adjacent authored nodes.
func erase_segment(road: RoadData, segment_index: int) -> Error:
	return erase_span(road, segment_index, segment_index + 1)


## The selected endpoints survive if they still have a span on their outside.
func erase_span(road: RoadData, from_index: int, to_index: int) -> Error:
	var first: int = mini(from_index, to_index)
	var last: int = maxi(from_index, to_index)
	if not _has_road(road) or first < 0 or last >= road.nodes.size() or first == last:
		return ERR_INVALID_PARAMETER
	return _erase_gap(road, first, last)


## Erase the node and both incident spans, leaving a gap.
func erase_node(road: RoadData, index: int) -> Error:
	if not _has_road(road) or index < 0 or index >= road.nodes.size():
		return ERR_INVALID_PARAMETER
	return _erase_gap(road, index - 1, index + 1)


## Disconnect this junction anchor from other roads. Its geometry survives.
func erase_cross(road: RoadData, index: int) -> Error:
	if not _has_road(road) or index < 0 or index >= road.nodes.size():
		return ERR_INVALID_PARAMETER
	if _road_has_active_vehicle(road):
		return ERR_BUSY
	var node: RoadNode = road.nodes[index]
	var changed: bool = node.cross != null
	var empty_anchors: Array[RoadNode] = []
	if changed:
		_clear_cross(node)
	for other: RoadData in storage.get_all():
		if other == road:
			continue
		for anchor: RoadNode in other.nodes:
			if anchor.cross == null or anchor.position.distance_to(node.position) > RoadPathfinder.JOIN_TOLERANCE:
				continue
			if road.num in anchor.cross.connecting_roads:
				changed = true
				anchor.cross.connecting_roads.erase(road.num)
				if anchor.cross.connecting_roads.is_empty():
					empty_anchors.append(anchor)
	if not changed:
		return ERR_DOES_NOT_EXIST
	_prune_empty_crosses(empty_anchors)
	_publish_network_change()
	return OK


func _has_road(road: RoadData) -> bool:
	return road != null and storage._by_id.get(road.num) == road


func _erase_gap(road: RoadData, left_end: int, right_start: int) -> Error:
	if _road_has_dependencies(road):
		return ERR_BUSY
	if road.curve == null:
		road.build_curve()
	var source: Curve3D = road.curve
	if source.point_count != road.nodes.size():
		return ERR_INVALID_DATA
	var old_nodes: Array[RoadNode] = road.nodes
	var old_anchors: Array[RoadNode] = old_nodes.filter(func(node: RoadNode) -> bool:
		return node == old_nodes.front() or node == old_nodes.back() or node.cross != null)
	var view: RoadWay3D = storage._containers_by_id.get(road.num)
	var fragments: Array[RoadData] = []
	var surviving: Dictionary = {}
	for points: Vector2i in PathCurveUtils.ranges_after_erase(old_nodes.size(), left_end, right_start):
		var section: Curve3D = PathCurveUtils.copy_point_range(source, points, Vector3.ZERO)
		if section.get_baked_length() <= 0.0:
			continue
		var fragment: RoadData = road if fragments.is_empty() else RoadData.of(storage._max_num + 1, road.infr_type_key)
		fragment.track_name = road.track_name
		fragment.tag = road.tag
		fragment.autosmooth = road.autosmooth
		fragment.nodes = old_nodes.slice(points.x, points.y + 1)
		fragment.start_pos = fragment.nodes[0].position
		fragment.crosses = []
		for index: int in fragment.nodes.size():
			var node: RoadNode = fragment.nodes[index]
			node.parent_track = fragment
			node.index = index
			if node.cross != null:
				fragment.crosses.append(node.cross)
			surviving[node] = true
		fragment.curve = section
		fragments.append(fragment)
	for node: RoadNode in old_nodes:
		if not surviving.has(node):
			_clear_cross(node)
			node.parent_track = null
			node.index = -1
	if fragments.is_empty():
		storage.remove(road)
		road.nodes = []
		road.curve = null
	elif fragments.size() == 2:
		storage.add(fragments[1])
	_retarget_crosses(road.num, old_anchors, surviving)
	if not fragments.is_empty() and is_instance_valid(view):
		view.road = road
		if fragments.size() == 2:
			spawn_road(fragments[1])
	for fragment: RoadData in fragments:
		fragment.curve_built.emit(fragment.curve)
		fragment.track_changed.emit()
	_publish_network_change()
	return OK


## A cross references a road ID plus where the anchors meet. Reassign only
## links whose original anchor survives, including directional authored links.
func _retarget_crosses(old_num: int, anchors: Array[RoadNode], surviving: Dictionary) -> void:
	var empty_anchors: Array[RoadNode] = []
	for other: RoadData in storage.get_all():
		for node: RoadNode in other.nodes:
			if node.cross == null or old_num not in node.cross.connecting_roads:
				continue
			var links: Array[int] = node.cross.connecting_roads
			links.erase(old_num)
			for anchor: RoadNode in anchors:
				if anchor == node or not surviving.has(anchor) or node.position.distance_to(anchor.position) > RoadPathfinder.JOIN_TOLERANCE:
					continue
				var target: int = anchor.parent_track.num
				if target != other.num and target not in links:
					links.append(target)
			if links.is_empty():
				empty_anchors.append(node)
	_prune_empty_crosses(empty_anchors)


func _prune_empty_crosses(anchors: Array[RoadNode]) -> void:
	for anchor: RoadNode in anchors:
		var road: RoadData = anchor.parent_track
		# Endpoints remain routable without a cross resource. Interior anchors
		# still need one while another road names them as a junction.
		var is_endpoint: bool = anchor.index == 0 or anchor.index == road.nodes.size() - 1
		if is_endpoint or not _has_incoming_cross(anchor):
			_clear_cross(anchor)


func _has_incoming_cross(anchor: RoadNode) -> bool:
	for road: RoadData in storage.get_all():
		if road == anchor.parent_track:
			continue
		for node: RoadNode in road.nodes:
			if node.cross != null and anchor.parent_track.num in node.cross.connecting_roads \
					and node.position.distance_to(anchor.position) <= RoadPathfinder.JOIN_TOLERANCE:
				return true
	return false


func _clear_cross(node: RoadNode) -> void:
	if node.cross == null:
		return
	(node.parent_track as RoadData).crosses.erase(node.cross)
	node.cross.connecting_roads.clear()
	node.cross.parent_node = null
	node.cross = null


## Path-relative dependencies cannot be rebased safely by a topology edit.
func _road_has_dependencies(road: RoadData) -> bool:
	for marker: RoadMarkerData in markers.markers:
		if marker.road_num == road.num:
			return true
	if Managers.roads != self:
		return false
	if is_instance_valid(Managers.road_stops):
		for stop: RoadStationData in Managers.road_stops.stops:
			if stop.road_num == road.num:
				return true
	if is_instance_valid(Managers.depots):
		for depot: RoadDepotData in Managers.depots.road_depots:
			if depot.road_num == road.num:
				return true
	if is_instance_valid(Managers.vehicles):
		for vehicle: RoadVehicle3D in Managers.vehicles.road_vehicles:
			if not is_instance_valid(vehicle):
				continue
			if vehicle.plan_execution.references_road_nodes(road.num) \
					or (vehicle.route_plan != null and vehicle.route_plan.references_road_nodes(road.num)):
				return true
	return _road_has_active_vehicle(road)


func _road_has_active_vehicle(road: RoadData) -> bool:
	var view: RoadWay3D = storage._containers_by_id.get(road.num)
	if Managers.roads == self and is_instance_valid(view) and is_instance_valid(Managers.vehicles):
		for vehicle: RoadVehicle3D in Managers.vehicles.road_vehicles:
			if is_instance_valid(vehicle) and vehicle.uses_road(view):
				return true
	return false


func _publish_network_change() -> void:
	network_revision += 1
	network_changed.emit()
