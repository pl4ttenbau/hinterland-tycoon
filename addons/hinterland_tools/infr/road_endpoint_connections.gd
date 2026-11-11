@tool
class_name RoadEndpointConnection extends Node

# Much smaller than the pointer's snap radius: crossings mean coincident road
# endpoints in XYZ, not roads passing close to each other or over a bridge.
const JOIN_DISTANCE: float = 0.02
const SERVICE_NAME: String = "_RoadEndpointConnections"
var lines: Dictionary = {}
var pending: bool = false
var edit_history: Object

static func ensure(world: Node) -> RoadEndpointConnection:
	var service := world.get_node_or_null(SERVICE_NAME) as RoadEndpointConnection
	if service == null:
		service = RoadEndpointConnection.new()
		service.name = SERVICE_NAME
		world.add_child(service)
	# No scene owner: this editor helper and the markers are never saved.
	return service

func register(line: Node3D) -> void:
	lines[line.get_instance_id()] = weakref(line)
	request_update()

func unregister(line: Node3D) -> void:
	lines.erase(line.get_instance_id())
	request_update()

func request_update() -> void:
	# Curve edits can emit several signals (e.g. smoothing every handle). Collapse
	# them into one map-wide update rather than scanning the scene for each line.
	if not pending:
		pending = true
		rebuild.call_deferred()

static func visible_roads(world: Node) -> Array[Node3D]:
	var by_id: Dictionary = {}
	var cache: Node = world.get_node_or_null("EditorCache")
	for node: Node in world.find_children("*", "", true, false):
		if node is EditorInfrLine3D and node.infr_domain == Enums.InfrDomain.ROAD and node.is_visible_in_tree() and node.curve and node.curve.point_count >= 2:
			# An explicitly loaded cached road is the editable version of that ID.
			if not by_id.has(node.num) or (cache != null and cache.is_ancestor_of(node)):
				by_id[node.num] = node
	var result: Array[Node3D] = []
	result.assign(by_id.values())
	return result

static func entries_for(roads: Array[Node3D]) -> Array[EditorRoadEndpoint]:
	var entries: Array[EditorRoadEndpoint] = []
	for line: Node3D in roads:
		for end: int in [0, 1]:
			var idx: int = 0 if end == 0 else line.curve.point_count - 1
			entries.append(EditorRoadEndpoint.new(line.num, end, line.to_global(line.curve.get_point_position(idx)), idx))
	return entries

static func neighbors(entries: Array[EditorRoadEndpoint]) -> Array:
	var result: Array = []
	var cells: Dictionary = {}
	var positions: PackedVector3Array = []
	# Compare the same centimetre-rounded geometry used by JSON saving. Otherwise
	# a connection close to the tolerance boundary could change merely on reload.
	for entry: EditorRoadEndpoint in entries:
		var p: Vector3 = entry.position
		positions.append(Vector3(roundf(p.x * 100.0), roundf(p.y * 100.0), roundf(p.z * 100.0)) / 100.0)
	for idx: int in range(entries.size()):
		result.append([])
		var cell := Vector3i((positions[idx] / JOIN_DISTANCE).floor())
		# Adjacent cells are checked too: points on either side of a hash boundary
		# can still be within tolerance. This avoids an all-pairs road scan.
		for x: int in range(-1, 2):
			for y: int in range(-1, 2):
				for z: int in range(-1, 2):
					for other: int in cells.get(cell + Vector3i(x, y, z), []):
						if entries[idx].road_num != entries[other].road_num and positions[idx].distance_squared_to(positions[other]) <= JOIN_DISTANCE * JOIN_DISTANCE:
							result[idx].append(other)
							result[other].append(idx)
		if not cells.has(cell):
			cells[cell] = []
		cells[cell].append(idx)
	return result

func rebuild() -> void:
	pending = false
	if not is_inside_tree():
		return
	var roads: Array[Node3D] = visible_roads(get_parent())
	var entries: Array[EditorRoadEndpoint] = entries_for(roads)
	var links: Array = neighbors(entries)
	_clear_inactive_roads(roads)
	for road_index: int in range(roads.size()):
		_apply_road_connections(roads[road_index], road_index, entries, links)

func _clear_inactive_roads(roads: Array[Node3D]) -> void:
	# Hidden/deleted neighbors must not leave stale junctions in the Inspector.
	var no_connections: Array[EditorEndpointConnection] = []
	for id: int in lines.keys():
		var line: Node = lines[id].get_ref()
		if not is_instance_valid(line):
			lines.erase(id)
		elif line not in roads:
			line.apply_endpoint_connections(no_connections, no_connections, false, false)

