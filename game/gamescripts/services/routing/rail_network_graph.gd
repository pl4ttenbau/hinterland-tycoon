## Directed rail network: one vertex per track and direction of travel.
##
## A train travelling a track can only leave through the junction ahead of it, and only onto
## the tracks that junction can connect to the one it arrived on: root to any branch, a branch
## back to the root, never branch to branch. Joints between tracks of incompatible gauges are
## left out. The graph describes topology only; current switch settings do not change it.
## Reversing is not an edge: a route that reverses is two searches.
class_name RailNetworkGraph extends RefCounted

class Graph extends AStar3D:
	## Vertex id -> length of its track; entering a vertex costs travelling its whole track.
	var lengths: Dictionary = {}
	func _compute_cost(_from_id: int, to_id: int) -> float:
		return lengths[to_id]

var _graph := Graph.new()
var _tracks: Dictionary = {}

#region Vertex ids
## Track numbers are non-negative, so ids are too, as AStar3D requires.
static func vertex_id(track_num: int, direction: Enums.PathDirection) -> int:
	return track_num * 2 + (1 if direction == Enums.PathDirection.TRACK_NODES_DECREASE else 0)

static func vertex_track_num(id: int) -> int:
	return id >> 1

static func vertex_direction(id: int) -> Enums.PathDirection:
	return Enums.PathDirection.TRACK_NODES_DECREASE if (id & 1) == 1 else Enums.PathDirection.TRACK_NODES_INCREASE
#endregion

## Rebuild once when the network changes; the graph keeps no reference to switch settings.
func build(tracks: Array[RailTrackData]) -> void:
	_graph.clear()
	_graph.lengths.clear()
	_tracks.clear()
	for track: RailTrackData in tracks:
		if track.num < 0 or track.nodes.size() < 2:
			continue
		if track.curve == null:
			track.build_curve()
		_tracks[track.num] = track
		var length: float = track.curve.get_baked_length()
		for direction: Enums.PathDirection in [Enums.PathDirection.TRACK_NODES_INCREASE, Enums.PathDirection.TRACK_NODES_DECREASE]:
			var id: int = vertex_id(track.num, direction)
			## The exit position keeps straight-line distance an admissible heuristic.
			_graph.add_point(id, _exit_node(track, direction).position)
			_graph.lengths[id] = length
	for track: RailTrackData in _tracks.values():
		for direction: Enums.PathDirection in [Enums.PathDirection.TRACK_NODES_INCREASE, Enums.PathDirection.TRACK_NODES_DECREASE]:
			var from_id: int = vertex_id(track.num, direction)
			for to_id: int in _transitions(track, direction):
				_graph.connect_points(from_id, to_id, false)

static func _exit_node(track: RailTrackData, direction: Enums.PathDirection) -> RailNodeData:
	return track.nodes[0] if direction == Enums.PathDirection.TRACK_NODES_DECREASE else track.get_end_node()

## Vertices a train can continue onto after travelling `track` in `direction`.
func _transitions(track: RailTrackData, direction: Enums.PathDirection) -> Array[int]:
	var result: Array[int] = []
	var exit: RailNodeData = _exit_node(track, direction)
	if exit.fork == null or exit.fork.junction == null:
		return result
	var junction: RailJunctionData = exit.fork.junction
	for next_num: int in junction.get_exit_track_nums(track.num):
		var next_track: RailTrackData = _tracks.get(next_num)
		var leg: RailJunctionArm = junction.get_node_fork(next_num)
		if next_track == null or leg == null:
			continue
		if not InfrType.rail_gauges_compatible(track.infr_type_key, next_track.infr_type_key):
			continue
		## Entering at the last node means travelling against node order.
		var next_direction: Enums.PathDirection = Enums.PathDirection.TRACK_NODES_DECREASE if leg.railNode.is_last() else Enums.PathDirection.TRACK_NODES_INCREASE
		result.append(vertex_id(next_num, next_direction))
	return result

#region Queries
func has_vertex(id: int) -> bool:
	return _graph.has_point(id)

func vertex_count() -> int:
	return _graph.get_point_count()

## Sorted, because AStar3D does not keep connection order.
func get_successors(id: int) -> Array[int]:
	var result: Array[int] = []
	if _graph.has_point(id):
		for next_id: int in _graph.get_point_connections(id):
			result.append(next_id)
		result.sort()
	return result

## Shortest sequence of directed tracks from one vertex to another, both included; empty if unreachable.
func find_path(from_id: int, to_id: int) -> Array[int]:
	var result: Array[int] = []
	if not _graph.has_point(from_id) or not _graph.has_point(to_id):
		return result
	for id: int in _graph.get_id_path(from_id, to_id):
		result.append(id)
	return result

## Total length of every track in the path, including the first and last.
func path_length(path: Array[int]) -> float:
	var length: float = 0.0
	for id: int in path:
		length += _graph.lengths.get(id, 0.0)
	return length
#endregion
