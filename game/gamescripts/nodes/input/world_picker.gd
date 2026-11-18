## Resolves a screen position using the viewport's current camera.
@icon("res://assets/icons/icon_mouse_white.png")
class_name WorldPicker extends Node

signal picked(collider: Node3D, position: Vector3)

const RAY_LENGTH: float = 300.0


func pick(screen_position: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		return
	var origin := camera.project_ray_origin(screen_position)
	var endpoint := origin + camera.project_ray_normal(screen_position) * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(origin, endpoint)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	var collider := hit.get("collider") as Node3D
	if is_instance_valid(collider):
		picked.emit(collider, hit.position)
