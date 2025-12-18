@icon("res://assets/icons/icon_locomotive_white.png")
class_name VehiclePlacer extends Node

@export_storage var _next_vehicle_num = 0
@export var rail_containers: Array[RailTrack3D]
@export var rail_vehicles: Array[RailVehicle3D] = []
@export var start_vehicles_spawned: bool = false

func _enter_tree() -> void:
	Managers.vehicles = self
	SignalBus.rails_spawned.connect(Callable(self, "_on_rails_rails_spawned"))
	
func _check_rails_and_terrain() -> bool:
	if !GlobalState:
		push_warning("Cannot save vehicle in scnene: Globals not found")
		return false
	if !rail_containers:
		push_warning("RailContainers not loaded; aboring vehicle creation")
		return false
	return true
	
func load_vehicles():
	var all_loaded: bool = self._check_rails_and_terrain()
	if  !all_loaded: return
	Loggie.info("Globals & rails found: initializing vehicles...")

	self.start_vehicles_spawned = true
	
func spawn_vehicle(veh_type_key: String, start_pos: VehicleStartPos) -> RailVehicle3D:
	var veh_3d := RailVehicle3D.of(veh_type_key, start_pos)
	self.add_child(veh_3d)
	# assign name and num
	veh_3d.vehicle_num = self.get_next_vehicle_num()
	veh_3d.name = "RailVehicle_%d" % veh_3d.vehicle_num
	# add to own array and as child
	GlobalState.vehicles.append(veh_3d)
	self.rail_vehicles.append(veh_3d)
	return veh_3d

func get_next_vehicle_num() -> int:
	self._next_vehicle_num += 1
	return self._next_vehicle_num

func _on_rails_rails_spawned(containers: Array[RailTrack3D]) -> void:
	Loggie.info("Rails spawned; initializing vehicles ...")
	self.rail_containers = containers
	load_vehicles()
