class_name PlayerHead extends Node3D

@onready var cam: Camera3D = $Camera3D
@onready var collider: CollisionShape3D = %Player/PlayerCollisionShape
@onready var area: Area3D = %Player/Area3D
	
func _ready() -> void:
	GlobalState.player = self
	# register signals
	self.area.input_event.connect(Callable(self, "_on_player_input"))

func _on_player_input(camera, event: InputEvent, event_position: Vector3, normal, shape_idx):
	Loggie.info(JSON.stringify(event))
	self.player_input.emit(event, event_position)
