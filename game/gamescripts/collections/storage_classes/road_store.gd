@icon("res://assets/icons/icon_road_white.png")
class_name RoadStore extends Resource

@export var _list: Array[RoadData] = []
@export var _by_id: Dictionary = {}
@export var _max_num: int = -1

@export_storage var _containers: Array[RoadWay3D] = []
@export_storage var _containers_by_id: Dictionary = {}

signal road_added(road_obj: RoadData)
	
func _enter_tree() -> void:
	self.road_added.connect(Callable(self, "_on_road_loaded"))

#region Add road
func add(road_obj: RoadData):
	self._list.append(road_obj)
	self._create_indexes(road_obj)
	_max_num = maxi(_max_num, road_obj.num)
	self.road_added.emit(road_obj)
	GlobalState.roads.append(road_obj)
	
func add_container(outer_road: RoadWay3D):
	self._containers.append(outer_road)
	self._containers_by_id.set(outer_road.road.num, outer_road)
	
func _create_indexes(road_obj: RoadData):
	self._by_id.set(road_obj.num, road_obj)
#endregion

## Remove the indexes and detach the view immediately so it stops colliding.
func remove(road: RoadData) -> void:
	if _by_id.get(road.num) != road:
		return
	_list.erase(road)
	_by_id.erase(road.num)
	GlobalState.roads.erase(road)
	var view: RoadWay3D = _containers_by_id.get(road.num)
	_containers_by_id.erase(road.num)
	if is_instance_valid(view):
		_containers.erase(view)
		GlobalState.outer_roads.erase(view)
		if view.get_parent() != null:
			view.get_parent().remove_child(view)
		view.queue_free()


#region Get Rail roads
func get_all() -> Array[RoadData]:
	return self._list

func get_by_num(road_num: int) -> RoadData:
	var found: RoadData =  self._by_id.get(road_num)
	if ! found: Loggie.error("Cannot get road %d; out of index?" % road_num)
	return found
	
func get_by_name(road_name: StringName) -> RoadData:
	return self._by_name.get(road_name)
	
func get_containers() -> Array[RoadWay3D]:
	return self._containers
	
func get_container_by_num(road_num: int) -> RoadWay3D:
	var found: RoadWay3D = self._containers_by_id.get(road_num, null)
	if ! found: Loggie.error("Cannot get RoadWay3D %d; out of index?" % road_num)
	return found
#endregion

#region Callbacks & Helpers 
func _on_road_loaded(road_obj: RoadData):
	GlobalState.roads.append(road_obj)
#endregion
