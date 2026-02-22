@icon("res://assets/icons/icon_station_white.png")
class_name NodeStationStore extends Resource

@export var _list: Array[RailNodeStationData] = []
@export var _by_id: Dictionary = {}
@export var _by_track: Dictionary = {}

@export_storage var _containers: Array[RailNodeStation3D] = []
@export_storage var _containers_by_id: Dictionary = {}

signal node_station_added(node_station: RailNodeStationData)
	
func _enter_tree() -> void:
	self.node_station_added.connect(Callable(self, "_node_station_added"))

#region Add Node Station
func add(node_station: RailNodeStationData):
	self._list.append(node_station)
	self._create_indexes(node_station)
	self.node_station_added.emit(node_station)
	
func add_container(outer_station: RailNodeStation3D):
	self._containers.append(outer_station)
	self._containers_by_id.set(outer_station.node_station.num, outer_station)
	
func _create_indexes(node_station: RailNodeStationData):
	self._by_id.set(node_station.num, node_station)
	# index by track num
	var track_num: int = node_station.parent_node.parent_track.num
	if self._by_track.has(track_num):
		var by_track_list: Array[RailNodeStationData] = self._by_track.get(track_num) as Array
		by_track_list.append(node_station)
		self._by_track.set(track_num, by_track_list)
	else:
		self._by_track.set(track_num, [node_station])
#endregion

#region Get Node Station
func get_all() -> Array[RailNodeStationData]:
	return self._list

func get_by_num(node_station_num: int) -> RailNodeStationData:
	var found: RailNodeStationData =  self._by_id.get(node_station_num)
	if ! found: Loggie.error("Cannot get node station %d; out of index?" % node_station_num)
	return found
	
func get_by_track(track_num: int) -> Array[RailNodeStationData]:
	var found: Array[RailNodeStationData] = self._by_track.get(track_num)
	if ! found: return []
	return found
	
func get_containers() -> Array[RailNodeStation3D]:
	return self._containers
	
func get_container_by_num(node_station_num: int) -> RailNodeStation3D:
	var found: RailNodeStation3D = self._containers_by_id.get(node_station_num, null)
	if ! found: Loggie.error("Cannot get RailNodeStation3D %d; out of index?" % node_station_num)
	return found
#endregion

#region Callbacks & Helpers 
func _on_node_station_added(node_station: RailNodeStationData):
	GlobalState.node_stations.append(node_station)
#endregion
