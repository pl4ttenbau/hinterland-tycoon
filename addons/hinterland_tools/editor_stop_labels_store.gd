@tool
class_name EditorStopLabelsStore extends RefCounted

const SIGN_SCENE_PATH: String = "res://scenes/subscenes/infr/station/sign/station_sign_3d.tscn"
const LABEL_HEIGHT: float = 15.0

func load_world(world: WorldEditorObjects, history: Object = null) -> Dictionary:
	if world.map_key.is_empty() or world.map_key.get_file() != world.map_key or world.map_key in [".", ".."]:
		return InfrJsonStore.failure("The EditorObjects scene needs a valid map_key.")
	var catalog := InterchangesLoader.new()
	var error: Error = catalog.load_interchanges(world.map_key)
	if error != OK:
		catalog.free()
		return InfrJsonStore.failure("Cannot load interchanges.json: " + error_string(error))
	var networks: Dictionary = {}
	var placements: Array[Dictionary] = []
	# Resolve the complete catalog before touching the existing labels. Bad JSON
	# or an out-of-range anchor must not erase a previously loaded preview.
	for stop: Dictionary in catalog.stop_definitions:
		var domain: String = stop["domain"]
		if not networks.has(domain):
			var mode: Enums.InfrDomain = Enums.InfrDomain.RAIL if domain == "RAIL" else Enums.InfrDomain.ROAD
			var source: Dictionary = InfrJsonStore.read_records(InfrJsonStore.path_for(world, mode))
			if not source.ok:
				catalog.free()
				return source
			var records: Dictionary = {}
			for record: Dictionary in source.records:
				records[int(record["num"])] = record
			networks[domain] = records
		var anchor_key: String = "trackNum" if domain == "RAIL" else "roadNum"
		var infrastructure: Dictionary = networks[domain].get(int(stop[anchor_key]), {})
		var index: int = int(stop["nodeIndex"])
		if infrastructure.is_empty() or index >= infrastructure["points"].size():
			catalog.free()
			return InfrJsonStore.failure("Stop %d references missing %s/node %d." % [int(stop["num"]), anchor_key, index])
		var interchange: InterchangeData = catalog.by_num[int(stop["interchangeNum"])]
		placements.append({"stop": stop, "name": interchange.interchange_name,
			"position": WorldUtils.vec3_from_float_arr(infrastructure["points"][index]["pos"])})
	catalog.free()
	var container := world.get_node_or_null("EditorStops") as Node3D
	if container == null:
		container = Node3D.new()
		container.name = "EditorStops"
		world.add_child(container)
		container.owner = world
	var labels: Array[Node] = []
	var owners: Dictionary = {}
	for placement: Dictionary in placements:
		var stop: Dictionary = placement.stop
		var label: StationSign3D = load(SIGN_SCENE_PATH).instantiate()
		label.name = "%sStop_%d" % ["Rail" if stop["domain"] == "RAIL" else "Road", int(stop["num"])]
		label.station_name = placement.name
		label.position = container.to_local(placement.position + Vector3.UP * LABEL_HEIGHT)
		label.visibility_range_end = 0.0
		label.set_meta("stop_num", int(stop["num"]))
		label.set_meta("interchange_num", int(stop["interchangeNum"]))
		label.set_meta("domain", stop["domain"])
		label.set_meta("node_index", int(stop["nodeIndex"]))
		labels.append(label)
		owners[label] = world
	var previous: Array[Node] = container.get_children()
	var previous_owners: Dictionary = {}
	for label: Node in previous:
		previous_owners[label] = label.owner
	if history != null:
		history.create_action("Load stop labels JSON into EditorObjects", UndoRedo.MERGE_DISABLE, world)
		history.add_do_method(self, "replace_labels", container, labels, owners)
		history.add_undo_method(self, "replace_labels", container, previous, previous_owners)
		for label: Node in labels:
			history.add_do_reference(label)
		for label: Node in previous:
			history.add_undo_reference(label)
		history.commit_action()
	else:
		self.replace_labels(container, labels, owners)
		for label: Node in previous:
			label.queue_free()
	return {"ok": true, "count": labels.size()}

func replace_labels(container: Node3D, labels: Array[Node], owners: Dictionary) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
	for label: Node in labels:
		container.add_child(label)
		label.owner = owners[label]
