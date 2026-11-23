extends RefCounted
## TrackAnchor on straight test lines, where distances along the curve equal x and are easy to check.

const TOLERANCE: float = 0.05

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run(_tree: SceneTree) -> int:
	for test: Callable in [test_nearest_node, test_resolving, test_normalized, test_far_edits, test_from_dict,
			test_write_to, test_same_place, test_curved_nodes]:
		check(test.call() == true, "%s completed without runtime errors" % test.get_method())
	print("Track anchor tests: %d failures" % failures)
	return 1 if failures > 0 else 0

## A straight line along +x through the given x positions, so curve distance == x.
static func line(xs: Array) -> RailTrackData:
	var track := RailTrackData.new()
	track.num = 1
	for index: int in range(xs.size()):
		track.add_node(RailNodeData.of(index, Vector3(xs[index], 0, 0), track), false)
	track.build_curve()
	return track

static func near(a: float, b: float) -> bool:
	return absf(a - b) <= TOLERANCE

func test_nearest_node() -> bool:
	var track: RailTrackData = line([0, 10, 30, 40])
	var a: TrackAnchor = TrackAnchor.at_curve_offset(track, 12.0)
	check(a.node_index == 1 and near(a.offset, 2.0), "12 m lies 2 m past node 1 (at 10 m)")
	var b: TrackAnchor = TrackAnchor.at_curve_offset(track, 22.0)
	check(b.node_index == 2 and near(b.offset, -8.0), "22 m is nearer node 2 (at 30 m): a negative offset")
	var tie: TrackAnchor = TrackAnchor.at_curve_offset(track, 20.0)
	check(tie.node_index == 1 and near(tie.offset, 10.0), "Exactly halfway, the earlier node wins")
	var ends: Array = [TrackAnchor.at_curve_offset(track, 0.0), TrackAnchor.at_curve_offset(track, 40.0)]
	check(ends[0].node_index == 0 and ends[1].node_index == 3 and near(ends[0].offset, 0.0) and near(ends[1].offset, 0.0),
		"The line ends anchor to the end nodes without an offset")
	var beyond: TrackAnchor = TrackAnchor.at_curve_offset(track, 55.0)
	check(beyond.node_index == 3 and near(beyond.offset, 0.0), "Distances past the end are clamped to the line")
	return true

func test_resolving() -> bool:
	var track: RailTrackData = line([0, 10, 30, 40])
	var anchor := TrackAnchor.new(2, -8.0)
	check(anchor.is_valid_on(track) and near(anchor.curve_offset(track), 22.0), "Node 2 minus 8 m is 22 m along the line")
	check(anchor.position_on(track).distance_to(Vector3(22, 0, 0)) <= TOLERANCE, "The world position matches")
	check(near(TrackAnchor.new(3, 5.0).curve_offset(track), 40.0), "An offset past the end is clamped to the line")
	var missing := TrackAnchor.new(9, 0.0)
	check(not missing.is_valid_on(track) and missing.curve_offset(track) == -1.0, "A missing node makes the anchor invalid")
	return true

func test_normalized() -> bool:
	var track: RailTrackData = line([0, 10, 30, 40])
	## Valid but not normalized: 25 m from node 0 lies nearer node 2.
	var far := TrackAnchor.new(0, 25.0).normalized(track)
	check(far.node_index == 2 and near(far.offset, -5.0), "Normalizing moves the anchor to the nearest node")
	var same := TrackAnchor.new(1, 2.0).normalized(track)
	check(same.node_index == 1 and near(same.offset, 2.0), "A normalized anchor stays as it is")
	return true

func test_far_edits() -> bool:
	## The reason for node anchors: lengthening the line after the stop does not move the stop, and
	## neither does a change before its node (the first segment gets longer here).
	var anchor := TrackAnchor.new(2, 3.0)
	var before: Vector3 = anchor.position_on(line([0, 10, 30, 40]))
	var longer_end: Vector3 = anchor.position_on(line([0, 10, 30, 70]))
	check(before.distance_to(Vector3(33, 0, 0)) <= TOLERANCE and longer_end.distance_to(before) <= TOLERANCE,
		"Edits after the node leave the place where it was")
	var shifted_start: Vector3 = anchor.position_on(line([-20, 10, 30, 40]))
	check(shifted_start.distance_to(before) <= TOLERANCE, "Edits before the node leave the place where it was too")
	return true

