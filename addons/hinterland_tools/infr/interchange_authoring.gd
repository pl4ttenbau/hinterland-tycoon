@tool
extends RefCounted

const JOIN_RADIUS_METRES: float = 50.0

## Read only saved infrastructure so a stop cannot reference a draft node.
func prepare(world: WorldMapScene, line: EditorInfrLine3D, index: int, adding_stop: bool) -> Dictionary:
	if InfrJsonStore.path_for(world, line.infr_domain).is_empty():
		return {"error": "The world needs a valid map key."}
	var path: String = InterchangesLoader.CATALOG_PATH_FORMAT % world.map_key
	var exists: bool = FileAccess.file_exists(path)
	var original: String = FileAccess.get_file_as_string(path) if exists else ""
	var records: Variant = JSON.parse_string(original) if exists else []
	if InterchangesLoader.validate_definitions(records) != OK:
		return {"error": "Invalid interchange catalog. Check the editor output."}
	var network: Dictionary = {}
	for domain: Enums.InfrDomain in [Enums.InfrDomain.ROAD, Enums.InfrDomain.RAIL]:
		var source: InfrCatalogReadResult = InfrJsonStore.read_records(InfrJsonStore.path_for(world, domain))
		if not source.ok:
			return {"error": source.error}
		var lines: Dictionary = {}
		for record: Dictionary in source.records:
			lines[int(record.num)] = record.points
		network["ROAD" if domain == Enums.InfrDomain.ROAD else "RAIL"] = lines
	var domain_key: String = "ROAD" if line.infr_domain == Enums.InfrDomain.ROAD else "RAIL"
	var id_key: String = "roadNum" if domain_key == "ROAD" else "trackNum"
	var anchor: Dictionary = {"domain": domain_key, "nodeIndex": index}
	anchor[id_key] = line.num
	var position: Vector3 = _anchor_position(anchor, network)
	if not position.is_finite() or not position.is_equal_approx(line.to_global(line.curve.get_point_position(index))):
		return {"error": "This node differs from saved infrastructure. Save and reload the infrastructure JSON first."}

	var candidates: Array[Dictionary] = []
	var next_stop: int = 0
	var next_interchange: int = 0
	for record: Dictionary in records:
		next_interchange = maxi(next_interchange, int(record.num) + 1)
		var distance: float = INF
		var has_manual_position: bool = InfrJsonStore.valid_vector(record.get("editorPosition"))
		if has_manual_position:
			distance = position.distance_to(WorldUtils.vec3_from_float_arr(record.editorPosition))
		for stop: Dictionary in record.stops:
			next_stop = maxi(next_stop, int(stop.num) + 1)
			if not has_manual_position:
				var stop_position: Vector3 = _anchor_position(stop, network)
				if stop_position.is_finite():
					distance = minf(distance, position.distance_to(stop_position))
			if adding_stop and stop.domain == domain_key and int(stop[id_key]) == line.num and int(stop.nodeIndex) == index:
				return {"error": "A stop already exists at this infrastructure node."}
		if distance <= JOIN_RADIUS_METRES:
			candidates.append({"record": record, "distance": distance})
	if adding_stop and candidates.is_empty():
		return {"error": "No interchange within 50 m. Place an interchange first."}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.record.num) < int(b.record.num) if a.distance == b.distance else a.distance < b.distance)
	return {"path": path, "exists": exists, "original": original, "records": records,
		"position": position, "anchor": anchor, "candidates": candidates,
		"next_stop": next_stop, "next_interchange": next_interchange}

func save(draft: Dictionary) -> EditorActionResult:
	var path: String = draft.path
	if FileAccess.file_exists(path) != draft.exists or (draft.exists and FileAccess.get_file_as_string(path) != draft.original):
		return EditorActionResult.failure("Interchange JSON changed. Pick the node again to reload it.")
	if InterchangesLoader.validate_definitions(draft.records) != OK:
		return EditorActionResult.failure("Invalid interchange or stop. Check the editor output.")
	return InfrJsonStore.write_text_with_backup(path, JSON.stringify(draft.records, "\t") + "\n")

func _anchor_position(anchor: Dictionary, network: Dictionary) -> Vector3:
	var key: String = "roadNum" if anchor.domain == "ROAD" else "trackNum"
	var points: Array = network[anchor.domain].get(int(anchor[key]), [])
	var index: int = int(anchor.nodeIndex)
	return WorldUtils.vec3_from_float_arr(points[index].pos) if index >= 0 and index < points.size() else Vector3.INF
