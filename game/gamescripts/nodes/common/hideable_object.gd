class_name HideableObject extends VisibleObject

const HIDING_DISTANCE: float = 200

@export_storage var dist2cam: float

func _ready() -> void:
	SignalBus.world_update.connect(Callable(self, "_on_map_tick"))
	
func _on_map_tick():
	var player: PlayerHead = GlobalState.player
	if !player: return
	var player_g_pos: Vector3 = player.global_position
	var own_g_pos: Vector3 = self.global_position
	self.dist2cam = player_g_pos.distance_to(own_g_pos)
	if self.dist2cam <= HIDING_DISTANCE:
		self.visible = true
	else:
		self.visible = false
