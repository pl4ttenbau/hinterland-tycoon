extends MarginContainer

func _enter_tree() -> void:
	# connect to signals
	SignalBus.train_entered.connect(Callable(self, "_on_train_entered"))
	SignalBus.train_exited.connect(Callable(self, "_on_train_exited"))
	# make initially invisible
	self._set_enabled(false)
	
func _set_enabled(enabled: bool):
	self.set_process_input(enabled)
	self.set_process(enabled)
	self.visible = enabled
	
#region Callbacks
func _on_train_entered(_vehicle3d: Train3D):
	self._set_enabled(true)
	self.process_mode = Node.PROCESS_MODE_INHERIT

func _on_train_exited():
	self._set_enabled(false)
#endregion
