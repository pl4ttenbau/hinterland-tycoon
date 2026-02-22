class_name HideableObject extends VisibleObject

const HIDING_DISTANCE: float = 200

@export_storage var dist2cam: float

func _ready() -> void:
	SignalBus.world_update.connect(Callable(self, "_on_map_tick"))
	
func _on_map_tick():
	if ! GlobalState.player: return
	self.dist2cam = get_cam_pos().distance_to(self.global_position)
	self.visible = self.dist2cam <= HIDING_DISTANCE

func get_cam_pos() -> Vector3:
	if GlobalState.active_cam != null:
		return GlobalState.active_cam.global_position
	return GlobalState.player.global_position
