@tool
@icon("res://assets/icons/nodes_3d/icon_mouse.svg")
class_name WorldCursor3D extends Marker3D

@export_tool_button("Put On Ground")
var put_on_ground = Callable(self, "_do_put_on_ground")

@export_tool_button("Copy Pos As Json")
var copy_pos_as_json = Callable(self, "_do_copy_pos_as_json")

@export_group("GPS", "gps_")
## Decimal degrees in latitude, longitude order, e.g. 54.21463, 19.11508.
@export var gps_coords: String

@export_tool_button("From GPS Coords", "Callable")
var gps_apply_fromcoords = do_apply_gps_coords_pos

func _do_put_on_ground() -> void:
	var terrain: Terrain3D = get_editor_terrain()
	if terrain == null or terrain.data == null:
		return
	var height: float = terrain.data.get_height(global_position)
	if not is_finite(height):
		Loggie.warn("Cannot place cursor: no terrain at this position")
		return
	global_position.y = height

func _do_copy_pos_as_json() -> void:
	var abs_pos: Vector3 = global_position
	var abs_pos_float_arr: Array[float] = [
		snapped(abs_pos.x, 0.01),
		snapped(abs_pos.y, 0.01),
		snapped(abs_pos.z, 0.01)
	]
	var abs_pos_arr_str: String = JSON.stringify(abs_pos_float_arr)
	Loggie.info("WorldCursor Pos: %s" % abs_pos_arr_str)
	DisplayServer.clipboard_set(abs_pos_arr_str)

func do_apply_gps_coords_pos() -> void:
	var coords: Array[float] = WorldUtils.gps_coords_str_to_float_arr(gps_coords)
	if coords.size() != 2:
		return
	var size_and_pos: MapSizeAndPosData = get_map_size_pos_dto_in_editor()
	var map_xz: Vector2 = WorldUtils.gps_coords_to_map_pos(coords, size_and_pos)
	if not map_xz.is_finite():
		return
	var terrain: Terrain3D = get_editor_terrain()
	if terrain == null or terrain.data == null:
		return
	# rasterOffset is in sample coordinates, like Terrain3D's import_position.
	var world_xz: Vector2 = map_xz * terrain.vertex_spacing
	var target := Vector3(world_xz.x, 0.0, world_xz.y)
	var height: float = terrain.data.get_height(target)
	if not is_finite(height):
		Loggie.warn("Cannot place cursor: GPS position is outside imported terrain")
		return
	target.y = height
	global_position = target
	Loggie.info("GPS cursor position: %v" % target)

func _get_world_map() -> WorldMapScene:
	var node: Node = self
	while node != null:
		if node is WorldMapScene:
			return node as WorldMapScene
		node = node.get_parent()
	if Engine.is_editor_hint():
		return EditorInterface.get_edited_scene_root() as WorldMapScene
	return null

func get_map_size_pos_dto_in_editor() -> MapSizeAndPosData:
	var world: WorldMapScene = _get_world_map()
	if world == null or world.map_key.is_empty():
		Loggie.warn("Cannot place cursor: open the world scene with its map_key set")
		return null
	var map_data: MapData = MapData.parse(world.map_key)
	if map_data == null or map_data.size_and_pos == null:
		Loggie.warn("Cannot load GPS map metadata for %s" % world.map_key)
		return null
	return map_data.size_and_pos

func get_editor_terrain() -> Terrain3D:
	var world: WorldMapScene = _get_world_map()
	if world != null and is_instance_valid(world.terrain):
		return world.terrain
	var scene_root: Node = world
	if scene_root == null and Engine.is_editor_hint():
		scene_root = EditorInterface.get_edited_scene_root()
	if scene_root is Terrain3D:
		return scene_root as Terrain3D
	if scene_root != null:
		# Include instanced terrain nodes; they need not belong to this scene.
		var candidates: Array[Node] = scene_root.find_children("*", "Terrain3D", true, false)
		if not candidates.is_empty():
			return candidates[0] as Terrain3D
	Loggie.warn("Cannot place cursor: no Terrain3D found in the world scene")
	return null
