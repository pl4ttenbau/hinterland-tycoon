class_name VehiclePlacer extends Node3D

@export var rail_containers: Array[OuterRailTrack]

func _ready() -> void:
	load_vehicles()
	
func load_vehicles():
	if !GlobalState:
		push_warning("Cannot save vehicle in scnene: Globals not found")
		return
	if !rail_containers:
		push_warning("RailContainers not loaded; aboring vehicle creation")
		return
	print("Globals & rails found: initializing vehicles...")
	var track_num: int = 4
	var veh: RailVehicle = RailVehicle.of(get_rail_path(track_num), 0)
	self.add_child(veh)

func get_rail_path(_num: int) -> OuterRailTrack:
	var container: OuterRailTrack = self.rail_containers.get(_num)
	if (!container):
		push_error("Cannot get rail path: container not loaded")
		return null
	return container

func _on_rails_rails_spawned(_rails: Array[OuterRailTrack]) -> void:
	Loggie.info("Rails spawned; initializing vehicles ...")
	self.rail_containers = _rails
	# load_vehicles()
