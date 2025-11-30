class_name EditorUtils extends RefCounted

static func get_editor_map_name():
	var scene_root_node: Node = EditorInterface.get_edited_scene_root()
	if scene_root_node is WorldMapScene:
		var world: WorldMapScene = scene_root_node as WorldMapScene
		return world.map_key
	else:
		Loggie.error("Cannot find Map in scene %s; Opened empty WorldScene instead?" % scene_root_node.name)
		return null
