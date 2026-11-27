@icon("res://assets/icons/icon_road_white.png")
class_name RoadStore extends AbstractInfrLineStore

@export var _list: Array[RoadData] = []
@export_storage var _containers: Array[RoadWay3D] = []

func _lines() -> Array:
	return self._list

func _views() -> Array:
	return self._containers

func _kind_name() -> String:
	return "road"

#region Get Roads
func get_all() -> Array[RoadData]:
	return self._list

func get_containers() -> Array[RoadWay3D]:
	return self._containers
#endregion
