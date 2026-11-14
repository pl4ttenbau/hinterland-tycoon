extends Label

func _enter_tree() -> void:
	SignalBus.ui_update_tick.connect(Callable(self, "_on_ui_tick"))

func update() -> void:
	var player := GlobalState.player
	if is_instance_valid(player):
		var position := player.walking_position()
		self.text = "%.1f %.1f %.1f" % [position.x, position.y, position.z]

func _on_ui_tick() -> void:
	update()
