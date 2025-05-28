class_name StationsHolder extends Node

@export var stations: Array[RailStation] = []

func _enter_tree() -> void:
	SignalBus.rails_spawned.connect(Callable(self, "_on_rails_rails_spawned"))

func spawn_stations():
	Loggie.info("Spawning stations..")
	for station_obj: RailStation in GlobalState.stations:
		var container: OuterRailStation = station_obj.spawn()
		self.add_child(container, true)
		container.rotate_to_prev_node()
		container.rotate(Vector3(0, 1, 0), 90)
	SignalBus.stations_spawned.emit()
	
func _on_rails_rails_spawned(_rails: Array[OuterRailTrack]) -> void:
	spawn_stations()
