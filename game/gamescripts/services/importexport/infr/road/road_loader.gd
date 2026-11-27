@icon("res://assets/icons/icon_road_white.png")
class_name RoadsLoader extends AbstractInfrLineLoader

const JSON_PATH_FORMAT = "res://world/%s/jsondata/roads.json"
const NODES_GROUP = "Roads"
const MAX_VISIBLE_DIST := 200

@export var storage: RoadStore = RoadStore.new()
@export var markers: RoadMarkerStore = RoadMarkerStore.new()

func _ready() -> void:
	var tool: Node = load("res://game/gamescripts/nodes/marker/road_marker_tool.gd").new()
	tool.roads = self
	add_child(tool)

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

## Disconnect this junction anchor from other roads. Its geometry survives.
func erase_cross(road: RoadData, index: int) -> Error:
	if not _has_line(road) or not road.has_node_index(index):
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


#region Split hooks
func _store() -> AbstractInfrLineStore:
	return storage


func _new_line() -> AbstractInfrLine:
	return RoadData.new()


func _spawn_view(track: AbstractInfrLine) -> void:
	spawn_road(track)


func _split_blocker(track: AbstractInfrLine) -> Error:
	return ERR_BUSY if _road_has_dependencies(track) else OK


func _copy_line_fields(fragment: AbstractInfrLine, source: AbstractInfrLine) -> void:
	super(fragment, source)
	(fragment as RoadData).autosmooth = (source as RoadData).autosmooth


func _init_fragment(fragment: AbstractInfrLine, _cut_start: bool, _cut_end: bool) -> void:
	var road := fragment as RoadData
	road.crosses.clear()
	for node: RoadNode in road.nodes:
		if node.cross != null:
			road.crosses.append(node.cross)


func _relink(split: AbstractInfrLineLoader.Split) -> void:
	var old_nodes: Array = split.old_nodes
	# Collect before the erased nodes drop their crosses.
	var old_anchors: Array[RoadNode] = []
	for node: RoadNode in old_nodes:
		if node == old_nodes.front() or node == old_nodes.back() or node.cross != null:
			old_anchors.append(node)
	for node: RoadNode in split.removed_nodes():
		_clear_cross(node)
	_retarget_crosses(split.line.num, old_anchors, split.surviving)
#endregion


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
				var target: int = anchor.parent_line.num
				if target != other.num and target not in links:
					links.append(target)
			if links.is_empty():
				empty_anchors.append(node)
	_prune_empty_crosses(empty_anchors)


func _prune_empty_crosses(anchors: Array[RoadNode]) -> void:
	for anchor: RoadNode in anchors:
		var road: RoadData = anchor.parent_line
		# Endpoints remain routable without a cross resource. Interior anchors
		# still need one while another road names them as a junction.
		var is_endpoint: bool = anchor.index == 0 or anchor.index == road.nodes.size() - 1
		if is_endpoint or not _has_incoming_cross(anchor):
			_clear_cross(anchor)


func _has_incoming_cross(anchor: RoadNode) -> bool:
	for road: RoadData in storage.get_all():
		if road == anchor.parent_line:
			continue
		for node: RoadNode in road.nodes:
			if node.cross != null and anchor.parent_line.num in node.cross.connecting_roads \
					and node.position.distance_to(anchor.position) <= RoadPathfinder.JOIN_TOLERANCE:
				return true
	return false


func _clear_cross(node: RoadNode) -> void:
	if node.cross == null:
		return
	(node.parent_line as RoadData).crosses.erase(node.cross)
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
	var view: RoadWay3D = storage.find_container(road.num)
	if Managers.roads == self and is_instance_valid(view) and is_instance_valid(Managers.vehicles):
		for vehicle: RoadVehicle3D in Managers.vehicles.road_vehicles:
			if is_instance_valid(vehicle) and vehicle.uses_road(view):
				return true
	return false


func _publish_network_change() -> void:
	network_revision += 1
	network_changed.emit()