func _apply_road_connections(road: Node3D, road_index: int, entries: Array[EditorRoadEndpoint], links: Array) -> void:
	var start_connections: Array[EditorEndpointConnection] = []
	var end_connections: Array[EditorEndpointConnection] = []
	var markers: Array[bool] = [false, false]
	for end: int in [0, 1]:
		# entries_for() emits the start/end pair consecutively for each road.
		var index: int = road_index * 2 + end
		var representative: int = index
		for other: int in links[index]:
			var connection: EditorEndpointConnection = EditorEndpointConnection.of(entries[other].road_num, entries[other].endpoint)
			(start_connections if end == 0 else end_connections).append(connection)
			representative = mini(representative, other)
		# One marker per shared junction, avoiding overlapping balls.
		markers[end] = not links[index].is_empty() and representative == index
	road.apply_endpoint_connections(start_connections, end_connections, markers[0], markers[1])

static func update_json(records: Dictionary) -> void:
	var entries: Array[EditorRoadEndpoint] = _json_endpoints(records)
	var links: Array = neighbors(entries)
	for index: int in range(entries.size()):
		_update_endpoint_crossing(index, entries, links, records)

static func _json_endpoints(records: Dictionary) -> Array[EditorRoadEndpoint]:
	var entries: Array[EditorRoadEndpoint] = []
	for id: int in records:
		var points: Array = records[id].points
		for end: int in [0, 1]:
			var index: int = 0 if end == 0 else points.size() - 1
			entries.append(EditorRoadEndpoint.new(id, end, WorldUtils.vec3_from_float_arr(points[index].pos), index))
	return entries

static func _update_endpoint_crossing(index: int, entries: Array[EditorRoadEndpoint], links: Array, records: Dictionary) -> void:
	var entry: EditorRoadEndpoint = entries[index]
	var point: Dictionary = records[entry.road_num].points[entry.node_index]
	var cross: Dictionary = point.get("cross", {}).duplicate(true)
	var previous_auto: Array = cross.get("autoConnectiveRoads", [])
	var manual: Array = []
	for id: Variant in cross.get("connectiveRoads", []):
		if id not in previous_auto and id not in manual:
			manual.append(id)
	var automatic: Array = []
	for other: int in links[index]:
		var id: int = entries[other].road_num
		if id not in manual and id not in automatic:
			automatic.append(id)
	automatic.sort()
	# Keep provenance, so moving endpoints removes only generated connections.
	var combined: Array = manual + automatic
	combined.sort()
	if not combined.is_empty() or point.has("cross"):
		cross["connectiveRoads"] = combined
		if automatic.is_empty():
			cross.erase("autoConnectiveRoads")
		else:
			cross["autoConnectiveRoads"] = automatic
		point["cross"] = cross

func edit_in_cache(line: Node3D) -> Node3D:
	if not get_parent() is WorldMapScene:
		push_warning("Edit In Cache is available from the world scene. This EditorObjects scene can be inspected and saved directly.")
		return null
	if line.curve == null or line.curve.point_count < 2:
		push_warning("Edit In Cache needs a completed infrastructure line.")
		return null
	var world: Node = get_parent()
	var cache: Node3D = EditorCache.ensure_container(world, line.infr_domain)
	for existing: Node in cache.get_children():
		if existing is Path3D and existing.get("num") == line.num and existing.get("infr_domain") == line.infr_domain:
			return existing as Node3D
	if edit_history == null:
		push_warning("Edit In Cache requires the HinterlandTools plugin to be active for this map.")
		return null
	return _stage_cache_copy(line, cache, world)

func _stage_cache_copy(line: Node3D, cache: Node3D, world: Node) -> Node3D:
	# Copy authored properties, not derived marker/rendering children. The curve
	# must be independent: changing the edit must never change the reference view.
	var copy: Node3D = line.get_script().of(line.infr_domain, line.num, line.infr_name, line.autosmooth)
	copy.rail_gauge = line.rail_gauge
	copy.curve = line.curve.duplicate(true)
	copy.abs_aabb = line.abs_aabb
	copy.transform = cache.global_transform.affine_inverse() * line.global_transform
	# create history entry
	edit_history.create_action("Edit infrastructure in cache", UndoRedo.MERGE_DISABLE, world)
	edit_history.add_do_method(cache, "add_child", copy, true)
	edit_history.add_do_method(copy, "set_owner", world)
	edit_history.add_do_method(self, "refresh_source", line.infr_domain)
	edit_history.add_undo_method(cache, "remove_child", copy)
	edit_history.add_undo_method(self, "refresh_source", line.infr_domain)
	edit_history.add_do_reference(copy)
	edit_history.commit_action()
	return copy

func refresh_source(domain: int) -> void:
	EditorCache.refresh_source_visibility(get_parent(), domain)
	request_update()
