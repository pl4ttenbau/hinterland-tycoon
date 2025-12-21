extends MarginContainer

func _enter_tree() -> void:
	# connect to signals
	SignalBus.vehicle_entered.connect(Callable(self, "_on_vehicle_entered"))
	SignalBus.vehicle_exited.connect(Callable(self, "_on_vehicle_exited"))
	
#region Callbacks
func _on_vehicle_entered(_vehicle3d: PathedVehicle3D):
	self.visible = true

func _on_vehicle_exited():
	self.visible = false
#endregion
