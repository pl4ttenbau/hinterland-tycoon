extends Label

func _enter_tree() -> void:
	SignalBus.ui_update_tick.connect(Callable(self, "_on_ui_tick"))

func update() -> void:
	var player := GlobalState.player
	if is_instance_valid(player):
		var player_pos: Vector3 = player.walking_position()
		self.text = "%.1f %.1f %.1f" % [player_pos.x, player_pos.y, player_pos.z]

func _on_ui_tick() -> void:
	update()
