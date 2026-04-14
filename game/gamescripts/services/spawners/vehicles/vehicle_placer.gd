@icon("res://assets/icons/icon_locomotive_white.png")
class_name VehiclePlacer extends Node

@export var rail_containers: Array[RailTrack3D]
@export var trains: Array[Train3D] = []
@export var start_vehicles_spawned: bool = false

@export var player_train: Train3D

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
func spawn_train(veh_type_key: String, start_pos: VehicleStartPos) -> Train3D:
	var train3d := Train3D.of(veh_type_key, start_pos)
	self.add_child(train3d)
	# assign name and num
	train3d.name = "Train_%d" % train3d.num
	# add to own array and as child
	GlobalState.trains.append(train3d)
	self.trains.append(train3d)
	return train3d
#endregion

#region Enter & Exit
func enter_vehicle(veh3d: Vehicle3D):
	self.player_train = veh3d.train3d
	self.activate_cam(self.player_train.get_cam())
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	SignalBus.train_entered.emit(self.player_train)
	
func exit_train():
	SignalBus.train_exited.emit()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	self.activate_cam(GlobalState.player.cam)
	self.player_train = null

func activate_cam(cam: Camera3D):
	cam.make_current()
	GlobalState.active_cam = cam
	var terr3d := GlobalState.world_container.terrain
	if terr3d:
		terr3d.set_camera(cam)
	else:
		Loggie.warn("Terrain3D cannot be found for camera change")
#endregion

#region Callbacks
func _on_rails_rails_spawned(containers: Array[RailTrack3D]) -> void:
	Loggie.info("Rails spawned; initializing vehicles ...")
	self.rail_containers = containers
	load_vehicles()
#endregion
