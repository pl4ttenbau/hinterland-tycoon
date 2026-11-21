## Local terrain-texture trial. No terrain backups are created.
## Run with --apply to save; without it, only inspect the requested samples.
extends SceneTree

const SOURCE: String = "res://world/gdansk/source/roads_ostaszewo/road_trace.json"
const REPORT: String = "res://world/gdansk/source/roads_ostaszewo/paint_validation.json"
const TERRAIN: String = "res://world/gdansk/heightdata"
const ROAD_ID: int = 11
const WATER_LEVEL: float = 14.647888

func _init() -> void:
	call_deferred("_run")

func _component(value: int) -> String:
	return ("-" if value < 0 else "_") + "%02d" % absi(value)

func _run() -> void:
	var apply_changes: bool = "--apply" in OS.get_cmdline_user_args()
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var grouped: Dictionary = {}
	for point: Array in spec.pixels:
		var wx: int = int(point[0])
		var wz: int = int(point[1])
		var location := Vector2i(floori(wx / 256.0), floori(wz / 256.0))
		if not grouped.has(location):
			grouped[location] = []
		grouped[location].append(Vector2i(wx - location.x * 256, wz - location.y * 256))
	var replace_mask: int = Terrain3DUtil.enc_base(31) | Terrain3DUtil.enc_overlay(31) | Terrain3DUtil.enc_blend(255) | Terrain3DUtil.enc_auto(true)
	var road_bits: int = Terrain3DUtil.enc_base(ROAD_ID) | Terrain3DUtil.enc_overlay(ROAD_ID)
	var staged: Array[Dictionary] = []
	var painted: int = 0
	var skipped_water: int = 0
	var skipped_gravel: int = 0
	# Preflight all resources and construct changes in memory before any saves.
	for location: Vector2i in grouped:
		var path: String = TERRAIN.path_join("terrain3d" + _component(location.x) + _component(location.y) + ".res")
		var region: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if region == null:
			push_error("Missing terrain region: " + path)
			quit(1)
			return
		var control: Image = region.get_control_map()
		var height: Image = region.get_height_map()
		var color: Image = region.get_color_map()
		if control.get_format() != Image.FORMAT_RF or control.get_size() != Vector2i(256,256):
			push_error("Unexpected control-map format: " + path)
			quit(1)
			return
		var before: PackedByteArray = control.get_data()
		var after: PackedByteArray = before.duplicate()
		var changed: Dictionary = {}
		for pixel: Vector2i in grouped[location]:
			var offset: int = (pixel.y * 256 + pixel.x) * 4
			var old_bits: int = before.decode_u32(offset)
			if height.get_pixelv(pixel).r <= WATER_LEVEL + 0.05:
				skipped_water += 1
				continue
			if Terrain3DUtil.get_base(old_bits) == 3 or (Terrain3DUtil.get_overlay(old_bits) == 3 and Terrain3DUtil.get_blend(old_bits) > 0):
				skipped_gravel += 1
				continue
			var new_bits: int = (old_bits & (~replace_mask & 0xffffffff)) | road_bits
			if new_bits != old_bits:
				after.encode_u32(offset, new_bits)
				changed[offset] = new_bits
				painted += 1
		for offset: int in range(0, before.size(), 4):
			if not changed.has(offset) and before.decode_u32(offset) != after.decode_u32(offset):
				push_error("Unexpected change outside the road mask")
				quit(1)
				return
		staged.append({"location": location,"path": path,"region": region,"before": before,
			"after": after,"changed": changed,"height": height.get_data(),"color": color.get_data()})
	if not apply_changes:
		print("ROAD_DRY_RUN requested=",spec.pixels.size()," paintable=",painted," water=",skipped_water," gravel=",skipped_gravel," regions=",staged.size())
		quit()
		return
	var regions: Array[Dictionary] = []
	for entry: Dictionary in staged:
		if entry.changed.is_empty():
			continue
		var region: Resource = entry.region
		var image: Image = region.get_control_map()
		image.set_data(256,256,false,Image.FORMAT_RF,entry.after)
		region.set_control_map(image)
		region.set_location(entry.location)
		region.set_modified(true)
		var error: Error = region.save(entry.path,false)
		if error != OK:
			push_error("Terrain save failed: %s (%s)" % [entry.path,error])
			quit(1)
			return
		var saved: Resource = ResourceLoader.load(entry.path,"",ResourceLoader.CACHE_MODE_IGNORE)
		if saved == null or saved.get_control_map().get_data() != entry.after or saved.get_height_map().get_data() != entry.height or saved.get_color_map().get_data() != entry.color:
			push_error("Saved terrain verification failed: " + entry.path)
			quit(1)
			return
		regions.append({"location": [entry.location.x,entry.location.y],"path": entry.path,
			"painted_samples": entry.changed.size(),"height_unchanged": true,"color_unchanged": true,
			"unpainted_control_changes": 0,"saved_control_verified": true})
	var report: Dictionary = {"date": "2026-11-08","scope": spec.scope,"source": SOURCE,
		"texture_name": "RoadGround","texture_slot": ROAD_ID,"width_game_units": 5,"hard_edge": true,
		"painted_samples": painted,"requested_samples": spec.pixels.size(),"water_samples_skipped": skipped_water,
		"gravel_samples_skipped": skipped_gravel,"regions": regions,"saved_files_verified": true,
		"height_maps_unchanged": true,"color_maps_unchanged": true,"unpainted_control_changes": 0,
		"backup_created": false,"side_streets_added": false,"scenario_year": 1968,
		"historical_limit": spec.historical_limit,"modern_expressway_painted": false}
	var output := FileAccess.open(REPORT,FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"))
	output.close()
	print("ROAD_PAINT_COMPLETE samples=",painted," regions=",regions.size()," water_skipped=",skipped_water," gravel_skipped=",skipped_gravel)
	quit()
