## Direction-aware road graph.
##
## Only road ends and junction nodes take part in routing; curve-shape nodes stay inside their
## road's curve. Each of those graph nodes gets four search states: "arrived travelling towards
## increasing offsets", "arrived travelling towards decreasing offsets", and the same two for
## leaving. Splitting arrival from departure is what lets the search tell a turn from a reversal:
## - arrive → leave in the same direction: drive straight on (free),
## - arrive at one node → leave from a coincident partner on another road: turn at a junction
##   (free, any direction on the new road),
## - arrive → leave in the opposite direction on the same road: a U-turn. That costs extra and is
##   only offered at road ends, which is where RoadUTurnPlanner can perform it. Dead ends are the
##   normal place; a junction mouth is a last resort with a high cost.
## Without this, every junction looked like a free place to reverse, and one-sided stops sent
## vehicles into a junction only to turn round there.
##
## Start and destination are attached per query as temporary points, so the permanent graph
## stays small and a start can carry the vehicle's heading.
class_name RoadPathfinder extends RefCounted

## Two nodes at most this far apart (XYZ) count as the same junction point.
const JOIN_TOLERANCE: float = 0.1
## Planning cost of turning round at a dead end, in metres of driving. Enough that a vehicle
## prefers a short loop or a turn into a side road, small enough that it still uses the dead end
## when that is the only sensible way to reach a one-sided stop.
const DEAD_END_U_TURN_COST: float = 25.0
## Turning round in a junction blocks it and looks wrong, so it is only chosen when no dead end
## or loop gives the vehicle another way round.
const JUNCTION_U_TURN_COST: float = 1000.0

## Travel direction along a road's curve: towards increasing or decreasing offsets.
const INC: int = 0
const DEC: int = 1
## State kinds per graph node; a state id is arm_index * 4 + kind + direction.
const ARRIVE: int = 0
const LEAVE: int = 2

class Graph extends AStar3D:
	var costs: Dictionary = {}
	func _compute_cost(from_id: int, to_id: int) -> float:
		return costs[Vector2i(from_id, to_id)]

## A graph node: a road end or a junction node, i.e. a place where routing can change.
class Arm extends RefCounted:
	var node: RoadNode
	## Distance along the road's curve, cached because node_offset() projects onto the curve.
	var offset: float
	## Index of the junction this arm belongs to; every arm is in exactly one, alone or shared.
	var junction: int
	var is_end: bool

var _graph := Graph.new()
var _arms: Array[Arm] = []
## RoadNode → arm index, for queries that start or end on a graph node.
var _arm_index: Dictionary = {}
## Road number → its arms (Array of Arm) sorted by offset, for attaching mid-road anchors.
var _road_arms: Dictionary = {}
## Junction index → arm indices meeting there.
var _junctions: Dictionary = {}

#region Building
## Rebuild once when the network changes, not once per candidate destination.
func build(roads: Array[RoadData], allowed_subtype: String = "") -> void:
	_graph.clear()
	_graph.costs.clear()
	_arms.clear()
	_arm_index.clear()
	_road_arms.clear()
	_junctions.clear()
	var included: Dictionary = {}
	for road: RoadData in roads:
		if not allowed_subtype.is_empty() and road.infr_type_key != allowed_subtype:
			continue
		if road.curve == null:
			road.build_curve()
		included[road.num] = road
	var links: Array = _find_links(included)
	_create_arms(included, links)
	_join_junctions(links)
	_connect_roads()
	_connect_arms()

## Find the junction partners of every cross. A cross names roads, not nodes, so look for nodes
## at the same point on just those roads: a direct lookup by number instead of a scan over the
## whole network. The partner is accepted even if only one side lists the link, and even if it
## is an interior node without its own cross; both happen in saved maps.
## Returns [node, partner] pairs.
func _find_links(included: Dictionary) -> Array:
	var links: Array = []
	for road: RoadData in included.values():
		for node: RoadNode in road.nodes:
			if node.cross == null:
				continue
			for num: int in node.cross.connecting_roads:
				var other: RoadData = included.get(num)
				if other == null:
					continue
				for partner: RoadNode in other.nodes:
					# A road passing over another names it too; height keeps them apart.
					if partner != node and node.position.distance_to(partner.position) <= JOIN_TOLERANCE:
						links.append([node, partner])
	return links

