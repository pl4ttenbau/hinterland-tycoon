@icon("res://assets/icons/icon_locomotive_white.png")
class_name VehiclePlacer extends Node

@export var rail_containers: Array[RailTrack3D]
@export var rail_vehicles: Array[Train3D] = []
@export var start_vehicles_spawned: bool = false

#region Initialization
func _enter_tree() -> void:
	Managers.vehicles = self
	SignalBus.rails_spawned.connect(Callable(self, "_on_rails_rails_spawned"))
	
func _check_rails_and_terrain() -> bool:
	if !GlobalState:
		push_warning("Cannot save vehicle in scene: Globals not found")
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
#endregion

#region Vehicle Spawning
func spawn_vehicle(veh_type_key: String, start_pos: VehicleStartPos) -> Train3D:
	var train3d := Train3D.of(veh_type_key, start_pos)
	self.add_child(train3d)
	# assign name and num
	train3d.name = "Train_%d" % train3d.num
	# add to own array and as child
	GlobalState.vehicles.append(train3d)
	self.rail_vehicles.append(train3d)
	return train3d
#endregion

#region Callbacks
func _on_rails_rails_spawned(containers: Array[RailTrack3D]) -> void:
	Loggie.info("Rails spawned; initializing vehicles ...")
	self.rail_containers = containers
	load_vehicles()
#endregion
