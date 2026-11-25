## Writes stops and interchanges built in game back into the map's interchanges.json, so placing stops in
## game can replace hand-authoring them in the editor.
##
## A merge, not a rewrite: the file stays the source of truth. Every record already in it is kept exactly as
## it is, including fields only tools read (the editor's "editorPosition") and its key order. Only what the
## file does not know yet is added: whole interchanges created in game, and new stops of interchanges it
## already has. Exporting twice adds nothing the second time.
##
## Moving or deleting authored stops in game is not supported, so the export never changes or removes a
## record. If the file and the game disagree about a number (someone saved the editor while the game ran),
## the export stops with an error instead of guessing which one is right.
class_name InterchangesExporter extends RefCounted

## Merge the live `interchanges` into `file_records` (the parsed catalog; left unchanged).
## Returns {"error": "" or the reason, "records": the merged catalog, "stops": stops added,
## "interchanges": interchanges added}. Counts include the stops of added interchanges.
static func merge(file_records: Array, interchanges: Array[InterchangeData]) -> Dictionary:
	var records: Array = file_records.duplicate(true)
	var records_by_num: Dictionary = {}
	# Stop number -> number of the interchange the file lists it under. Stop numbers are unique across
	# the whole catalog (InterchangesLoader checks that), so this tells exported stops from collisions.
	var file_stop_parents: Dictionary = {}
	for record: Dictionary in records:
		records_by_num[int(record["num"])] = record
		for stop: Dictionary in record["stops"]:
			file_stop_parents[int(stop["num"])] = int(record["num"])
	var added_stops: int = 0
	var added_interchanges: int = 0
	for interchange: InterchangeData in interchanges:
		var record: Dictionary = records_by_num.get(interchange.num, {})
		if record.is_empty():
			# All of it is new. Its stop numbers must be new as well.
			for stop: AbstractStation in interchange.stops:
				if file_stop_parents.has(stop.num):
					return _conflict("Stop %d of new interchange %d is already in the file under interchange %d" \
						% [stop.num, interchange.num, file_stop_parents[stop.num]])
			records.append(InterchangeMapper.interchange_to_dict(interchange))
			added_interchanges += 1
			added_stops += interchange.stops.size()
			continue
		# The same number must still mean the same interchange; a renamed or retowned record means the file
		# was changed by someone else since the game loaded it.
		if record["name"] != interchange.interchange_name or int(record["townNum"]) != interchange.town_num:
			return _conflict("Interchange %d is \"%s\" in the file but \"%s\" in game" \
				% [interchange.num, record["name"], interchange.interchange_name])
		for stop: AbstractStation in interchange.stops:
			if not file_stop_parents.has(stop.num):
				record["stops"].append(StopMapper.stop_to_dict(stop))
				added_stops += 1
			elif file_stop_parents[stop.num] != interchange.num:
				return _conflict("Stop %d belongs to interchange %d in the file but to %d in game" \
					% [stop.num, file_stop_parents[stop.num], interchange.num])
	return {"error": "", "records": records, "stops": added_stops, "interchanges": added_interchanges}

## Merge the live interchanges into the catalog at `path` and write it (with a backup) when anything was
## added. Returns merge()'s counts plus "backup" (the backup's path, "" when nothing was written).
static func export_to(path: String, interchanges: Array[InterchangeData]) -> Dictionary:
	if path.is_empty():
		return {"error": "No interchange catalog is loaded.", "backup": "", "stops": 0, "interchanges": 0}
	# Read the file again rather than trusting what was loaded: it may have been saved since.
	var parser := JSON.new()
	if not FileAccess.file_exists(path) or parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"error": "Cannot read %s" % path, "backup": "", "stops": 0, "interchanges": 0}
	if InterchangesLoader.validate_definitions(parser.data) != OK:
		return {"error": "%s is invalid; fix it before exporting" % path, "backup": "", "stops": 0, "interchanges": 0}
	var merged: Dictionary = merge(parser.data, interchanges)
	merged["backup"] = ""
	if not merged.error.is_empty():
		return merged
	if merged.stops == 0 and merged.interchanges == 0:
		return merged
	# The merged catalog must load again before it replaces a good file.
	if InterchangesLoader.validate_definitions(merged.records) != OK:
		merged.error = "The merged catalog is invalid; %s was not changed" % path
		return merged
	var written: Dictionary = JsonFileUtils.write_text_with_backup(path, JsonFileUtils.catalog_text(merged.records))
	merged.error = written.error
	merged.backup = written.backup
	return merged

static func _conflict(message: String) -> Dictionary:
	return {"error": message + "; reload the map before exporting.", "records": [], "stops": 0, "interchanges": 0}
