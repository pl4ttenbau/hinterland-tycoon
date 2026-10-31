@tool
extends RefCounted

# Track the records this editor session actually loaded/saved. A partially
# generated editor scene must not silently delete unseen roads from the file.
var managed_ids: Dictionary = {}

static func path_for(world: WorldMapScene, domain: Enums.InfrDomain) -> String:
	if world.map_key.is_empty() or world.map_key.get_file() != world.map_key or world.map_key in [".", ".."]:
		return ""
	return "res://world/%s/jsondata/%s.json" % [world.map_key, "roads" if domain == Enums.InfrDomain.ROAD else "tracks"]

static func failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}

static func read_records(path: String) -> Dictionary:
	if path.is_empty():
		return failure("The open world has no valid map key.")
	if not FileAccess.file_exists(path):
		return {"ok": true, "records": [], "exists": false}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return failure("Cannot read %s: %s" % [path, error_string(FileAccess.get_open_error())])
	var parser := JSON.new()
	var error: Error = parser.parse(file.get_as_text())
	file.close()
	if error != OK:
		return failure("Invalid JSON in %s, line %d: %s" % [path, parser.get_error_line(), parser.get_error_message()])
	var problem: String = validate_records(parser.data)
	if not problem.is_empty():
		return failure("%s: %s" % [path, problem])
	return {"ok": true, "records": parser.data, "exists": true}

static func validate_records(records: Variant) -> String:
	if not records is Array:
		return "Expected an array of infrastructure records."
	var ids: Dictionary = {}
	for record: Variant in records:
		if not record is Dictionary or not record.get("num") is float and not record.get("num") is int:
			return "Every record needs a numeric num."
		var num: float = record.num
		if not is_finite(num) or num < 0 or num != floor(num) or ids.has(int(num)):
			return "Record numbers must be unique nonnegative integers."
		ids[int(num)] = true
		for key: String in ["name", "type"]:
			if record.has(key) and not record[key] is String:
				return "Record %d has an invalid %s." % [int(num), key]
		if record.has("autosmooth") and not record.autosmooth is bool:
			return "Record %d has an invalid autosmooth setting." % int(num)
		if not record.get("points") is Array or record.points.size() < 2:
			return "Record %d needs at least two points." % int(num)
		for point: Variant in record.points:
			if not point is Dictionary or not valid_vector(point.get("pos")):
				return "Record %d has an invalid point position." % int(num)
			for key: String in ["handleIn", "handleOut"]:
				if point.has(key) and not valid_vector(point[key]):
					return "Record %d has an invalid %s." % [int(num), key]
	return ""

