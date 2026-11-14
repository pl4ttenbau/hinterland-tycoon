## Exports the open map's current mineral traces from the Inspector.
@tool
class_name EditorResourceTraces extends Node

@export_range(1.0, 32.0, 1.0, "or_greater")
var metres_per_pixel: float = MineralMapExporter.DEFAULT_METRES_PER_PIXEL

@export_tool_button("Regenerate Mineral Maps")
var regenerate_mineral_maps_button: Callable = regenerate_mineral_maps


func regenerate_mineral_maps() -> Error:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return ERR_UNAVAILABLE

	# EditorObjects can be opened alone. Export only when it belongs to an open world.
	var world := EditorInterface.get_edited_scene_root() as WorldMapScene
	if world == null or not world.is_ancestor_of(self) or world.map_key.is_empty():
		push_warning("Open the world scene with its map key set to regenerate mineral maps.")
		return ERR_UNCONFIGURED
	var terrain: Terrain3D = world.terrain
	if not is_instance_valid(terrain):
		push_warning("The world scene needs Terrain3D to regenerate mineral maps.")
		return ERR_UNCONFIGURED

	return MineralMapExporter.write_maps(
		world.map_key, terrain, terrain.assets,
		MineralMapExporter.default_output_dir(world.map_key), metres_per_pixel,
	)
