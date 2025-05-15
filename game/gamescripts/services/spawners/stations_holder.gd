class_name StationsHolder extends Node3D

@export var stations: Array[RailStation] = []

func spawn_stations():
	Loggie.info("Spawning stations..")
	for station in GlobalState.stations:
		var container: Node3D = station.spawn()
		self.add_child(container, true)

func _on_scene_ready() -> void:
	pass
	
func _on_rails_rails_spawned(_rails: Array[OuterRailTrack]) -> void:
	spawn_stations()
