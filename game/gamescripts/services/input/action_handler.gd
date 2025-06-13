@icon("res://assets/icons/icon_input_white.png")
class_name ActionHandler extends Node

func _enter_tree() -> void:
	SignalBus.action_menu_triggered.connect(Callable(self, "_on_action_triggered"))
	
func _on_action_triggered(item: ActionMenuItem) -> bool:
	Loggie.info("Action Selected: %s" % item.get_action_name())
	if item.get_action_name() == "Enter":
		self._enter_or_exit_vehicle()
	return true

func _enter_or_exit_vehicle() -> void:
	if GlobalState.active_cam.get_meta("cam_name") == "CAM_PLAYER":
		var veh: RailVehicle = GlobalState.vehicles.get(0) as RailVehicle
		self.activate_cam(veh.get_cam())
	else:
		self.activate_cam(GlobalState.player.cam)
		

func activate_cam(cam: Camera3D):
	cam.make_current()
	GlobalState.active_cam = cam
