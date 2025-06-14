class_name EnterAction extends Node

func on_trigger():
	if GlobalState.active_cam.get_meta("cam_name") == "CAM_PLAYER":
		var veh: RailVehicle = GlobalState.vehicles.get(0) as RailVehicle
		self.activate_cam(veh.get_cam())
	else:
		self.activate_cam(GlobalState.player.cam)

static func activate_cam(cam: Camera3D):
	cam.make_current()
	GlobalState.active_cam = cam
