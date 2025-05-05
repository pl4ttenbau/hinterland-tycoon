extends Label

@onready var player: Node3D = %Player

func update() -> void:
	if (player):
		var playerPos: Vector3 = player.global_position
		self.text = "%.1f %.1f %.1f" % [playerPos.x, playerPos.y, playerPos.z]


func _on_ui_update_timer_timeout() -> void:
	update()
