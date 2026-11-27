@tool
class_name InfrJsonStore extends RefCounted

const INFR_JSON_PATH_TEMPLATE = "res://world/%s/jsondata/%s.json"
const JSON_LINE_WIDTH: int = 120

# JSON is the saved source of truth. Only unsaved cached lines are merged into it;
# removing an edit from the cache discards that edit, not the saved road.

static func path_for(world: Node, domain: Enums.InfrDomain) -> String:
	if world.map_key.is_empty() or world.map_key.get_file() != world.map_key or world.map_key in [".", ".."]:
		return ""
	return INFR_JSON_PATH_TEMPLATE % [world.map_key, InfrDomains.json_stem(domain)]

static func failure(message: String) -> EditorActionResult:
	return EditorActionResult.failure(message)

static func read_records(path: String) -> InfrCatalogReadResult:
	return InfrCatalogReadResult.read(path)

static func validate_records(records: Variant) -> String:
	return InfrLineValidator.validate_records(records)

static func valid_vector(value: Variant) -> bool:
	return InfrLineValidator.valid_vector(value)

static func vec_array(vector: Vector3) -> Array:
	return [vector.x, vector.y, vector.z]

static func container_for(world: WorldMapScene, domain: Enums.InfrDomain) -> Node3D:
	return EditorCache.ensure_container(world, domain)

static func next_number(world: WorldMapScene, domain: Enums.InfrDomain) -> int:
	var source: InfrCatalogReadResult = read_records(path_for(world, domain))
	if not source.ok:
		push_warning(source.error)
		return -1
	var number: int = 1
	for record: Dictionary in source.records:
		number = maxi(number, int(record.num) + 1)
	return number

func save_world(world: WorldMapScene, domain: Enums.InfrDomain) -> EditorActionResult:
	var container: Node3D = container_for(world, domain)
	if container == null:
		return failure("The open world has no matching infrastructure container.")
	var lines: Array[EditorInfrLine3D] = []
	# Save every cached edit, including hidden ones. Reference geometry under
	# EditorObjects is never written back over newer JSON or external deletions.
	for node: Node in container.get_children():
		if node is EditorInfrLine3D and node.infr_domain == domain:
			lines.append(node)
	return save_lines(path_for(world, domain), lines, domain)

func save_lines(path: String, lines: Array[EditorInfrLine3D], domain: Enums.InfrDomain) -> EditorActionResult:
	var source: InfrCatalogReadResult = read_records(path)
	if not source.ok:
		return failure(source.error)
	var records: Dictionary = {}
	for original: Dictionary in source.records:
		records[int(original.num)] = original.duplicate(true)
	var seen: Dictionary = {}
	for line: EditorInfrLine3D in lines:
		var result: EditorActionResult = _merge_line_record(line, domain, records, seen)
		if not result.ok:
			return result
	var output: Array = _prepare_records_for_save(records, domain)
	# Worked out before anything is written: if the stops cannot be updated, nothing is saved.
	var stops: Dictionary = _reanchor_stops(path, source.records, records, domain)
	if stops.has("error"):
		return failure(stops.error)
	var result: EditorActionResult = write_with_backup(path, output)
	if result.ok:
		result.count = output.size()
	if result.ok and stops.has("records"):
		var written: EditorActionResult = write_text_with_backup(stops.path, InfrJsonFormatter.interchanges_text(stops.records))
		if not written.ok:
			return failure("Saved %s, but the stops on changed lines were not updated: %s" % [path.get_file(), written.error])
	return result

## Stops (interchanges.json, next to the line file) name a node by its index. When a line gains or loses
## points, later indices shift and a stop would silently jump to another node; so its stops are moved
## back to where they stood (EditorStopAnchors.reanchor_stops). Returns {} when nothing needs to change,
## {"path", "records"} with the updated catalog, or {"error"} when the catalog cannot be read.
func _reanchor_stops(path: String, old_list: Array, new_records: Dictionary, domain: Enums.InfrDomain) -> Dictionary:
	var old_records: Dictionary = {}
	var changed: bool = false
	for record: Dictionary in old_list:
		var num: int = int(record.num)
		old_records[num] = record
		if new_records.has(num) and new_records[num].points.size() != record.points.size():
			changed = true
	var catalog_path: String = path.get_base_dir().path_join("interchanges.json")
	if not changed or not FileAccess.file_exists(catalog_path):
		return {}
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	if InterchangesLoader.validate_definitions(catalog) != OK:
		return {"error": "interchanges.json is invalid, so the stops on lines with added or removed points cannot be updated. Fix it first."}
	var report: Array[String] = EditorStopAnchors.reanchor_stops(catalog, InfrDomains.key(domain), old_records, new_records)
	if report.is_empty():
		return {}
	for line: String in report:
		print("Re-anchored " + line)
	return {"path": catalog_path, "records": catalog}

