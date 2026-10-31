@tool
@icon("res://assets/icons/nodes_3d/icon_editor_cache.svg")
extends Node3D

## Local map-owned authoring lines. JSON saving/loading is handled by InfrJsonStore.
## This deliberately does not use the legacy EditorObjects container classes.
@export_group("Save JSON")
@export_tool_button("Save Roads JSON")
var save_roads_json = Callable(self, "do_save_roads_json")
@export_tool_button("Save Rails JSON")
var save_rails_json = Callable(self, "do_save_rails_json")

func do_save_roads_json() -> void:
	request_save(Enums.InfrDomain.ROAD)

func do_save_rails_json() -> void:
	request_save(Enums.InfrDomain.RAIL)

func request_save(domain: Enums.InfrDomain) -> void:
	# No file-writing code in this node. Include the requesting cache so the
	# receiver can reject requests from an inactive map instead of saving another.
	var bus: Node = preload("res://addons/hinterland_tools/editor_signals.gd").instance
	if not is_instance_valid(bus):
		push_warning("Enable HinterlandTools to save infrastructure JSON.")
		return
	bus.infrastructure_save_requested.emit(self, domain)

func _ready() -> void:
	if not Engine.is_editor_hint():
		visible = false
		return
	_prepare_existing.call_deferred()

func _prepare_existing() -> void:
	if not is_inside_tree() or not get_parent() is WorldMapScene:
		return
	for domain: Enums.InfrDomain in [Enums.InfrDomain.ROAD, Enums.InfrDomain.RAIL]:
		var present: bool = has_meta(_domain_key(domain))
		for node: Node in find_children("*", "", true, false):
			if node is EditorInfrLine3D and node.infr_domain == domain:
				present = true
		if present:
			_prepare_domain(get_parent(), self, domain)

static func _domain_key(domain: Enums.InfrDomain) -> String:
	return "initialized_roads" if domain == Enums.InfrDomain.ROAD else "initialized_rails"

static func ensure_container(world: WorldMapScene, domain: Enums.InfrDomain) -> Node3D:
	var cache: Node3D = world.get_node_or_null("EditorCache") as Node3D
	if cache == null:
		cache = Node3D.new()
		cache.name = "EditorCache"
		cache.set_script(load("res://addons/hinterland_tools/editor_cache.gd"))
		world.add_child(cache)
		cache.owner = world
	_prepare_domain(world, cache, domain)
	return cache

static func _prepare_domain(world: WorldMapScene, cache: Node3D, domain: Enums.InfrDomain) -> void:
	var legacy: Node3D
	for node: Node in world.find_children("*", "", true, false):
		if cache.is_ancestor_of(node):
			continue
		if (domain == Enums.InfrDomain.ROAD and node is GeneratedRoadWays) or (domain == Enums.InfrDomain.RAIL and node is GeneratedRailLines):
			legacy = node as Node3D
			break
	var key: String = _domain_key(domain)
	var cached_lines: Array[Node] = []
	for node: Node in cache.find_children("*", "", true, false):
		if node is EditorInfrLine3D and node.infr_domain == domain:
			cached_lines.append(node)
	# EditorObjects roads stay where they are. Only flatten geometry already in
	# the local cache; source-scene objects remain valid visible snap targets.
	var was_initialized: bool = cache.has_meta(key)
	for line: Node3D in cached_lines:
		if line.get_parent() != cache:
			line.reparent(cache, true)
		line.owner = world
	cache.set_meta(key, true)
	# Clear obsolete wrappers in the CACHE only. The original subscene is kept.
	var wrappers: Array[Node] = cache.find_children("*", "", true, false)
	wrappers.reverse()
	for node: Node in wrappers:
		if node.get_parent() != null and node.get_child_count() == 0 and (node is GeneratedRoadWays or node is GeneratedRailLines or (node.get_script() == null and node.name.contains("__"))):
			node.get_parent().remove_child(node)
			node.queue_free()
	# Older cache versions hid the entire source container. Undo that once on
	# upgrade; subsequent user visibility changes are left alone.
	var visibility_key: String = key + "_visible_sources"
	if legacy != null and was_initialized and not cache.has_meta(visibility_key):
		legacy.show()
	cache.set_meta(visibility_key, true)
	refresh_source_visibility(world, domain)

static func refresh_source_visibility(world: Node, domain: Enums.InfrDomain) -> void:
	var cache: Node = world.get_node_or_null("EditorCache")
	if cache == null:
		return
	var ids: Dictionary = {}
	for line: Node in cache.get_children():
		if line is EditorInfrLine3D and line.infr_domain == domain:
			ids[line.num] = true
	for line: Node in world.find_children("*", "", true, false):
		if not line is EditorInfrLine3D or cache.is_ancestor_of(line) or line.infr_domain != domain:
			continue
		# Hide only duplicate source IDs while their editable cached copy exists.
		# Remember our own hides, so flushing restores them without unhiding roads
		# the user deliberately hid. Other source roads remain visible throughout.
		if ids.has(line.num) and line.visible:
			line.set_meta("_cache_hidden_duplicate", true)
			line.hide()
		elif not ids.has(line.num) and line.get_meta("_cache_hidden_duplicate", false):
			line.remove_meta("_cache_hidden_duplicate")
			line.show()
