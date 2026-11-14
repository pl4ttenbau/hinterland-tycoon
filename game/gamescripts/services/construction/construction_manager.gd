## Shared terrain picking and placement checks for the current world session.
class_name ConstructionManager extends Node

const NON_BLOCKING_GROUP := &"construction_non_blocking"


func terrain_hit(terrain: Terrain3D, camera: Camera3D, cursor: Vector2) -> Vector3:
	if not is_instance_valid(terrain) or camera == null or terrain.data == null:
		return Vector3.INF
	# Query terrain directly so the preview can follow the cursor past existing structures.
	var hit: Vector3 = terrain.get_intersection(camera.project_ray_origin(cursor), camera.project_ray_normal(cursor))
	return hit if _has_ground(terrain.data, hit) else Vector3.INF


## The candidate can stay off-tree. The proposed transform places its root in world space.
func site_error(world: WorldMapScene, building: Node3D, proposed: Transform3D) -> String:
	if not is_instance_valid(world) or world != GlobalState.world_container or not is_instance_valid(world.terrain):
		return "The selected site is unavailable."
	if not _has_ground(world.terrain.data, proposed.origin):
		return "Select a site on the terrain."
	if not is_instance_valid(building):
		return "The building is unavailable."

	var component := Constructable3D.find_on(building)
	var footprint: CollisionShape3D = component.placement_shape if component != null else null
	if footprint == null or footprint.shape == null:
		return "The building is missing its placement shape."

	# Compose local transforms up to the root. Global transforms require a live scene.
	var local := Transform3D.IDENTITY
	var part: Node = footprint
	while part != building and part is Node3D and not part.top_level:
		local = part.transform * local
		part = part.get_parent()
	if part != building:
		return "The placement shape must follow the building's transform."

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = footprint.shape
	query.transform = proposed * local
	# Terrain can fill the query's result limit with heightfield contacts.
	var terrain_collision := world.terrain.get_collision()
	if terrain_collision != null:
		query.exclude = [terrain_collision.get_rid()]
	var space: PhysicsDirectSpaceState3D = world.terrain.get_world_3d().direct_space_state
	for hit: Dictionary in space.intersect_shape(query):
		var collider: Object = hit.collider
		if collider is StaticBody3D and not collider.is_in_group(NON_BLOCKING_GROUP):
			return "The building would overlap an existing structure."
	return ""


static func _has_ground(data: Terrain3DData, position: Vector3) -> bool:
	return data != null and position.is_finite() and data.has_regionp(position) \
		and not data.get_control_hole(position)
