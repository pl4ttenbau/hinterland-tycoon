class_name StationsHolder extends Node

@export var stations: Array[RailStationResource] = []
@export_storage var _next_station_num: int = 0

func _enter_tree() -> void:
	SignalBus.rails_spawned.connect(Callable(self, "_on_rails_rails_spawned"))

## Station objects are created with the rail tracks, but instanciated one by one here
func spawn_stations():
	Loggie.info("Spawning stations..")
	for station_obj: RailStationResource in GlobalState.stations:
		var container: OuterRailStation = spawn_station(station_obj)
		container.rotate_to_prev_node()
		container.rotate(Vector3(0, 1, 0), 90)
	SignalBus.stations_spawned.emit()
	
func spawn_station(station_obj: RailStationResource) -> OuterRailStation:
	station_obj.num = self.get_next_station_num()
	var container: OuterRailStation = station_obj.spawn()
	container._name_nodes()
	self.add_child(container, true)
	return container
	
func _on_rails_rails_spawned(_rails: Array[OuterRailTrack]) -> void:
	spawn_stations()

func get_next_station_num() -> int:
	self._next_station_num += 1
	return self._next_station_num
