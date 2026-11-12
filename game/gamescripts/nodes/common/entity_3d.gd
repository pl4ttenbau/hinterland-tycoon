## View-class for GameEntityData
@tool
class_name GameEntity3D extends Node3D

@export var entity: GameEntityData


func _init() -> void:
	if Engine.is_editor_hint():
		child_order_changed.connect(update_configuration_warnings)


func _get_configuration_warnings() -> PackedStringArray:
	return Constructable3D.missing_warning(self) if _requires_constructable() else PackedStringArray()


func _requires_constructable() -> bool:
	return false
