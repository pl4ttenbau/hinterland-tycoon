@tool
extends Node3D

## Local map-owned authoring lines. JSON saving/loading is handled by InfrJsonStore.
## This deliberately does not use the legacy EditorObjects container classes.
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
	# Existing cached geometry wins over legacy scene copies when upgrading the
	# old grouped layout. Otherwise adopt legacy lines once, preserving position.
	if not cache.has_meta(key) and cached_lines.is_empty() and legacy != null:
		for node: Node in legacy.find_children("*", "", true, false):
			if node is EditorInfrLine3D and node.infr_domain == domain:
				cached_lines.append(node)
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
	if legacy != null:
		legacy.visible = false
