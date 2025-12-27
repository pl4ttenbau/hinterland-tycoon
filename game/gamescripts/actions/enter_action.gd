class_name EnterAction extends Node

func on_trigger():
	if GlobalState.active_cam.get_meta("cam_name") == "CAM_PLAYER":
		self.enter_train()
	else:
		self.exit_train()

static func activate_cam(cam: Camera3D):
	cam.make_current()
	GlobalState.active_cam = cam
	GlobalState.world_container.terrain.set_camera(cam)
	
func enter_train():
	var veh := GlobalState.trains.get(0) as Train3D
	if ! veh:
		Loggie.error("Cannot get into vehicle: none found on map")
		return
	self.activate_cam(veh.get_cam())
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	SignalBus.train_entered.emit(veh)
	
func exit_train():
	SignalBus.train_exited.emit()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	self.activate_cam(GlobalState.player.cam)
