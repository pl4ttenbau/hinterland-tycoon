@tool
## Loads JSON stop anchors as editor-only signs, preserving previews on invalid input.
class_name EditorStopLabelsStore extends RefCounted

const SIGN_SCENE_PATH: String = "res://scenes/subscenes/infr/station/sign/station_sign_3d.tscn"
const LABEL_HEIGHT: float = 15.0

func load_world(world: WorldEditorObjects, history: Object = null) -> EditorActionResult:
	if world.map_key.is_empty() or world.map_key.get_file() != world.map_key or world.map_key in [".", ".."]:
		return EditorActionResult.failure("The EditorObjects scene needs a valid map_key.")
	var catalog := InterchangesLoader.new()
	var error: Error = catalog.load_interchanges(world.map_key)
	if error != OK:
		catalog.free()
		return EditorActionResult.failure("Cannot load interchanges.json: " + error_string(error))
	var placements: Array[EditorStopLabelPlacement] = []
	var result: EditorActionResult = _collect_placements(world, catalog, placements)
	catalog.free()
	if not result.ok:
		return result
	var container: Node3D = get_or_create_stops_container(world)
	var labels: Array[Node] = []
	for placement: EditorStopLabelPlacement in placements:
		labels.append(_create_stop_label(placement, container))
	_commit_labels(container, labels, world, history)
	return EditorActionResult.success(labels.size())

func _collect_placements(world: WorldEditorObjects, catalog: InterchangesLoader, placements: Array[EditorStopLabelPlacement]) -> EditorActionResult:
	# Resolve the complete catalog before touching the existing labels. Bad JSON
	# or an out-of-range anchor must not erase a previously loaded preview.
	var networks: Dictionary = {}
	for stop: Dictionary in catalog.stop_definitions:
		var result: EditorActionResult = _collect_stop_placement(world, stop, catalog, networks, placements)
		if not result.ok:
			return result
	return EditorActionResult.success(placements.size())

func _load_network(world: WorldEditorObjects, domain: String, networks: Dictionary) -> EditorActionResult:
	if networks.has(domain):
		return EditorActionResult.success()
	var mode: Enums.InfrDomain = Enums.InfrDomain.RAIL if domain == "RAIL" else Enums.InfrDomain.ROAD
	var source: InfrCatalogReadResult = InfrJsonStore.read_records(InfrJsonStore.path_for(world, mode))
	if not source.ok:
		return EditorActionResult.failure(source.error)
	var records: Dictionary = {}
	for record: Dictionary in source.records:
		records[int(record["num"])] = record
	networks[domain] = records
	return EditorActionResult.success()

func _collect_stop_placement(world: WorldEditorObjects, stop: Dictionary, catalog: InterchangesLoader, networks: Dictionary, placements: Array[EditorStopLabelPlacement]) -> EditorActionResult:
	var domain: String = stop["domain"]
	var result: EditorActionResult = _load_network(world, domain, networks)
	if not result.ok:
		return result
	var anchor_key: String = "trackNum" if domain == "RAIL" else "roadNum"
	var infrastructure: Dictionary = networks[domain].get(int(stop[anchor_key]), {})
	var index: int = int(stop["nodeIndex"])
	if infrastructure.is_empty() or index >= infrastructure["points"].size():
		return EditorActionResult.failure("Stop %d references missing %s/node %d." % [int(stop["num"]), anchor_key, index])
	var interchange: InterchangeData = catalog.by_num[int(stop["interchangeNum"])]
	var placement: EditorStopLabelPlacement = EditorStopLabelPlacement.from_definition(stop, interchange.interchange_name,
		WorldUtils.vec3_from_float_arr(infrastructure["points"][index]["pos"]))
	if placement == null:
		return EditorActionResult.failure("Invalid stop label placement.")
	placements.append(placement)
	return EditorActionResult.success()

func _create_stop_label(placement: EditorStopLabelPlacement, container: Node3D) -> StationSign3D:
	var label: StationSign3D = load(SIGN_SCENE_PATH).instantiate()
	label.name = "%sStop_%d" % ["Rail" if placement.domain == Enums.InfrDomain.RAIL else "Road", placement.stop_num]
	label.station_name = placement.station_name
	label.position = container.to_local(placement.position + Vector3.UP * LABEL_HEIGHT)
	label.visibility_range_end = 0.0
	label.set_meta("stop_num", placement.stop_num)
	label.set_meta("interchange_num", placement.interchange_num)
	label.set_meta("domain", "RAIL" if placement.domain == Enums.InfrDomain.RAIL else "ROAD")
	label.set_meta("node_index", placement.node_index)
	return label

func _commit_labels(container: Node3D, labels: Array[Node], world: WorldEditorObjects, history: Object) -> void:
	var previous: EditorSceneSnapshot = EditorSceneSnapshot.capture(container)
	var state: EditorSceneSnapshot = EditorSceneSnapshot.for_nodes(labels, world)
	if history != null:
		history.create_action("Load stop labels JSON into EditorObjects", UndoRedo.MERGE_DISABLE, world)
		history.add_do_method(self, "replace_labels", container, state)
		history.add_undo_method(self, "replace_labels", container, previous)
		for label: Node in labels:
			history.add_do_reference(label)
		for label: Node in previous.roots:
			history.add_undo_reference(label)
		history.commit_action()
	else:
		self.replace_labels(container, state)
		for label: Node in previous.roots:
			label.queue_free()

func replace_labels(container: Node3D, state: EditorSceneSnapshot) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
	for label: Node in state.roots:
		container.add_child(label)
	state.restore_owners()

func get_or_create_stops_container(world: WorldEditorObjects) -> Node3D:
	var container := world.get_node_or_null("EditorStops") as Node3D
	if container == null:
		container = Node3D.new()
		container.name = "EditorStops"
		world.add_child(container)
		container.owner = world
	return container
