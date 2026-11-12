class_name EnterAction extends BaseAction

func on_trigger():
	super.on_trigger()
	if Managers.vehicles != null and Managers.vehicles.player_road_vehicle != null:
		Managers.vehicles.exit_road_vehicle()
		return
	if not is_instance_valid(GlobalState.player):
		return
	if not is_instance_valid(GlobalState.player.in_train):
		self.enter_train()
	else:
		self.exit_train()

static func activate_cam(cam: Camera3D):
	cam.make_current()
	GlobalState.active_cam = cam
	if is_instance_valid(GlobalState.world_container) and is_instance_valid(GlobalState.world_container.terrain):
		GlobalState.world_container.terrain.set_camera(cam)
	
func enter_train():
	Loggie.info("Entering train..")
	var train3d: Train3D
	for candidate: Train3D in GlobalState.trains:
		if is_instance_valid(candidate):
			train3d = candidate
			break
	if ! train3d:
		Loggie.error("Cannot get into vehicle: none found on map")
		return
	if is_instance_valid(Managers.vehicles):
		Managers.vehicles.player_train = train3d
	self.activate_cam(train3d.get_cam())
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	SignalBus.player_entered_train.emit(train3d)
	
func exit_train():
	Loggie.info("Leaving train..")
	if is_instance_valid(Managers.vehicles):
		Managers.vehicles.player_train = null
	SignalBus.player_exited_train.emit()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# position player by vehicle
	var player: BasicFpsPlayer = GlobalState.player.player_parent
	var veh_pos: Vector3 = GlobalState.active_cam.global_position
	var pos_by_vehicle: Vector3 = veh_pos + Vector3(12, -1, 0)
	player.global_position = pos_by_vehicle
	
	# activate player cam again
	self.activate_cam(GlobalState.player.cam)