## Road ends always route. Interior nodes route when they carry a cross (kept even without
## partners, for legacy data) or when another road links to them.
func _create_arms(included: Dictionary, links: Array) -> void:
	var linked: Dictionary = {}
	for link: Array in links:
		linked[link[0]] = true
		linked[link[1]] = true
	for road: RoadData in included.values():
		var arms: Array = []
		var last: int = road.nodes.size() - 1
		for node: RoadNode in road.nodes:
			var is_end: bool = node.index == 0 or node.index == last
			if not is_end and node.cross == null and not linked.has(node):
				continue
			var arm := Arm.new()
			arm.node = node
			arm.offset = node.offset()
			arm.is_end = is_end
			arm.junction = _arms.size()
			_arm_index[node] = _arms.size()
			_arms.append(arm)
			arms.append(arm)
			for kind: int in [ARRIVE + INC, ARRIVE + DEC, LEAVE + INC, LEAVE + DEC]:
				_graph.add_point(_state(_arms.size() - 1, kind), node.position)
		# Node order normally is offset order; sorting keeps odd curves safe.
		arms.sort_custom(func(a: Arm, b: Arm) -> bool: return a.offset < b.offset)
		_road_arms[road.num] = arms

## Group linked arms into junctions (union-find), so a three- or four-way junction is one place
## and turning from any arm to any other takes a single step.
func _join_junctions(links: Array) -> void:
	var parent: Array[int] = []
	for index: int in range(_arms.size()):
		parent.append(index)
	var root := func(index: int) -> int:
		while parent[index] != index:
			parent[index] = parent[parent[index]]
			index = parent[index]
		return index
	for link: Array in links:
		var a: int = root.call(_arm_index[link[0]])
		var b: int = root.call(_arm_index[link[1]])
		if a != b:
			parent[a] = b
	for index: int in range(_arms.size()):
		var junction: int = root.call(index)
		_arms[index].junction = junction
		if not _junctions.has(junction):
			_junctions[junction] = []
		_junctions[junction].append(index)

## Driving along a road between neighbouring arms, in both directions. Curved arc length is the
## cost; the straight-line heuristic stays admissible because an arc is never shorter.
func _connect_roads() -> void:
	for arms: Array in _road_arms.values():
		for index: int in range(arms.size() - 1):
			var from: int = _arm_index[arms[index].node]
			var to: int = _arm_index[arms[index + 1].node]
			var length: float = arms[index + 1].offset - arms[index].offset
			_connect(_state(from, LEAVE + INC), _state(to, ARRIVE + INC), length)
			_connect(_state(to, LEAVE + DEC), _state(from, ARRIVE + DEC), length)

## What a vehicle may do on arriving at an arm: carry on, turn onto another arm of the same
## junction, or turn round where RoadUTurnPlanner can do it (road ends only).
func _connect_arms() -> void:
	for index: int in range(_arms.size()):
		var arm: Arm = _arms[index]
		var partners: Array = _junctions[arm.junction]
		for direction: int in [INC, DEC]:
			_connect(_state(index, ARRIVE + direction), _state(index, LEAVE + direction), 0.0)
			if arm.is_end:
				var cost: float = DEAD_END_U_TURN_COST if partners.size() == 1 else JUNCTION_U_TURN_COST
				_connect(_state(index, ARRIVE + direction), _state(index, LEAVE + _opposite(direction)), cost)
			for partner: int in partners:
				if partner == index:
					continue
				var gap: float = arm.node.position.distance_to(_arms[partner].node.position)
				for onward: int in [INC, DEC]:
					_connect(_state(index, ARRIVE + direction), _state(partner, LEAVE + onward), gap)
#endregion

#region Queries
## Shortest drivable sequence of nodes from one node to another, both included; empty if
## unreachable. Junction hops list both coincident nodes; a U-turn shows as the path turning back
## at a road end. [param heading] is the start's travel direction along its road: +1 towards
## increasing offsets, -1 towards decreasing, 0 when either is fine (planning, validation).
func find_path(from: RoadNode, to: RoadNode, heading: int = 0) -> Array[RoadNode]:
	var result: Array[RoadNode] = []
	if from == null or to == null:
		return result
	if from == to:
		result.append(from)
		return result
	var temporary: Array[int] = []
	var start: int = _add_temporary(from.position, temporary)
	var finish: int = _add_temporary(to.position, temporary)
	_attach_start(start, from, heading)
	_attach_finish(finish, to)
	_attach_direct(start, finish, from, to, heading)
	for id: int in _graph.get_id_path(start, finish):
		var node: RoadNode = from if id == start else to if id == finish else _arms[_arm_of(id)].node
		# Arrive and leave states share a node; list each place once.
		if result.is_empty() or result.back() != node:
			result.append(node)
	_release_temporary(temporary)
	return result

## Start on a graph node: arrive there in the allowed direction(s), so carrying on, turning and
## turning round are all decided by the ordinary arm edges. Mid-road: drive to the next arm
## ahead and/or behind, as the heading allows.
func _attach_start(start: int, from: RoadNode, heading: int) -> void:
	var directions: Array[int] = _directions(heading)
	if _arm_index.has(from):
		for direction: int in directions:
			_connect(start, _state(_arm_index[from], ARRIVE + direction), 0.0)
		return
	var span: Array = _span(from)
	if span.is_empty():
		return
	var offset: float = from.offset()
	if INC in directions:
		_connect(start, _state(_arm_index[span[1].node], ARRIVE + INC), span[1].offset - offset)
	if DEC in directions:
		_connect(start, _state(_arm_index[span[0].node], ARRIVE + DEC), offset - span[0].offset)

