extends Timer

func _ready() -> void:
	self.timeout.connect(Callable(self, "_on_timer_timeout"))

func _on_timer_timeout():
	SignalBus.world_update.emit()
