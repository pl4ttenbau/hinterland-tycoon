@icon("res://assets/icons/icon_locomotive_white.png")
class_name VehiclePlacer extends Node

@export var rail_containers: Array[OuterRailTrack]

func _enter_tree() -> void:
	SignalBus.rails_spawned.connect(Callable(self, "_on_rails_rails_spawned"))

func _ready() -> void:
	load_vehicles()
	
func load_vehicles():
	if !GlobalState:
		push_warning("Cannot save vehicle in scnene: Globals not found")
		return
	if !rail_containers:
		push_warning("RailContainers not loaded; aboring vehicle creation")
		return
	Loggie.info("Globals & rails found: initializing vehicles...")
	var track_num: int = 2
	var veh: RailVehicle = RailVehicle.of(get_rail_path(track_num), 0)
	self.add_child(veh)

func get_rail_path(_num: int) -> OuterRailTrack:
	var track_num: int = _num -1
	var container: OuterRailTrack = self.rail_containers.get(track_num)
	if (!container):
		push_error("Cannot get rail path: container not loaded")
		return null
	return container

func _on_rails_rails_spawned(containers: Array[OuterRailTrack]) -> void:
	Loggie.info("Rails spawned; initializing vehicles ...")
	self.rail_containers = containers
	# load_vehicles()