func _merge_line_record(line: EditorInfrLine3D, domain: Enums.InfrDomain, records: Dictionary, seen: Dictionary) -> EditorActionResult:
	if line.num < 0 or seen.has(line.num) or line.curve == null or line.curve.point_count < 2:
		return failure("Cannot save duplicate/negative IDs or curves with fewer than two points.")
	seen[line.num] = true
	var old_record: Dictionary = records.get(line.num, {})
	var problem: String = _validate_anchor_changes(line, old_record.get("points", []))
	if not problem.is_empty():
		return failure(problem)
	records[line.num] = line_to_record(line, domain, old_record)
	return EditorActionResult.success()

## The JSON record for `line`, exactly as a save builds it before rounding and formatting: world-space
## positions and handles, number, name, type and (roads) the smoothing flag. `old_record` is the saved
## record being replaced: its other top-level fields are kept, and so is each point's metadata (forks,
## stations, ...) when the point count is unchanged. Callers check anchors first (see _merge_line_record).
## Static and side-effect free, so tests can round-trip lines through the real save conversion.
static func line_to_record(line: EditorInfrLine3D, domain: Enums.InfrDomain, old_record: Dictionary = {}) -> Dictionary:
	var record: Dictionary = old_record.duplicate(true)
	var old_points: Array = record.get("points", [])
	record["num"] = line.num
	record["name"] = line.infr_name
	if domain == Enums.InfrDomain.RAIL and not line.rail_gauge.is_empty():
		record["type"] = line.rail_gauge
	elif not record.has("type"):
		record["type"] = InfrDomains.default_type(domain)
	if domain == Enums.InfrDomain.ROAD:
		record["autosmooth"] = line.autosmooth
	var points: Array = []
	for index: int in range(line.curve.point_count):
		points.append(_serialize_curve_point(line, index, old_points))
	record["points"] = points
	return record

static func _validate_anchor_changes(line: EditorInfrLine3D, old_points: Array) -> String:
	# Index-based metadata must not silently move to another anchor after edits.
	if old_points.size() != line.curve.point_count:
		for point: Dictionary in old_points:
			for key: String in point:
				if key in ["pos", "handleIn", "handleOut"]:
					continue
				if line.infr_domain == Enums.InfrDomain.RAIL and _is_generated_fork(point, key):
					continue
				return "Record %d has point metadata and a changed point count; preserve its anchors before saving." % line.num
	return ""

## A rail fork that lists only its tracks is rebuilt from the geometry on every save
## (_prepare_records_for_save), so losing it with a changed point count loses nothing: the generator puts
## it back on whichever points are the ends now. A fork with anything else in it (e.g. "static") carries
## hand-made meaning and still blocks the save like any other metadata.
static func _is_generated_fork(point: Dictionary, key: String) -> bool:
	return key == "fork" and point.fork is Dictionary and point.fork.keys() == ["connectiveTracks"]

static func _serialize_curve_point(line: EditorInfrLine3D, index: int, old_points: Array) -> Dictionary:
	var point: Dictionary = old_points[index].duplicate(true) if old_points.size() == line.curve.point_count else {}
	point["pos"] = vec_array(line.to_global(line.curve.get_point_position(index)))
	# Handles are offsets, so apply only the basis, without translation.
	point["handleIn"] = vec_array(line.global_basis * line.curve.get_point_in(index))
	point["handleOut"] = vec_array(line.global_basis * line.curve.get_point_out(index))
	return point

func _prepare_records_for_save(records: Dictionary, domain: Enums.InfrDomain) -> Array:
	# Resolve crossings against the rounded positions that JSON will contain.
	round_positions(records.values())
	if domain == Enums.InfrDomain.ROAD:
		RoadEndpointConnection.update_json(records)
	elif domain == Enums.InfrDomain.RAIL:
		# Rail switches likewise: every track end gets the tracks a train can continue into. This rewrites
		# the forks of the whole map, not just the edited lines, so the file always matches the geometry
		# (the same result as tools/rail/tracks.sh forks --write).
		var forks: Dictionary = RailForkGenerator.apply(records.values())
		for record: Dictionary in forks.records:
			records[int(record.num)] = record
	var ids: Array = records.keys()
	ids.sort()
	var output: Array = []
	for num: int in ids:
		var record: Dictionary = records[num]
		if domain == Enums.InfrDomain.RAIL and record.get("type") is String:
			record["type"] = InfrType.normalize_rail_gauge(record["type"])
		output.append(record)
	return output

static func round_positions(records: Array) -> void:
	InfrJsonFormatter.round_positions(records)

static func format_json(value: Variant, depth: int = 0, prefix_width: int = 0, position: bool = false) -> String:
	return InfrJsonFormatter.format_json(value, depth, prefix_width, position)

static func position_text(value: float) -> String:
	return InfrJsonFormatter.position_text(value)

static func write_with_backup(path: String, records: Array) -> EditorActionResult:
	var problem: String = validate_records(records)
	if not problem.is_empty():
		return failure(problem)
	# Work on a copy so serialization does not modify live curves/caller data.
	records = records.duplicate(true)
	round_positions(records)
	return write_text_with_backup(path, format_json(records) + "\n")

