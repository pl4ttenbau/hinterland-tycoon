## Road-section graph: shape nodes stay in curves; first/last anchors attach per query.
class_name RoadPathfinder extends RefCounted

const JOIN_TOLERANCE: float = 0.1

class Graph extends AStar3D:
	var costs: Dictionary = {}
	func _compute_cost(from_id: int, to_id: int) -> float:
		return costs[Vector2i(from_id, to_id)]

var _graph := Graph.new()
var _ids: Dictionary = {}
var _nodes: Dictionary = {}

## Rebuild once when the network changes, not once per candidate destination.
func build(roads: Array[RoadData], allowed_subtype: String = "") -> void:
	_graph.clear()
	_graph.costs.clear()
	_ids.clear()
	_nodes.clear()
	for road: RoadData in roads:
		if not allowed_subtype.is_empty() and road.infr_type_key != allowed_subtype:
			continue
		if road.curve == null:
			road.build_curve()
		_add_road(road)
	for node: RoadNode in _nodes.values():
		_connect_crossing(node, roads)

## Curved segment lengths supply costs; straight-line distance remains an admissible heuristic.
func _add_road(road: RoadData) -> void:
	var previous: int = -1
	for index: int in range(road.nodes.size()):
		var node: RoadNode = road.nodes[index]
		# Normal roads contribute two endpoints. Retain explicit legacy junctions
		# defensively, without turning ordinary curve-shape nodes into graph nodes.
		if index != 0 and index != road.nodes.size() - 1 and node.cross == null:
			continue
		var id: int = _ids.size()
		_ids[Vector2i(road.num, index)] = id
		_nodes[id] = node
		_graph.add_point(id, node.position)
		if previous >= 0:
			_connect(previous, id, _distance(_nodes[previous], node))
		previous = id

## Crossings require both explicit connectivity and matching XYZ anchors.
## A road passing visually over another road never creates an edge by itself.
func _connect_crossing(node: RoadNode, roads: Array[RoadData]) -> void:
	if node.cross == null:
		return
	for road: RoadData in roads:
		if road.num not in node.cross.connecting_roads:
			continue
		for other: RoadNode in road.nodes:
			var key := Vector2i(road.num, other.index)
			if _ids.has(key) and node.position.distance_to(other.position) <= JOIN_TOLERANCE:
				_connect(_id_for(node), _ids[key], node.position.distance_to(other.position))

func _connect(from_id: int, to_id: int, distance: float, both: bool = true) -> void:
	if from_id == to_id or _graph.are_points_connected(from_id, to_id, false):
		return
	_graph.costs[Vector2i(from_id, to_id)] = distance
	if both:
		_graph.costs[Vector2i(to_id, from_id)] = distance
	_graph.connect_points(from_id, to_id, both)

func _id_for(node: RoadNode) -> int:
	return _ids.get(Vector2i(node.parent_track.num, node.index), -1) if node != null else -1

## Attach at most two temporary anchors. The permanent graph stays small.
func find_path(from: RoadNode, to: RoadNode) -> Array[RoadNode]:
	var result: Array[RoadNode] = []
	if from == null or to == null:
		return result
	var temporary: Array[int] = []
	var start: int = _attach(from, false, temporary)
	var finish: int = start if from == to else _attach(to, true, temporary)
	if start >= 0 and finish >= 0:
		if from.parent_track == to.parent_track and _allows_arrival(from, to):
			_connect(start, finish, _distance(from, to), false)
		for id: int in _graph.get_id_path(start, finish):
			result.append(_nodes[id])
	_release_temporary(temporary)
	return result

## Side-specific destinations accept only an incoming edge from the proper direction.
func _attach(node: RoadNode, destination: bool, temporary: Array[int]) -> int:
	var existing: int = _id_for(node)
	if existing >= 0:
		return existing
	if not _ids.has(Vector2i(node.parent_track.num, 0)):
		return -1
	var id: int = _graph.get_available_point_id()
	_graph.add_point(id, node.position)
	_nodes[id] = node
	temporary.append(id)
	for other_id: int in _ids.values():
		var other: RoadNode = _nodes[other_id]
		if other.parent_track != node.parent_track:
			continue
		if not destination:
			_connect(id, other_id, _distance(node, other), false)
		elif _allows_arrival(other, node):
			_connect(other_id, id, _distance(other, node), false)
	return id

func _allows_arrival(from: RoadNode, to: RoadNode) -> bool:
	if not to is RoadRouteAnchor or to.arrival_direction == 0:
		return true
	return (RoadRouteAnchor.offset_of(to) - RoadRouteAnchor.offset_of(from)) * to.arrival_direction >= -0.001

func _release_temporary(ids: Array[int]) -> void:
	for id: int in ids:
		_graph.remove_point(id)
		_nodes.erase(id)
	for key: Vector2i in _graph.costs.keys():
		if key.x in ids or key.y in ids:
			_graph.costs.erase(key)

func _distance(from: RoadNode, to: RoadNode) -> float:
	if from.parent_track == to.parent_track:
		return absf(RoadRouteAnchor.offset_of(to) - RoadRouteAnchor.offset_of(from))
	return from.position.distance_to(to.position)

func path_length(path: Array[RoadNode]) -> float:
	var length: float = 0.0
	for index: int in range(1, path.size()):
		length += _distance(path[index - 1], path[index])
	return length

func graph_node_count() -> int:
	return _graph.get_point_count()
