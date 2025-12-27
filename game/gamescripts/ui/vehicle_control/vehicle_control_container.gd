extends MarginContainer

func _enter_tree() -> void:
	# connect to signals
	SignalBus.train_entered.connect(Callable(self, "_on_train_entered"))
	SignalBus.train_exited.connect(Callable(self, "_on_train_exited"))
	
#region Callbacks
func _on_train_entered(_vehicle3d: Train3D):
	self.visible = true

func _on_train_exited():
	self.visible = false
#endregion
