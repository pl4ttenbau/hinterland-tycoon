extends WorldEnvironment
## The saved environment stays clear for map editing; fog is enabled on Play.

func _ready() -> void:
	if Engine.is_editor_hint() or environment == null:
		return
	# Keep runtime changes separate from the shared authoring resource.
	environment = environment.duplicate() as Environment
	environment.fog_enabled = true