func test_from_dict() -> bool:
	var plain: TrackAnchor = TrackAnchor.from_dict({"nodeIndex": 4})
	check(plain != null and plain.node_index == 4 and plain.offset == 0.0, "Records with only nodeIndex read as places on the node")
	## JSON parsing returns floats for every number.
	var parsed: TrackAnchor = TrackAnchor.from_dict({"nodeIndex": 2.0, "nodeOffset": -3.5})
	check(parsed != null and parsed.node_index == 2 and parsed.offset == -3.5, "nodeIndex and nodeOffset are read from JSON numbers")
	for bad: Dictionary in [{}, {"nodeIndex": -1}, {"nodeIndex": 1.5}, {"nodeIndex": "1"}, {"nodeIndex": INF},
			{"nodeIndex": 1, "nodeOffset": "2"}, {"nodeIndex": 1, "nodeOffset": NAN}]:
		check(TrackAnchor.from_dict(bad) == null, "Invalid anchor record is rejected: %s" % str(bad))
	return true

func test_write_to() -> bool:
	var record: Dictionary = {"num": 5, "nodeOffset": 9.0}
	TrackAnchor.new(3, 0.001).write_to(record)
	check(record == {"num": 5, "nodeIndex": 3}, "An offset that rounds to zero is left out, and a stale one removed")
	TrackAnchor.new(1, 12.346).write_to(record)
	check(record.nodeIndex == 1 and record.nodeOffset == 12.35, "Offsets are written in centimetres")
	var reread: TrackAnchor = TrackAnchor.from_dict(record)
	check(reread.same_place(TrackAnchor.new(1, 12.346)), "A written anchor reads back as the same place")
	return true

func test_same_place() -> bool:
	## Same place means the same written anchor: node and offset in whole centimetres.
	check(TrackAnchor.new(1, 2.0).same_place(TrackAnchor.new(1, 2.001)), "Offsets that write the same centimetre are the same place")
	check(not TrackAnchor.new(1, 2.0).same_place(TrackAnchor.new(1, 2.02)), "Two centimetres apart is another place")
	check(not TrackAnchor.new(1, 0.0).same_place(TrackAnchor.new(2, 0.0)), "Another node is another place")
	check(not TrackAnchor.new(1, 0.0).same_place(null), "No anchor is never the same place")
	## The editor's re-anchoring report prints anchors like this.
	check(str(TrackAnchor.new(2, -8.0)) == "node 2 -8.00 m" and str(TrackAnchor.new(1, 2.0)) == "node 1 +2.00 m",
		"Anchors print as node and signed offset")
	return true

## On a bent line, distances along the curve are no longer x: the anchor must still find its nodes exactly.
func test_curved_nodes() -> bool:
	var track := RailTrackData.new()
	track.num = 2
	var positions: Array[Vector3] = [Vector3(0, 0, 0), Vector3(10, 0, 5), Vector3(20, 0, 0), Vector3(30, 0, 8)]
	for index: int in range(positions.size()):
		track.add_node(RailNodeData.of(index, positions[index], track), false)
	track.build_curve()
	var previous: float = -1.0
	for index: int in range(positions.size()):
		var on_node := TrackAnchor.new(index)
		check(on_node.position_on(track) == positions[index], "A stop on node %d stands exactly on the node" % index)
		var distance: float = on_node.curve_offset(track)
		check(distance > previous, "Node %d lies further along the curve than the one before" % index)
		previous = distance
		var found: TrackAnchor = TrackAnchor.at_curve_offset(track, distance)
		check(found.node_index == index and near(found.offset, 0.0), "Node %d's own curve distance anchors back to it" % index)
	## Between nodes: a place 3 m past node 1 resolves 3 m further along the curve and anchors back the same.
	var between := TrackAnchor.new(1, 3.0)
	var back: TrackAnchor = TrackAnchor.at_curve_offset(track, between.curve_offset(track))
	check(back.node_index == 1 and near(back.offset, 3.0), "A place between nodes survives the round trip through its curve distance")
	check(between.position_on(track).distance_to(positions[1]) > 2.5, "The place is really off the node")
	return true
