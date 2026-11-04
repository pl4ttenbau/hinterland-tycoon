@tool
## Nodes and scene ownership retained together for editor replacement and undo/redo.
class_name EditorSceneSnapshot extends RefCounted

var roots: Array[Node] = []
var owners: Dictionary[Node, Node] = {}
var world: Node
var domain: Enums.InfrDomain

static func for_nodes(nodes: Array[Node], owner: Node, scene: Node = null, mode: Enums.InfrDomain = Enums.InfrDomain.ROAD) -> EditorSceneSnapshot:
	var snapshot := EditorSceneSnapshot.new()
	snapshot.roots.assign(nodes)
	snapshot.world = scene
	snapshot.domain = mode
	for node: Node in nodes:
		snapshot.owners[node] = owner
	return snapshot

static func capture(container: Node, scene: Node = null, mode: Enums.InfrDomain = Enums.InfrDomain.ROAD) -> EditorSceneSnapshot:
	var snapshot: EditorSceneSnapshot = for_nodes(container.get_children(), null, scene, mode)
	for node: Node in container.find_children("*", "", true, false):
		if node.owner != null:
			snapshot.owners[node] = node.owner
	return snapshot

func restore_owners() -> void:
	# LinePath3D replaces transient children on tree entry; history must only
	# restore ownership on surviving authored nodes.
	for node: Node in owners:
		if is_instance_valid(node) and not node.is_queued_for_deletion() and owners[node] != null:
			node.owner = owners[node]
