extends Label

@onready var player: Node3D = %Player

func _enter_tree() -> void:
	SignalBus.ui_update_tick.connect(Callable(self, "_on_ui_tick"))

func update() -> void:
	if (player):
		var playerPos: Vector3 = player.global_position
		self.text = "%.1f %.1f %.1f" % [playerPos.x, playerPos.y, playerPos.z]

func _on_ui_tick() -> void:
	update()
