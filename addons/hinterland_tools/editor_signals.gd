@tool
extends Node

static var instance: Node

## Cache Inspector actions request persistence; the plugin owns the handler.
signal infrastructure_save_requested(cache: Node3D, domain: int)

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

## Emitted by map-editing tools after a terrain click has been resolved in world space.
signal terrain_clicked(position: Vector3)
