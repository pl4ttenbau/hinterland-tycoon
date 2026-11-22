@tool
## Plugin-owned signals shared by editor toolbar, viewport tools and cache actions.
class_name HinterlandEditorSignals extends Node

static var instance: Node

## Cache Inspector actions request persistence; the plugin owns the handler.
signal infrastructure_save_requested(cache: Node3D, domain: int)
## A single line's "Save Single" button: write just that line's record, adding or replacing it.
signal infrastructure_line_save_requested(line: Node3D)

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

## Emitted by map-editing tools after a terrain click has been resolved in world space.
signal terrain_clicked(position: Vector3)
