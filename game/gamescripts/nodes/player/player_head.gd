class_name PlayerHead extends VisibleObject

@onready var cam: Camera3D = $Camera3D
@onready var collider: CollisionShape3D = %Player/PlayerCollisionShape
@onready var area: Area3D = $"../PlayerArea"

const SPAWN_OFFSET = Vector3(0, 1, 0)

func _enter_tree() -> void:
	SignalBus.map_spawned.connect(Callable(self, "_on_map_spawned"))
	
func _ready() -> void:
	GlobalState.player = self
	GlobalState.active_cam = self.cam
	
func place_to_map_start():
	if GlobalState.loaded_map && GlobalState.loaded_map.start_pos_xz:
		var spawn_pos = WorldUtils.pos_on_map(GlobalState.loaded_map.start_pos_xz)
		self.get_parent_node_3d().position = spawn_pos + SPAWN_OFFSET
		
static func get_cam_pos() -> Vector3:
	if GlobalState.active_cam != null:
		return GlobalState.active_cam.global_position
	return GlobalState.player.global_position
	
func _on_map_spawned(_terrain: TerrainContainer):
	self.place_to_map_start()
