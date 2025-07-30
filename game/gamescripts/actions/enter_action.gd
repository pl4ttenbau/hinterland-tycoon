class_name EnterAction extends Node

func on_trigger():
	if GlobalState.active_cam.get_meta("cam_name") == "CAM_PLAYER":
		self.enter_vehicle()
	else:
		self.exit_vehicle()

static func activate_cam(cam: Camera3D):
	cam.make_current()
	GlobalState.active_cam = cam
	
func enter_vehicle():
	var veh := GlobalState.vehicles.get(0) as RailVehicle
	if ! veh:
		Loggie.error("Cannot get into vehicle: none found on map")
		return
	self.activate_cam(veh.get_cam())
	SignalBus.vehicle_entered.emit(veh)
	
func exit_vehicle():
	SignalBus.vehicle_exited.emit()
	self.activate_cam(GlobalState.player.cam)
