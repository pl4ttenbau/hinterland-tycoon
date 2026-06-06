@tool
extends RefCounted

const Shared: Resource = preload("res://addons/GodotSignalChecker/scripts/shared.gd")


static func scan_project() -> Array:
	# Scans every .tscn in the project and returns a list of broken connections.
	var results: Array = []
	for path in _collect_scenes("res://"):
		results.append_array(_check_scene(path))
	
	return results


static func _collect_scenes(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(root)
	
	if dir == null:
		return out
	
	dir.list_dir_begin()
	var name: String = dir.get_next()
	
	while name != "":
		# Skip hidden dirs (.godot, .git, ...)
		if not name.begins_with("."):
			var full: String = root.path_join(name)
			if dir.current_is_dir():
				# ignore any folder that has a .gdignore inside it
				if FileAccess.file_exists(full.path_join(".gdignore")):
					pass
				else:
					out.append_array(_collect_scenes(full))
			
			elif name.ends_with(".tscn"):
				out.append(full)
		
		name = dir.get_next()
	
	dir.list_dir_end()
	return out


static func _check_scene(path: String) -> Array:
	var results: Array = []
	var pack: PackedScene = load(path) as PackedScene
	
	if pack == null:
		return results

	var state: SceneState = pack.get_state()
	var connection_count: int = state.get_connection_count()
	if connection_count == 0:
		return results

	var root: Node = pack.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	if root == null:
		return results

	for i in connection_count:
		var src_path: NodePath = state.get_connection_source(i)
		var dst_path: NodePath = state.get_connection_target(i)
		var signal_name: StringName = state.get_connection_signal(i)
		var method: StringName = state.get_connection_method(i)
		var target: Node = root.get_node_or_null(dst_path)

		if target == null:
			# Target node itself is missing - still a broken connection.
			results.append(_make_report_entry(path, state, i, false))
			continue

		if not _target_has_method(target, method):
			results.append(_make_report_entry(path, state, i, false))
			continue

		if Shared.read_scan_parameter():
			var source_node: Node = root.get_node_or_null(src_path)
			if source_node == null:
				continue

			var binds: Array = state.get_connection_binds(i)
			var unbinds: int = state.get_connection_unbinds(i)
			if not _parameter_counts_match(source_node, target, signal_name, method, binds.size(), unbinds):
				results.append(_make_report_entry(path, state, i, true))

	root.queue_free()
	return results


static func _parameter_counts_match(
	source: Node,
	target: Node,
	signal_name: StringName,
	method_name: StringName,
	bind_count: int,
	unbind_count: int
) -> bool:
	var signal_args: int = _signal_argument_count(source, signal_name)
	var method_info: Dictionary = _method_info(target, method_name)

	if signal_args < 0 or method_info.is_empty():
		# could not introspect - don't flag as broken.
		Shared.debug_log("could not introspect: %s -> %s " % [signal_name, method_name])
		return true

	var delivered: int = signal_args - unbind_count + bind_count
	var total_params: int = (method_info["args"] as Array).size()
	var default_params: int = (method_info["default_args"] as Array).size()
	var required_params: int = total_params - default_params
	var ok: bool = delivered >= required_params and delivered <= total_params

	Shared.debug_log(
		"%s.%s -> delivered=%d, accepts: requires=%d total=%d %s" % [
			target.name,
			method_name,
			delivered,
			required_params,
			total_params,
			"OK" if ok else "WRONG PARAMETER COUNT"
		]
	)
	return ok


static func _signal_argument_count(node: Node, signal_name: StringName) -> int:
	for signal_info in node.get_signal_list():
		if signal_info["name"] == signal_name:
			return (signal_info["args"] as Array).size()
	return -1


static func _method_info(node: Node, method_name: StringName) -> Dictionary:
	for method_info in node.get_method_list():
		if method_info["name"] == method_name:
			return method_info
	return {}


static func _target_has_method(target: Node, method: StringName) -> bool:
	var script: Script = target.get_script() as Script
	var result: bool
		
	result = target.has_method(method)

	var script_path: String = script.resource_path if script != null else "<none>"
	Shared.debug_log("%s.%s script=%s -> %s" % [target.name, method, script_path, "OK" if result else "MISSING"])
	return result


static func _make_report_entry(path: String, state: SceneState, idx: int, wrong_parameter_count: bool) -> Dictionary:
	return {
		"scene_path": path,
		"source_node_path": state.get_connection_source(idx),
		"signal_name": state.get_connection_signal(idx),
		"target_node_path": state.get_connection_target(idx),
		"method_name": state.get_connection_method(idx),
		"wrong_parameter_count": wrong_parameter_count
	}
