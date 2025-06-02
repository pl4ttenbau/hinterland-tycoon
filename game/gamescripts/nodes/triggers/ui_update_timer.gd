extends Timer

func _enter_tree() -> void:
	self.timeout.connect(Callable(self, "_on_timer_timeout"))

func _on_timer_timeout():
	SignalBus.ui_update_tick.emit()
