extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	quit(0 if _generate() == OK else 1)


func _generate() -> Error:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var no_mcp_index: int = args.find("--no-mcp")
	if no_mcp_index >= 0:
		args.remove_at(no_mcp_index)
	if "--help" in args:
		_print_usage()
		return OK
	if args.is_empty() or args.size() > 3 or not args[0].replace("-", "_").is_valid_identifier():
		_print_usage()
		return FAILED

	var world_key: String = args[0]
	var output_dir: String = args[1] if args.size() >= 2 else MineralMapExporter.default_output_dir(world_key)
	output_dir = ProjectSettings.globalize_path(output_dir)
	if not output_dir.is_absolute_path():
		output_dir = ProjectSettings.globalize_path("res://".path_join(output_dir))
	var spacing: float = MineralMapExporter.DEFAULT_METRES_PER_PIXEL
	if args.size() == 3:
		spacing = args[2].to_float()
		if not args[2].is_valid_float() or not is_finite(spacing) or spacing < 1.0:
			return _fail("Metres per pixel must be a number of at least 1.")

	var world_dir: String = "res://world/" + world_key
	var data_dir: String = world_dir.path_join("heightdata")
	var assets_path: String = world_dir.path_join("mapscenes/terrain/terrain_assets_%s.res" % world_key)
	if not DirAccess.dir_exists_absolute(data_dir) or not ResourceLoader.exists(assets_path):
		return _fail("Cannot find terrain data and texture assets for %s." % world_key)

	# Keep the paint assets separate. Terrain3D can discard its texture list when
	# it tries to build GPU texture arrays on the headless renderer.
	var paint_assets: Terrain3DAssets = load(assets_path)
	if paint_assets == null:
		return _fail("Cannot load terrain texture assets for %s." % world_key)
	var terrain := Terrain3D.new()
	root.add_child(terrain)
	terrain.data.load_directory(data_dir)
	var result: Error = MineralMapExporter.write_maps(world_key, terrain, paint_assets, output_dir, spacing)
	terrain.free()
	return result


func _print_usage() -> void:
	print("tools/minerals/generate-minerals.sh WORLD [OUTPUT_DIR] [METRES_PER_PIXEL]")
	print("Default output: .godot/mineral-maps/WORLD. Default resolution: %.0f metres per pixel." % MineralMapExporter.DEFAULT_METRES_PER_PIXEL)
	print("Relative output paths are resolved from the project root.")
	print("PNG brightness is richness from 0 to 100%. Transparent pixels are outside terrain or in holes.")
	print("minerals.json records the upper-left edge in world X/Z. Pixel centres are sampled with +X right and +Z down.")


func _fail(message: String) -> Error:
	printerr(message)
	return FAILED