## Finish on a graph node: arriving at any arm of its junction counts, it is the same place.
## Mid-road: leave the arm before it (or after it) towards the target, if the target accepts
## that arrival direction.
func _attach_finish(finish: int, to: RoadNode) -> void:
	if _arm_index.has(to):
		var arm: Arm = _arms[_arm_index[to]]
		for partner: int in _junctions[arm.junction]:
			var gap: float = _arms[partner].node.position.distance_to(to.position)
			for direction: int in [INC, DEC]:
				_connect(_state(partner, ARRIVE + direction), finish, gap)
		return
	var span: Array = _span(to)
	if span.is_empty():
		return
	var offset: float = to.offset()
	if _allows_arrival(to, INC):
		_connect(_state(_arm_index[span[0].node], LEAVE + INC), finish, offset - span[0].offset)
	if _allows_arrival(to, DEC):
		_connect(_state(_arm_index[span[1].node], LEAVE + DEC), finish, span[1].offset - offset)

## Start and target on the same road: drive straight there if heading and stop side allow it.
## Arms in between are passed straight on, so the direct edge costs the same as going through them.
func _attach_direct(start: int, finish: int, from: RoadNode, to: RoadNode, heading: int) -> void:
	if from.parent_line != to.parent_line or not _road_arms.has(from.parent_line.num):
		return
	var delta: float = to.offset() - from.offset()
	if absf(delta) < 0.001:
		_connect(start, finish, 0.0)
		return
	var direction: int = INC if delta > 0.0 else DEC
	if direction in _directions(heading) and _allows_arrival(to, direction):
		_connect(start, finish, absf(delta))

## The arms just before and after a mid-road node, [before, after]; empty if its road is not in
## the graph. Road ends are always arms, so both exist for any offset on the road.
func _span(node: RoadNode) -> Array:
	var arms: Array = _road_arms.get(node.parent_line.num, [])
	if arms.is_empty():
		return []
	var offset: float = node.offset()
	var before: Arm = arms[0]
	var after: Arm = arms[arms.size() - 1]
	for arm: Arm in arms:
		if arm.offset <= offset:
			before = arm
		if arm.offset >= offset:
			after = arm
			break
	return [before, after]

## One-sided stops and markers accept only one arrival direction along their road.
func _allows_arrival(to: RoadNode, direction: int) -> bool:
	if not to is RoadRouteAnchor or to.arrival_direction == 0:
		return true
	return (to.arrival_direction > 0) == (direction == INC)
#endregion

#region Graph plumbing
func _state(arm: int, kind: int) -> int:
	return arm * 4 + kind

## Inverse of _state(): which arm a permanent state belongs to.
@warning_ignore("integer_division")
func _arm_of(state: int) -> int:
	return state / 4

func _opposite(direction: int) -> int:
	return DEC if direction == INC else INC

func _directions(heading: int) -> Array[int]:
	if heading > 0:
		return [INC]
	if heading < 0:
		return [DEC]
	return [INC, DEC]

## Directed edge. A repeated edge keeps the cheaper cost.
func _connect(from_id: int, to_id: int, cost: float) -> void:
	var key := Vector2i(from_id, to_id)
	if _graph.costs.has(key):
		_graph.costs[key] = minf(_graph.costs[key], cost)
		return
	_graph.costs[key] = cost
	_graph.connect_points(from_id, to_id, false)

func _add_temporary(position: Vector3, temporary: Array[int]) -> int:
	var id: int = _graph.get_available_point_id()
	_graph.add_point(id, position)
	temporary.append(id)
	return id

## Removing a point drops its connections; their costs go with them.
func _release_temporary(ids: Array[int]) -> void:
	for id: int in ids:
		_graph.remove_point(id)
	for key: Vector2i in _graph.costs.keys():
		if key.x in ids or key.y in ids:
			_graph.costs.erase(key)
#endregion

#region Measuring
## Physical driving length of a found path; U-turn planning costs are not included.
func path_length(path: Array[RoadNode]) -> float:
	var length: float = 0.0
	for index: int in range(1, path.size()):
		length += _distance(path[index - 1], path[index])
	return length

func _distance(from: RoadNode, to: RoadNode) -> float:
	if from.parent_line == to.parent_line:
		return absf(to.offset() - from.offset())
	return from.position.distance_to(to.position)

## Number of arms (road ends and junction nodes). Search states and temporary query points are
## not counted, so this stays a measure of the network itself.
func graph_node_count() -> int:
	return _arms.size()
#endregion
