extends Node

## Directed rail graph, junction topology and ID-based junction lookups, without loading a world.
var failures: int = 0
var rails: RailsLoader
var forks: RailJunctionLoader

var INC: Enums.PathDirection = Enums.PathDirection.TRACK_NODES_INCREASE
var DEC: Enums.PathDirection = Enums.PathDirection.TRACK_NODES_DECREASE

func _ready() -> void:
	self._run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		self.failures += 1
		push_error(message)

func make_track(num: int, points: Array[Vector3], gauge: String = "750_MM") -> RailTrackData:
	var track := RailTrackData.new()
	track.num = num
	track.infr_type_key = gauge
	for point_i: int in range(points.size()):
		track.add_node(RailNodeData.of(point_i, points[point_i], track), false)
	track.build_curve()
	self.rails.track_storage.add(track)
	return track

## Join track endpoints at one position. The first listed track is the static root.
func make_junction(legs: Array[RailNodeData]) -> RailJunctionData:
	for node: RailNodeData in legs:
		var leg := RailJunctionArm.new()
		leg.railNode = node
		leg.static_track = legs.size() > 2 and node == legs[0]
		node.fork = leg
		self.forks.add_new_or_connection(leg)
	var junction: RailJunctionData = legs[0].fork.junction
	junction.setting.init_current_setting()
	return junction

func id(track: RailTrackData, direction: Enums.PathDirection) -> int:
	return RailNetworkGraph.vertex_id(track.num, direction)

func _run() -> void:
	self.rails = RailsLoader.new()
	Managers.rails = self.rails
	self.forks = RailJunctionLoader.new()
	Managers.forks = self.forks
	## Two routes from the approach to the exit; the one via the straight track is shorter.
	var approach := self.make_track(0, [Vector3.ZERO, Vector3(0, 0, -20)])
	var straight := self.make_track(1, [Vector3(0, 0, -20), Vector3(0, 0, -60)])
	var branch := self.make_track(2, [Vector3(0, 0, -20), Vector3(60, 0, -40)])
	var link_a := self.make_track(3, [Vector3(0, 0, -60), Vector3(40, 0, -80)])
	## Entered at its last node, so it is travelled against node order.
	var link_b := self.make_track(4, [Vector3(40, 0, -80), Vector3(60, 0, -40)])
	var exit := self.make_track(5, [Vector3(40, 0, -80), Vector3(40, 0, -200)])
	var metre_gauge := self.make_track(6, [Vector3(40, 0, -200), Vector3(40, 0, -300)], InfrType.GAUGE_1000_MM)
	var entry_switch := self.make_junction([approach.nodes[1], straight.nodes[0], branch.nodes[0]])
	self.make_junction([straight.nodes[1], link_a.nodes[0]])
	self.make_junction([branch.nodes[1], link_b.nodes[1]])
	var exit_switch := self.make_junction([exit.nodes[0], link_a.nodes[1], link_b.nodes[0]])
	self.make_junction([exit.nodes[1], metre_gauge.nodes[0]])

	self.check(straight.nodes[0].fork.junction == entry_switch and branch.nodes[0].fork.junction == entry_switch,
		"Every leg references its junction")
	self.check(entry_switch.get_root_track_num() == approach.num, "The static track is the junction root")
	self.check(entry_switch.get_exit_track_nums(approach.num) == [straight.num, branch.num], "The root leads to every branch")
	self.check(entry_switch.get_exit_track_nums(branch.num) == [approach.num], "A branch leads only back to the root")

	var graph: RailNetworkGraph = self.rails.get_network_graph()
	self.check(graph.vertex_count() == 14, "Each track has one vertex per direction")
	self.check(graph.get_successors(id(approach, INC)) == [id(straight, INC), id(branch, INC)], "Leaving the root offers both branches")
	self.check(graph.get_successors(id(straight, DEC)) == [id(approach, DEC)], "Returning on a branch leads to the root")
	self.check(graph.get_successors(id(link_a, INC)) == [id(exit, INC)], "Branch to branch is not a connection")
	self.check(graph.get_successors(id(branch, INC)) == [id(link_b, DEC)], "Entering a track at its last node travels against node order")
	self.check(graph.get_successors(id(exit, INC)).is_empty(), "Incompatible gauges do not connect")
	self.check(graph.get_successors(id(exit, DEC)).size() == 2, "Facing the switch from its root offers both branches")

	var path: Array[int] = graph.find_path(id(approach, INC), id(exit, INC))
	self.check(path == [id(approach, INC), id(straight, INC), id(link_a, INC), id(exit, INC)], "The shortest route uses the straight track")
	var expected_length: float = 0.0
	for track: RailTrackData in [approach, straight, link_a, exit]:
		expected_length += track.curve.get_baked_length()
	self.check(absf(graph.path_length(path) - expected_length) < 0.01, "Route length is the sum of curve lengths")
	self.check(graph.find_path(id(link_a, INC), id(link_b, INC)).is_empty(), "Reaching a sibling branch needs a reversal, so no path")
	self.check(graph.find_path(id(exit, DEC), id(approach, DEC)).size() == 4, "Routes are found in the opposite direction too")

	## Switch settings do not change the graph; route setting uses set_connected_track.
	self.check(entry_switch.set_connected_track(branch.num) and entry_switch.setting.current.connected == branch.num,
		"A branch can be selected directly")
	self.check(not entry_switch.set_connected_track(approach.num), "The root cannot be selected as a branch")
	self.check(self.rails.get_network_graph() == graph, "Switching does not rebuild the graph")
	var next: VehiclePathSegment = VehiclePathSegmentBuilder.find_next_segment(VehiclePathSegment.of_rail(approach.num, INC))
	self.check(next != null and next.track_num == branch.num and next.movement_dir == INC, "Trains follow the selected branch")
	var reverse_next: VehiclePathSegment = VehiclePathSegmentBuilder.find_next_segment(VehiclePathSegment.of_rail(link_b.num, INC))
	self.check(reverse_next != null and reverse_next.track_num == branch.num and reverse_next.movement_dir == DEC,
		"Direction onto the next track comes from the junction leg")

	var spur := self.make_track(7, [Vector3(100, 0, 0), Vector3(100, 0, -10)])
	var rebuilt: RailNetworkGraph = self.rails.get_network_graph()
	self.check(rebuilt != graph and rebuilt.vertex_count() == 16, "Adding a track rebuilds the graph on next use")

	## Break fixture data cycles normally retained for the lifetime of a loaded map.
	for track: RailTrackData in [approach, straight, branch, link_a, link_b, exit, metre_gauge, spur]:
		for rail_node: RailNodeData in track.nodes:
			if rail_node.fork != null:
				if rail_node.fork.junction != null:
					rail_node.fork.junction.setting.parent = null
				rail_node.fork.junction = null
				rail_node.fork.railNode = null
				rail_node.fork = null
	self.rails.free()
	self.forks.free()
	print("Rail network graph tests: ", self.failures, " failures")
	self.get_tree().quit(0 if self.failures == 0 else 1)
