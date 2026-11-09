@tool
class_name InfrJsonStore extends RefCounted

const INFR_JSON_PATH_TEMPLATE = "res://world/%s/jsondata/%s.json"
const JSON_LINE_WIDTH: int = 120

# JSON is the saved source of truth. Only unsaved cached lines are merged into it;
# removing an edit from the cache discards that edit, not the saved road.

static func path_for(world: Node, domain: Enums.InfrDomain) -> String:
	if world.map_key.is_empty() or world.map_key.get_file() != world.map_key or world.map_key in [".", ".."]:
		return ""
	return INFR_JSON_PATH_TEMPLATE % [world.map_key, "roads" if domain == Enums.InfrDomain.ROAD else "tracks"]

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
	var result: EditorActionResult = write_with_backup(path, output)
	if result.ok:
		result.count = output.size()
	return result

func _merge_line_record(line: EditorInfrLine3D, domain: Enums.InfrDomain, records: Dictionary, seen: Dictionary) -> EditorActionResult:
	if line.num < 0 or seen.has(line.num) or line.curve == null or line.curve.point_count < 2:
		return failure("Cannot save duplicate/negative IDs or curves with fewer than two points.")
	seen[line.num] = true
	var record: Dictionary = records.get(line.num, {}).duplicate(true)
	var old_points: Array = record.get("points", [])
	var problem: String = _validate_anchor_changes(line, old_points)
	if not problem.is_empty():
		return failure(problem)
	record["num"] = line.num
	record["name"] = line.infr_name
	if not record.has("type"):
		record["type"] = "rural_road" if domain == Enums.InfrDomain.ROAD else "NORMAL_GAUGE"
	if domain == Enums.InfrDomain.ROAD:
		record["autosmooth"] = line.autosmooth
	var points: Array = []
	for index: int in range(line.curve.point_count):
		points.append(_serialize_curve_point(line, index, old_points))
	record["points"] = points
	records[line.num] = record
	return EditorActionResult.success()

func _validate_anchor_changes(line: EditorInfrLine3D, old_points: Array) -> String:
	# Index-based metadata must not silently move to another anchor after edits.
	if old_points.size() != line.curve.point_count:
		for point: Dictionary in old_points:
			for key: String in point:
				if key not in ["pos", "handleIn", "handleOut"]:
					return "Record %d has point metadata and a changed point count; preserve its anchors before saving." % line.num
	return ""

func _serialize_curve_point(line: EditorInfrLine3D, index: int, old_points: Array) -> Dictionary:
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
	var ids: Array = records.keys()
	ids.sort()
	var output: Array = []
	for num: int in ids:
		output.append(records[num])
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

static func write_text_with_backup(path: String, contents: String) -> EditorActionResult:
	var absolute: String = ProjectSettings.globalize_path(path)
	var suffix: String = "%s-%d" % [Time.get_datetime_string_from_system().replace(":", "-"), Time.get_ticks_usec()]
	var temporary: String = absolute + ".tmp-" + suffix
	var result: EditorActionResult = _write_temporary_json(temporary, contents)
	if not result.ok:
		return result
	var backup: String = ""
	if FileAccess.file_exists(absolute):
		backup = absolute + ".bak-" + suffix
		var backup_error: Error = DirAccess.copy_absolute(absolute, backup)
		if backup_error != OK:
			DirAccess.remove_absolute(temporary)
			return failure("Backup failed; original JSON was not changed: " + error_string(backup_error))
	# Replace only after the complete temporary file and backup exist.
	var error: Error = DirAccess.rename_absolute(temporary, absolute)
	if error != OK:
		DirAccess.remove_absolute(temporary)
		return failure("Could not replace JSON; original retained: " + error_string(error))
	return EditorActionResult.success(0, backup)

static func _write_temporary_json(path: String, contents: String) -> EditorActionResult:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return failure("Cannot write temporary JSON: " + error_string(FileAccess.get_open_error()))
	file.store_string(contents)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		DirAccess.remove_absolute(path)
		return failure("Could not finish writing JSON: " + error_string(error))
	return EditorActionResult.success()

static func reference_container_for(world: Node, domain: Enums.InfrDomain) -> Node3D:
	var cache: Node = world.get_node_or_null("EditorCache")
	for node: Node in world.find_children("*", "", true, false):
		if cache != null and cache.is_ancestor_of(node):
			continue
		if (domain == Enums.InfrDomain.ROAD and node is GeneratedRoadWays) or (domain == Enums.InfrDomain.RAIL and node is GeneratedRailLines):
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