## Safe replace with one backup. The game's stop export needs the same, so it lives in JsonFileUtils;
## this only turns its result into the editor's EditorActionResult.
static func write_text_with_backup(path: String, contents: String) -> EditorActionResult:
	var written: Dictionary = JsonFileUtils.write_text_with_backup(path, contents)
	if not written.error.is_empty():
		return failure(written.error)
	return EditorActionResult.success(0, written.backup)

static func reference_container_for(world: Node, domain: Enums.InfrDomain) -> Node3D:
	var cache: Node = EditorCache.find(world)
	for node: Node in world.find_children("*", "", true, false):
		if cache != null and cache.is_ancestor_of(node):
			continue
		if InfrDomains.is_reference_container(node, domain):
			return node as Node3D
	return null

func load_world(world: Node, domain: Enums.InfrDomain, history: Object = null) -> EditorActionResult:
	var source: InfrCatalogReadResult = read_records(path_for(world, domain))
	if not source.ok:
		return failure(source.error)
	if not source.exists:
		return failure("No JSON file exists at " + path_for(world, domain))
	var container: Node3D = reference_container_for(world, domain)
	if container == null:
		return failure("The open world has no matching EditorObjects infrastructure container.")
	var roots: Array[Node] = []
	var inverse: Transform3D = container.global_transform.affine_inverse()
	for record: Dictionary in source.records:
		roots.append(_create_line_from_record(record, domain, inverse))
	var previous: EditorSceneSnapshot = EditorSceneSnapshot.capture(container, world, domain)
	var owner: Node = world if world is WorldEditorObjects else container.owner
	var state: EditorSceneSnapshot = EditorSceneSnapshot.for_nodes(roots, owner, world, domain)
	_commit_references(container, state, previous, history)
	return EditorActionResult.success(roots.size())

func _create_line_from_record(record: Dictionary, domain: Enums.InfrDomain, inverse: Transform3D) -> EditorInfrLine3D:
	var line: EditorInfrLine3D = EditorInfrLine3D.of(domain, int(record.num), record.get("name", "unnamed"), record.get("autosmooth", true))
	line.create_curve_from_dict(record)
	line.position = inverse * WorldUtils.vec3_from_float_arr(record.points[0].pos)
	for index: int in range(line.curve.point_count):
		line.curve.set_point_position(index, inverse * line.curve.get_point_position(index) - line.position)
		line.curve.set_point_in(index, inverse.basis * line.curve.get_point_in(index))
		line.curve.set_point_out(index, inverse.basis * line.curve.get_point_out(index))
	return line

func _commit_references(container: Node3D, state: EditorSceneSnapshot, previous: EditorSceneSnapshot, history: Object) -> void:
	if history != null:
		history.create_action("Load infrastructure JSON into EditorObjects", UndoRedo.MERGE_DISABLE, state.world)
		history.add_do_method(self, "replace_references", container, state)
		history.add_undo_method(self, "replace_references", container, previous)
		for node: Node in state.roots:
			history.add_do_reference(node)
		for node: Node in previous.roots:
			history.add_undo_reference(node)
		history.commit_action()
	else:
		replace_references(container, state)
		for node: Node in previous.roots:
			node.queue_free()

func replace_references(container: Node3D, state: EditorSceneSnapshot) -> void:
	for node: Node in container.get_children():
		container.remove_child(node)
	for node: Node in state.roots:
		container.add_child(node)
	state.restore_owners()
	EditorCache.refresh_source_visibility(state.world, state.domain)

static func domain_roots(cache: Node3D, domain: Enums.InfrDomain) -> Array[Node]:
	var roots: Array[Node] = []
	for node: Node in cache.get_children():
		if node is EditorInfrLine3D and node.infr_domain == domain:
			roots.append(node)
	return roots

func replace_domain(cache: Node3D, state: EditorSceneSnapshot) -> void:
	for node: Node in domain_roots(cache, state.domain):
		cache.remove_child(node)
	for node: Node in state.roots:
		cache.add_child(node)
	state.restore_owners()

	EditorCache.refresh_source_visibility(cache.get_parent(), state.domain)

func flush_saved(world: WorldMapScene, domain: Enums.InfrDomain, history: Object) -> void:
	var cache: Node3D = container_for(world, domain)
	var roots: Array[Node] = domain_roots(cache, domain)
	var previous: EditorSceneSnapshot = EditorSceneSnapshot.for_nodes(roots, world, world, domain)
	# Keep the flush undoable. A detached node remains in history until the map
	# closes, avoiding invalidating earlier creation/edit actions by freeing it.
	history.create_action("Clear saved infrastructure cache", UndoRedo.MERGE_DISABLE, world)
	history.add_do_method(self, "replace_domain", cache, EditorSceneSnapshot.for_nodes([], world, world, domain))
	history.add_undo_method(self, "replace_domain", cache, previous)
	for node: Node in roots:
		history.add_undo_reference(node)
	history.commit_action()
