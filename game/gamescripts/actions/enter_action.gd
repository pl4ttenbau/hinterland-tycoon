class_name EnterAction extends BaseAction

func on_trigger():
	super.on_trigger()
	if GlobalState.active_cam.get_meta("cam_name") == "CAM_PLAYER":
		self.enter_train()
	else:
		self.exit_train()

static func activate_cam(cam: Camera3D):
	cam.make_current()
	GlobalState.active_cam = cam
	GlobalState.world_container.terrain.set_camera(cam)
	
func enter_train():
	Loggie.info("Entering train..")
	var train3d := GlobalState.trains.get(0) as Train3D
	if ! train3d:
		Loggie.error("Cannot get into vehicle: none found on map")
		return
	self.activate_cam(train3d.get_cam())
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	SignalBus.player_entered_train.emit(train3d)
	
func exit_train():
	Loggie.info("Leaving train..")
	SignalBus.player_exited_train.emit()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# position player by vehicle
	var player: BasicFpsPlayer = GlobalState.player.player_parent
	var veh_pos: Vector3 = GlobalState.active_cam.global_position
	var pos_by_vehicle: Vector3 = veh_pos + Vector3(12, -1, 0)
	player.global_position = pos_by_vehicle
	
	# activate player cam again
	self.activate_cam(GlobalState.player.cam)
