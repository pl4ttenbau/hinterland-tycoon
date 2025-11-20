@icon("res://assets/icons/icon_gears_white.png")
class_name StationResidencesConnector extends Node

@export var has_stations_loaded: bool = false
@export var has_buildings_placed: bool = false
@export var has_made_initial_connections: bool = false

func _enter_tree() -> void:
	SignalBus.stations_loaded.connect(Callable(self, "_on_stations_loaded"))
	SignalBus.town_buildings_spawned.connect(Callable(self, "_on_residences_placed"))
	
func connect_stations_to_residences():
	if !self.has_buildings_placed || !self.has_stations_loaded: return
	if self.has_made_initial_connections: return
	Loggie.info("Connecting stations to residences..")
	self.has_made_initial_connections = true
	
func _on_stations_loaded(_stations: Array[RailStationData]):
	self.has_stations_loaded = true
	self.connect_stations_to_residences()
	
func _on_residences_placed():
	self.has_buildings_placed = true
	self.connect_stations_to_residences()