static func valid_vector(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for number: Variant in value:
		if not (number is float or number is int) or not is_finite(float(number)):
			return false
	return true

static func vec_array(vector: Vector3) -> Array:
	return [vector.x, vector.y, vector.z]

static func container_for(world: WorldMapScene, domain: Enums.InfrDomain) -> Node3D:
	return preload("res://addons/hinterland_tools/editor_cache.gd").ensure_container(world, domain)

static func next_number(world: WorldMapScene, domain: Enums.InfrDomain) -> int:
	var source: Dictionary = read_records(path_for(world, domain))
	if not source.ok:
		push_warning(source.error)
		return -1
	var number: int = 1
	for record: Dictionary in source.records:
		number = maxi(number, int(record.num) + 1)
	return number

func save_world(world: WorldMapScene, domain: Enums.InfrDomain) -> Dictionary:
	var container: Node3D = container_for(world, domain)
	if container == null:
		return failure("The open world has no matching infrastructure container.")
	var lines: Array[EditorInfrLine3D] = []
	for node: Node in container.find_children("*", "", true, false):
		if node is EditorInfrLine3D and node.infr_domain == domain:
			lines.append(node)
	return save_lines(path_for(world, domain), lines, domain)

func save_lines(path: String, lines: Array[EditorInfrLine3D], domain: Enums.InfrDomain) -> Dictionary:
	var source: Dictionary = read_records(path)
	if not source.ok:
		return source
	var records: Dictionary = {}
	for original: Dictionary in source.records:
		records[int(original.num)] = original.duplicate(true)
	var seen: Dictionary = {}
	for line: EditorInfrLine3D in lines:
		if line.num < 0 or seen.has(line.num) or line.curve == null or line.curve.point_count < 2:
			return failure("Cannot save duplicate/negative IDs or curves with fewer than two points.")
		seen[line.num] = true
		var record: Dictionary = records.get(line.num, {}).duplicate(true)
		var old_points: Array = record.get("points", [])
		# Index-based metadata belongs to a particular network point. Do not move
		# a crossing/station onto a different point after inserting/removing anchors.
		if old_points.size() != line.curve.point_count:
			for point: Dictionary in old_points:
				for key: String in point:
					if key not in ["pos", "handleIn", "handleOut"]:
						return failure("Record %d has point metadata and a changed point count; preserve its anchors before saving." % line.num)
		record["num"] = line.num
		record["name"] = line.infr_name
		if not record.has("type"):
			record["type"] = "rural_road" if domain == Enums.InfrDomain.ROAD else "NORMAL_GAUGE"
		if domain == Enums.InfrDomain.ROAD:
			record["autosmooth"] = line.autosmooth
		var points: Array = []
		for idx: int in range(line.curve.point_count):
			var point: Dictionary = old_points[idx].duplicate(true) if old_points.size() == line.curve.point_count else {}
			point["pos"] = vec_array(line.to_global(line.curve.get_point_position(idx)))
			# Handles are offsets, so only apply the basis (no translation).
			point["handleIn"] = vec_array(line.global_basis * line.curve.get_point_in(idx))
			point["handleOut"] = vec_array(line.global_basis * line.curve.get_point_out(idx))
			points.append(point)
		record["points"] = points
		records[line.num] = record
	for num: int in managed_ids.get(path, {}):
		if not seen.has(num):
			records.erase(num)
	var ids: Array = records.keys()
	ids.sort()
	var output: Array = []
	for num: int in ids:
		output.append(records[num])
	var result: Dictionary = write_with_backup(path, output)
	if result.ok:
		managed_ids[path] = seen
		result["count"] = output.size()
	return result

static func write_with_backup(path: String, records: Array) -> Dictionary:
	var problem: String = validate_records(records)
	if not problem.is_empty():
		return failure(problem)
	var absolute: String = ProjectSettings.globalize_path(path)
	var suffix: String = "%s-%d" % [Time.get_datetime_string_from_system().replace(":", "-"), Time.get_ticks_usec()]
	var temporary: String = absolute + ".tmp-" + suffix
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return failure("Cannot write temporary JSON: " + error_string(FileAccess.get_open_error()))
	file.store_string(JSON.stringify(records, "\t", false, true) + "\n")
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		DirAccess.remove_absolute(temporary)
		return failure("Could not finish writing JSON: " + error_string(error))
	var backup: String = ""
	if FileAccess.file_exists(absolute):
		backup = absolute + ".bak-" + suffix
		error = DirAccess.copy_absolute(absolute, backup)
		if error != OK:
			DirAccess.remove_absolute(temporary)
			return failure("Backup failed; original JSON was not changed: " + error_string(error))
	# Same-directory rename replaces the destination only after the complete file
	# and its backup exist. Failed writes never truncate the original JSON.
	error = DirAccess.rename_absolute(temporary, absolute)
	if error != OK:
		DirAccess.remove_absolute(temporary)
		return failure("Could not replace JSON; original retained: " + error_string(error))
	return {"ok": true, "backup": backup}

func load_world(world: WorldMapScene, domain: Enums.InfrDomain, history: Object) -> Dictionary:
	var path: String = path_for(world, domain)
	var source: Dictionary = read_records(path)
	if not source.ok:
		return source
	if not source.exists:
		return failure("No JSON file exists at " + path)
	var container: Node3D = container_for(world, domain)
	if container == null:
		return failure("The open world has no matching infrastructure container.")
	var roots: Array[Node] = []
	var ids: Dictionary = {}
	for record: Dictionary in source.records:
		var num: int = int(record.num)
		ids[num] = true
		var line: EditorInfrLine3D = EditorInfrLine3D.of(domain, num, record.get("name", "unnamed"), record.get("autosmooth", true))
		line.create_curve_from_dict(record)
		var inverse: Transform3D = container.global_transform.affine_inverse()
		line.position = inverse * WorldUtils.vec3_from_float_arr(record.points[0].pos)
		for idx: int in range(line.curve.point_count):
			line.curve.set_point_position(idx, inverse * line.curve.get_point_position(idx) - line.position)
			line.curve.set_point_in(idx, inverse.basis * line.curve.get_point_in(idx))
			line.curve.set_point_out(idx, inverse.basis * line.curve.get_point_out(idx))
		roots.append(line)
	var old_roots: Array[Node] = domain_roots(container, domain)
	var old_owners: Dictionary = {}
	for node: Node in container.find_children("*", "", true, false):
		old_owners[node] = node.owner
	var new_owners: Dictionary = {}
	for root: Node in roots:
		new_owners[root] = world
		for node: Node in root.find_children("*", "", true, false):
			if node is EditorInfrLine3D:
				new_owners[node] = world
	history.create_action("Load roads JSON" if domain == Enums.InfrDomain.ROAD else "Load rails JSON", UndoRedo.MERGE_DISABLE, world)
	history.add_do_method(self, "replace_domain", container, {"roots": roots, "owners": new_owners, "domain": domain})
	history.add_undo_method(self, "replace_domain", container, {"roots": old_roots, "owners": old_owners, "domain": domain})
	history.add_do_method(self, "set_managed", path, ids)
	history.add_undo_method(self, "set_managed", path, managed_ids.get(path, {}).duplicate())
	for node: Node in roots:
		history.add_do_reference(node)
	for node: Node in old_roots:
		history.add_undo_reference(node)
	history.commit_action()
	return {"ok": true, "count": source.records.size()}

func set_managed(path: String, ids: Dictionary) -> void:
	managed_ids[path] = ids

static func domain_roots(cache: Node3D, domain: Enums.InfrDomain) -> Array[Node]:
	var roots: Array[Node] = []
	for node: Node in cache.get_children():
		if node is EditorInfrLine3D and node.infr_domain == domain:
			roots.append(node)
	return roots

func replace_domain(cache: Node3D, state: Dictionary) -> void:
	for node: Node in domain_roots(cache, state.domain):
		cache.remove_child(node)
	for node: Node in state.roots:
		cache.add_child(node)
	for node: Node in state.owners:
		if is_instance_valid(node) and node.is_inside_tree() and state.owners[node] != null:
			node.owner = state.owners[node]

func flush_saved(world: WorldMapScene, domain: Enums.InfrDomain, history: Object) -> void:
	var cache: Node3D = container_for(world, domain)
	var roots: Array[Node] = domain_roots(cache, domain)
	var owners: Dictionary = {}
	for node: Node in roots:
		owners[node] = world
	var path: String = path_for(world, domain)
	# Keep the flush undoable. A detached node remains in history until the map
	# closes, avoiding invalidating earlier creation/edit actions by freeing it.
	history.create_action("Clear saved infrastructure cache", UndoRedo.MERGE_DISABLE, world)
	history.add_do_method(self, "replace_domain", cache, {"roots": [], "owners": {}, "domain": domain})
	history.add_undo_method(self, "replace_domain", cache, {"roots": roots, "owners": owners, "domain": domain})
	# An empty flushed cache must not mean "delete all saved roads" on next Save.
	history.add_do_method(self, "set_managed", path, {})
	history.add_undo_method(self, "set_managed", path, managed_ids.get(path, {}).duplicate())
	for node: Node in roots:
		history.add_undo_reference(node)
	history.commit_action()
