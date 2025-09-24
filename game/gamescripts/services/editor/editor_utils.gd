class_name EditorUtils extends RefCounted

static func get_editor_map_name():
	var scene_root_node: Node = EditorInterface.get_edited_scene_root()
	if scene_root_node is TerrainContainer:
		var world: TerrainContainer = scene_root_node as TerrainContainer
		return world.map_key
	return null

static func get_open_world() -> TerrainContainer:
	var scene_root_node: Node = EditorInterface.get_edited_scene_root()
	if scene_root_node is TerrainContainer:
		return scene_root_node as TerrainContainer
	Loggie.error("Cannot find open world scene!")
	return null
