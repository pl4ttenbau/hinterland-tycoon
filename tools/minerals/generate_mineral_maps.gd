extends SceneTree

const MineralGeologySampler = preload("res://game/gamescripts/resources/terrain/mineral_geology.gd")
const DEFAULT_METRES_PER_PIXEL: float = 4.0
const MAX_PIXELS: int = 4_194_304
const RICH_THRESHOLD: float = 0.40


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
	var output_dir: String = args[1] if args.size() >= 2 else "res://.godot/mineral-maps/" + world_key
	output_dir = ProjectSettings.globalize_path(output_dir)
	if not output_dir.is_absolute_path():
		output_dir = ProjectSettings.globalize_path("res://".path_join(output_dir))
	var spacing: float = DEFAULT_METRES_PER_PIXEL
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
	var result: Error = _export_maps(world_key, terrain, paint_assets, output_dir, spacing)
	terrain.free()
	return result


func _export_maps(
	world_key: String,
	terrain: Terrain3D,
	paint_assets: Terrain3DAssets,
	output_dir: String,
	spacing: float,
) -> Error:
	var data: Terrain3DData = terrain.data
	var regions: Array[Vector2i] = data.get_region_locations()
	if regions.is_empty():
		return _fail("No terrain regions were loaded for %s." % world_key)

	var first: Vector2i = regions[0]
	var last: Vector2i = first
	for region: Vector2i in regions:
		first = first.min(region)
		last = last.max(region)
	var region_width: float = terrain.get_region_size() * terrain.get_vertex_spacing()
	# Region coordinates refer to tile origins. Include the full last region in the image.
	var origin: Vector2 = Vector2(first) * region_width
	var extent: Vector2 = Vector2(last - first + Vector2i.ONE) * region_width
	var width: int = ceili(extent.x / spacing)
	var height: int = ceili(extent.y / spacing)
	if width * height > MAX_PIXELS:
		return _fail("Output would be %d × %d pixels. Increase metres per pixel." % [width, height])

	var geology := MineralGeologySampler.new(world_key.hash())
	var images: Dictionary[String, Image] = {}
	var rich_pixels: Dictionary[String, int] = {}
	var peak_richness: Dictionary[String, float] = {}
	for resource: String in geology.sample(Vector3.ZERO):
		images[resource] = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
		rich_pixels[resource] = 0
		peak_richness[resource] = 0.0

	var terrain_pixels: int = 0
	for row: int in range(height):
		for column: int in range(width):
			# The metadata stores the image edge. Sample half a pixel inward along both axes.
			var xz: Vector2 = origin + (Vector2(column, row) + Vector2(0.5, 0.5)) * spacing
			var position := Vector3(xz.x, 0.0, xz.y)
			if not data.has_regionp(position) or data.get_control_hole(position):
				continue
			terrain_pixels += 1
			var readings := geology.sample(position, data, paint_assets)
			for resource: String in readings:
				var richness: float = readings[resource]
				images[resource].set_pixel(column, row, Color(richness, richness, richness))
				peak_richness[resource] = maxf(peak_richness[resource], richness)
				if richness > RICH_THRESHOLD:
					rich_pixels[resource] += 1

	if terrain_pixels == 0:
		return _fail("No terrain was sampled. Decrease metres per pixel.")
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(output_dir)
	if dir_error != OK:
		return _fail("Cannot create %s (%s)." % [output_dir, error_string(dir_error)])
	for resource: String in images:
		var png_path: String = output_dir.path_join(resource + ".png")
		var save_error: Error = images[resource].save_png(png_path)
		if save_error != OK:
			return _fail("Cannot write %s (%s)." % [png_path, error_string(save_error)])
		var rich_share: float = 100.0 * rich_pixels[resource] / terrain_pixels
		print("%s: %.2f%% of terrain samples above %.0f%% richness (peak %.1f%%)" % [
			resource, rich_share, RICH_THRESHOLD * 100.0, peak_richness[resource] * 100.0,
		])

	var metadata_path: String = output_dir.path_join("map.json")
	var metadata := FileAccess.open(metadata_path, FileAccess.WRITE)
	if metadata == null:
		return _fail("Cannot write %s." % metadata_path)
	metadata.store_string(JSON.stringify({
		"world": world_key,
		"origin_xz": [origin.x, origin.y],
		"metres_per_pixel": spacing,
		"size_pixels": [width, height],
		"terrain_pixels": terrain_pixels,
		"richness_threshold": RICH_THRESHOLD,
		"pixels_above_threshold": rich_pixels,
	}, "\t") + "\n")
	metadata.close()
	print("Wrote mineral maps to %s" % output_dir)
	return OK


func _print_usage() -> void:
	print("tools/minerals/generate-minerals.sh WORLD [OUTPUT_DIR] [METRES_PER_PIXEL]")
	print("Default output: .godot/mineral-maps/WORLD. Default resolution: %.0f metres per pixel." % DEFAULT_METRES_PER_PIXEL)
	print("Relative output paths are resolved from the project root.")
	print("PNG brightness is richness from 0 to 100%. Transparent pixels are outside terrain or in holes.")
	print("map.json records the upper-left edge in world X/Z. Pixel centres are sampled with +X right and +Z down.")


func _fail(message: String) -> Error:
	printerr(message)
	return FAILED
