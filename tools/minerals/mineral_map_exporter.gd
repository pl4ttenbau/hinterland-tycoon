## Exports geology from either the editor's live terrain or a headless terrain instance.
@tool
class_name MineralMapExporter extends RefCounted

const DEFAULT_METRES_PER_PIXEL: float = 4.0
const MAX_PIXELS: int = 4_194_304
const RICH_THRESHOLD: float = 0.40


static func default_output_dir(world_key: String) -> String:
	return ProjectSettings.globalize_path("res://.godot/mineral-maps/" + world_key)


static func write_maps(
	world_key: String,
	terrain: Terrain3D,
	paint_assets: Terrain3DAssets,
	output_dir: String,
	spacing: float,
) -> Error:
	if not is_instance_valid(terrain) or terrain.data == null:
		return _fail("Terrain data is unavailable for %s." % world_key)
	if not is_finite(spacing) or spacing < 1.0:
		return _fail("Metres per pixel must be a number of at least 1.")
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

	var geology := MineralGeology.new(world_key.hash())
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

	var metadata_path: String = output_dir.path_join("minerals.json")
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


static func _fail(message: String) -> Error:
	printerr(message)
	return FAILED
