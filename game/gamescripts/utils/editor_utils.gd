@tool
class_name EditorUtils extends RefCounted

static func get_editor_map_name():
	var scene_root_node: Node = EditorInterface.get_edited_scene_root()
	if scene_root_node is WorldMapScene:
		var world: WorldMapScene = scene_root_node as WorldMapScene
		return world.map_key
	else:
		Loggie.error("Cannot find Map in scene %s; Opened empty WorldScene instead?" % scene_root_node.name)
		return null

static func get_open_editor_map() -> WorldMapScene:
	var any_scene_root: Node = EditorInterface.get_edited_scene_root()
	if !any_scene_root is WorldMapScene:
		Loggie.error("Cannot get open map in editor: %s seems not to be of WorldMapScene type" % any_scene_root.get_path())
		return
	return any_scene_root as WorldMapScene

static func get_open_terrain3d() -> Terrain3D:
	var open_world_scene: WorldMapScene = get_open_editor_map()
	if open_world_scene.has_node("WorldTerrain"):
		return open_world_scene.get_node("WorldTerrain")
	elif open_world_scene.has_node("Terrain3D"):
		return open_world_scene.get_node("Terrain3D")
	Loggie.warn("cannot find WorldMapScene terrain and default name")
	for any_child: Node in open_world_scene.get_children():
		if any_child is Terrain3D:
			return any_child as Terrain3D
	Loggie.error("Cannot find open Terrain3D at all")
	return null
	
static func get_y_at_pos(world_pos: Vector3) -> float:
	var terr3d: Terrain3D = get_open_terrain3d()
	Loggie.info("getting height in terrain %s at %v" % [terr3d.name, world_pos])
	var h: float = terr3d.data.get_height(world_pos)
	if h == NAN || h <= 0:
		Loggie.error("Cannot get height")
		return 0
	return h
