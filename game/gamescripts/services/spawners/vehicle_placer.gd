@icon("res://assets/icons/icon_locomotive_white.png")
class_name VehiclePlacer extends Node

@export_storage var _next_vehicle_num = 0
@export var rail_containers: Array[OuterRailTrack]
@export var rail_vehicles: Array[RailVehicle] = []

func _enter_tree() -> void:
	Managers.vehicles = self
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
	self.spawn_vehicle(track_num, 0)
	
func spawn_vehicle(track_num: int, node_index: int) -> RailVehicle:
	var veh: RailVehicle = RailVehicle.of(get_rail_path(track_num), 0)
	self.add_child(veh)
	# assign name and num
	veh.vehicle_num = self.get_next_vehicle_num()
	veh.name = "RailVehicle_%d" % veh.vehicle_num
	# add to own array and as child
	GlobalState.vehicles.append(veh)
	self.rail_vehicles.append(veh)
	return veh

func get_next_vehicle_num() -> int:
	self._next_vehicle_num += 1
	return self._next_vehicle_num

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
