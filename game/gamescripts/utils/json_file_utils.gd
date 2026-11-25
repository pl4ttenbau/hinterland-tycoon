@tool
## Writing the map's JSON catalogs from game code and editor tools alike: catalog text in the style of
## the existing files, and a safe replace with one backup. (Moved here from the editor addon on
## 2026-11-23, so the game can export stops without depending on addons/.)
class_name JsonFileUtils extends RefCounted

## Catalog text (e.g. interchanges.json), tab-indented like the existing files. JSON parsing returns
## every number as a float, which would come back out as "num": 2.0: whole numbers in object fields (IDs,
## node indices) are written as integers again. Fractions such as nodeOffset stay, and so do array
## elements (positions).
static func catalog_text(records: Array) -> String:
	# Keys keep their order (no sort_keys): a save must not reorder every record in the diff.
	return JSON.stringify(_whole_numbers_as_ints(records), "\t", false) + "\n"

static func _whole_numbers_as_ints(value: Variant) -> Variant:
	if value is Dictionary:
		var out: Dictionary = {}
		for key: Variant in value:
			var field: Variant = value[key]
			out[key] = int(field) if field is float and is_finite(field) and field == floorf(field) else _whole_numbers_as_ints(field)
		return out
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(_whole_numbers_as_ints(item) if item is Dictionary or item is Array else item)
		return items
	return value

## Replace the file at `path` with `contents`: written to a temporary file first, then the old file is
## copied to "<file>.bak-<time>", then the temporary file takes its place. Any failure leaves the
## original untouched. Older backups of the same file are removed afterwards; the new one is enough.
## Returns {"error": "" or the reason, "backup": the backup's path, "" when there was no file before}.
static func write_text_with_backup(path: String, contents: String) -> Dictionary:
	var absolute: String = ProjectSettings.globalize_path(path)
	var suffix: String = "%s-%d" % [Time.get_datetime_string_from_system().replace(":", "-"), Time.get_ticks_usec()]
	var temporary: String = absolute + ".tmp-" + suffix
	var problem: String = _write_temporary(temporary, contents)
	if not problem.is_empty():
		return {"error": problem, "backup": ""}
	var backup: String = ""
	if FileAccess.file_exists(absolute):
		backup = absolute + ".bak-" + suffix
		var backup_error: Error = DirAccess.copy_absolute(absolute, backup)
		if backup_error != OK:
			DirAccess.remove_absolute(temporary)
			return {"error": "Backup failed; original JSON was not changed: " + error_string(backup_error), "backup": ""}
	# Replace only after the complete temporary file and backup exist.
	var error: Error = DirAccess.rename_absolute(temporary, absolute)
	if error != OK:
		DirAccess.remove_absolute(temporary)
		return {"error": "Could not replace JSON; original retained: " + error_string(error), "backup": ""}
	if not backup.is_empty():
		_remove_older_backups(absolute, backup)
	return {"error": "", "backup": backup}

## Delete every earlier "<file>.bak-*" next to `absolute`, keeping only `keep`. Runs only after a
## successful save, so the newest backup always exists before older ones go. Failures are ignored:
## a leftover backup is harmless, and the save itself already succeeded.
static func _remove_older_backups(absolute: String, keep: String) -> void:
	var directory: String = absolute.get_base_dir()
	var prefix: String = absolute.get_file() + ".bak-"
	for file: String in DirAccess.get_files_at(directory):
		var candidate: String = directory.path_join(file)
		if file.begins_with(prefix) and candidate != keep:
			DirAccess.remove_absolute(candidate)

static func _write_temporary(path: String, contents: String) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "Cannot write temporary JSON: " + error_string(FileAccess.get_open_error())
	file.store_string(contents)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		DirAccess.remove_absolute(path)
		return "Could not finish writing JSON: " + error_string(error)
	return ""
