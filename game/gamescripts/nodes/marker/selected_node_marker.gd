class_name SelectedNodeMarker3D extends Node3D

func _ready() -> void:
	%DestroyAgainTimer.timeout.connect(Callable(self, "_destroy_again"))
	
func _destroy_again():
	self.queue_free()
