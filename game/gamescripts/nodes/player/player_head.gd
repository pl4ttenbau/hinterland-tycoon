class_name PlayerHead extends VisibleObject

@onready var cam: Camera3D = $Camera3D
@onready var collider: CollisionShape3D = %Player/PlayerCollisionShape
@onready var area: Area3D = %Player/Area3D
	
func _ready() -> void:
	GlobalState.player = self
	GlobalState.active_cam = self.cam
