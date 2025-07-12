extends Label

func _enter_tree() -> void:
	SignalBus.ui_update_tick.connect(Callable(self, "_on_ui_tick"))

func update() -> void:
	self.text = str(Engine.get_frames_per_second())

func _on_ui_tick() -> void:
	update()
