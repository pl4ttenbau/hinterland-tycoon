## Converts unclaimed mouse input into world actions.
class_name WorldInteraction extends Node

signal pick_requested(screen_position: Vector2)
signal terrain_clicked(position: Vector3)

@export var entity_click_handler: BaseEntityClickHandler


func _unhandled_input(event: InputEvent) -> void:
	if UiState.is_world_input_blocked() or not event is InputEventMouseButton or event.pressed:
		return
	pick_requested.emit(event.position)
	SignalBus.mouse_click.emit(event)


func _on_world_picked(collider: Node3D, position: Vector3) -> void:
	if collider is Terrain3D:
		terrain_clicked.emit(position)
		get_viewport().set_input_as_handled()
		return
	if entity_click_handler.handle_click(collider):
		get_viewport().set_input_as_handled()
		return
	SignalBus.unhandled_collider_click.emit(collider)
