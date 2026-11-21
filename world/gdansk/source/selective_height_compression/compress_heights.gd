## Selective height remapping of saved Terrain3D regions. No blur, no backups.
## Default: dry run. Saving requires --apply and unchanged input file hashes.
extends SceneTree

const DEFAULT_CONFIG: String = "res://world/gdansk/source/selective_height_compression/wislinka_pile.json"

func _init() -> void:
	call_deferred("_run")

func _part(value: int) -> String:
	return ("-" if value < 0 else "_") + "%02d" % absi(value)

func _compressed(h: float, settings: Dictionary) -> float:
	var start: float = settings.unchanged_below_y
	if h <= start:
		return h
	var t: float = h - start
	var knee: float = settings.transition_height
	var factor: float = settings.upper_height_factor
	if t < knee:
		return start + t - (1.0 - factor) * t * t / (2.0 * knee)
	return start + knee * (1.0 + factor) * 0.5 + factor * (t - knee)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _selection_weight(point: Vector2, polygon: PackedVector2Array, edge_width: float) -> float:
	if polygon.is_empty():
		return 1.0
	if not Geometry2D.is_point_in_polygon(point,polygon):
		return 0.0
	var nearest_squared: float = INF
	for i: int in range(polygon.size()):
		var a: Vector2 = polygon[i]
		var delta: Vector2 = polygon[(i+1)%polygon.size()] - a
		var t: float = clampf((point-a).dot(delta)/delta.length_squared(),0.0,1.0)
		nearest_squared = minf(nearest_squared,point.distance_squared_to(a+delta*t))
	return smoothstep(0.0,edge_width,sqrt(nearest_squared))

func _run() -> void:
	var config_path: String = DEFAULT_CONFIG
	var apply_changes: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--config="):
			config_path = argument.trim_prefix("--config=")
		if argument == "--apply":
			apply_changes = true
	var settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	if settings.is_empty() or settings.upper_height_factor <= 0 or settings.upper_height_factor > 1 or settings.transition_height <= 0:
		_fail("Invalid compression settings")
		return
	var bounds: Array = settings.bounds_xmin_zmin_xmax_zmax
	var polygon := PackedVector2Array()
	for vertex: Array in settings.get("selection_polygon_xz",[]):
		polygon.append(Vector2(float(vertex[0]),float(vertex[1])))
	var edge_width: float = settings.get("selection_edge_transition_width",0.0)
	if not polygon.is_empty() and (polygon.size()<3 or edge_width<=0):
		_fail("Polygon selections need at least three vertices and a positive edge transition width")
		return
	var staged: Array[Dictionary] = []
	var peak_before: float = -INF
	var peak_after: float = -INF
	var total: int = 0
	for file_name: String in settings.expected_source_region_sha256:
		var path: String = str(settings.terrain_directory).path_join(file_name)
		if FileAccess.get_sha256(path) != settings.expected_source_region_sha256[file_name]:
			_fail("Input terrain changed or this operation was already applied: " + path)
			return
		var region: Resource = ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
		if region == null:
			_fail("Cannot load region: " + path)
			return
		var location_array: Array = settings.region_locations[file_name]
		var location := Vector2i(int(location_array[0]),int(location_array[1]))
		var height: Image = region.get_height_map()
		if height.get_format() != Image.FORMAT_RF or height.get_size() != Vector2i(256,256):
			_fail("Unexpected height-map format: " + path)
			return
		var before: PackedByteArray = height.get_data()
		var after: PackedByteArray = before.duplicate()
		var changed: Dictionary = {}
		for z: int in range(256):
			for x: int in range(256):
				var wx: int = location.x * 256 + x
				var wz: int = location.y * 256 + z
				if wx < bounds[0] or wz < bounds[1] or wx > bounds[2] or wz > bounds[3]:
					continue
				var offset: int = (z * 256 + x) * 4
				var h: float = before.decode_float(offset)
				if not is_finite(h):
					_fail("Non-finite height")
					return
				if polygon.is_empty() and (wx == bounds[0] or wx == bounds[2] or wz == bounds[1] or wz == bounds[3]) and h > settings.unchanged_below_y:
					_fail("Selection cuts through high ground; enlarge its bounds before applying")
					return
				if h <= settings.unchanged_below_y:
					continue
				var weight: float = _selection_weight(Vector2(wx,wz),polygon,edge_width)
				if weight <= 0:
					continue
				var updated: float = lerpf(h,_compressed(h,settings),weight)
				peak_before = maxf(peak_before,h)
				peak_after = maxf(peak_after,updated)
				if updated < h:
					after.encode_float(offset,updated)
					if after.decode_u32(offset) != before.decode_u32(offset):
						changed[offset] = true
						total += 1
		for offset: int in range(0,before.size(),4):
			if not changed.has(offset) and before.decode_u32(offset) != after.decode_u32(offset):
				_fail("Height changed outside the selected high ground")
				return
		staged.append({"path":path,"file":file_name,"location":location,"region":region,
			"before":before,"after":after,"changed":changed.size(),
			"control":region.get_control_map().get_data(),"color":region.get_color_map().get_data()})
	if not apply_changes:
		print("HEIGHT_DRY_RUN changed=",total," peak_before=",peak_before," peak_after=",peak_after)
		quit()
		return
	var results: Array[Dictionary] = []
	for entry: Dictionary in staged:
		if entry.changed == 0:
			continue
		var region: Resource = entry.region
		var height: Image = region.get_height_map()
		height.set_data(256,256,false,Image.FORMAT_RF,entry.after)
		region.set_height_map(height)
		region.set_location(entry.location)
		region.calc_height_range()
		region.set_modified(true)
		if region.save(entry.path,false) != OK:
			_fail("Saving region failed: " + str(entry.path))
			return
		var saved: Resource = ResourceLoader.load(entry.path,"",ResourceLoader.CACHE_MODE_IGNORE)
		if saved == null or saved.get_height_map().get_data() != entry.after or saved.get_control_map().get_data() != entry.control or saved.get_color_map().get_data() != entry.color:
			_fail("Saved map verification failed: " + str(entry.path))
			return
		results.append({"file":entry.file,"changed_samples":entry.changed,"after_sha256":FileAccess.get_sha256(entry.path),
			"height_reload_verified":true,"control_map_unchanged":true,"color_map_unchanged":true})
	var report: Dictionary = {"date":"2026-11-08","feature":settings.feature,"config":config_path,
		"method":"Monotonic piecewise height compression with a quadratic transition; no spatial smoothing or averaging",
		"peak_before_y":peak_before,"peak_after_y":peak_after,"water_level":settings.water_level,
		"peak_before_above_water":peak_before-settings.water_level,"peak_after_above_water":peak_after-settings.water_level,
		"unchanged_below_y":settings.unchanged_below_y,"transition_height":settings.transition_height,
		"upper_height_factor":settings.upper_height_factor,"changed_samples":total,"regions":results,
		"selection_polygon_xz":settings.get("selection_polygon_xz",[]),"selection_edge_transition_width":edge_width,
		"other_height_samples_unchanged":true,"backup_created":false,"reimport_performed":false}
	var output := FileAccess.open(settings.report_path,FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"))
	output.close()
	print("HEIGHT_COMPRESSION_COMPLETE changed=",total," peak_before=",peak_before," peak_after=",peak_after)
	quit()
