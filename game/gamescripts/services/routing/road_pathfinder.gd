## A data-only graph: every road node is addressable; only authored crossings join roads.
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
	for index: int in range(road.nodes.size()):
		var node: RoadNode = road.nodes[index]
		var id: int = _ids.size()
		_ids[Vector2i(road.num, index)] = id
		_nodes[id] = node
		_graph.add_point(id, node.position)
		if index > 0:
			var previous: RoadNode = road.nodes[index - 1]
			var distance: float = absf(road.curve.get_closest_offset(node.rel_position) - road.curve.get_closest_offset(previous.rel_position))
			_connect(id - 1, id, maxf(distance, node.position.distance_to(previous.position)))

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

func _connect(from_id: int, to_id: int, distance: float) -> void:
	if from_id == to_id or _graph.are_points_connected(from_id, to_id):
		return
	_graph.costs[Vector2i(from_id, to_id)] = distance
	_graph.costs[Vector2i(to_id, from_id)] = distance
	_graph.connect_points(from_id, to_id, true)

func _id_for(node: RoadNode) -> int:
	return _ids.get(Vector2i(node.parent_track.num, node.index), -1) if node != null else -1

func find_path(from: RoadNode, to: RoadNode) -> Array[RoadNode]:
	var result: Array[RoadNode] = []
	var start: int = _id_for(from)
	var finish: int = _id_for(to)
	if start < 0 or finish < 0:
		return result
	for id: int in _graph.get_id_path(start, finish):
		result.append(_nodes[id])
	return result

func path_length(path: Array[RoadNode]) -> float:
	var length: float = 0.0
	for index: int in range(1, path.size()):
		length += float(_graph.costs[Vector2i(_id_for(path[index - 1]), _id_for(path[index]))])
	return length
