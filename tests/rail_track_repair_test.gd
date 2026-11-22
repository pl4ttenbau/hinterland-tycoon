extends SceneTree
## RailTrackRepair on hand-made track records: one fixture per rule, far apart so they never interact.

var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	for test: Callable in [test_kinked_join, test_switch_untouched, test_locked_neighbour, test_sharp_kink_left,
			test_duplicates, test_input_untouched]:
		check(test.call() == true, "%s completed without runtime errors" % test.get_method())
	print("Rail track repair tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)

static func track(num: int, points: Array) -> Dictionary:
	var out: Array = []
	for point: Variant in points:
		out.append({"pos": point} if point is Array else point)
	return {"num": num, "name": "Fixture %d" % num, "type": "750_MM", "points": out}

static func pos(record: Dictionary, index: int) -> Vector3:
	var p: Array = record.points[index].pos
	return Vector3(p[0], p[1], p[2])

static func find(records: Array, num: int) -> Dictionary:
	for record: Dictionary in records:
		if int(record.num) == num:
			return record
	return {}

## Plan-view angle between arriving along `a` (towards its end) and leaving along `b` (from its start).
static func kink_degrees(a: Dictionary, b: Dictionary) -> float:
	var arriving: Vector3 = pos(a, a.points.size() - 1) - pos(a, a.points.size() - 2)
	var leaving: Vector3 = pos(b, 1) - pos(b, 0)
	arriving.y = 0.0
	leaving.y = 0.0
	return rad_to_deg(arriving.angle_to(leaving))

func test_kinked_join() -> bool:
	## Track 1 runs along +x into (20,0,0); track 2 leaves at 45°. Both neighbours are free.
	var records: Array = [
		track(1, [[0, 0, 0], [10, 0, 0], [20, 0, 0]]),
		track(2, [[20, 0, 0], {"pos": [27.07, 1.5, 7.07], "handleIn": [-2, 0, -2]}, [40, 0, 20]]),
	]
	var result: Dictionary = RailTrackRepair.repair(records)
	var a: Dictionary = find(result.records, 1)
	var b: Dictionary = find(result.records, 2)
	check(result.aligned == 1 and result.skipped == 0, "A 45° continuation is aligned")
	check(kink_degrees(a, b) < 0.1, "The line runs straight through the join afterwards")
	check(pos(a, 2) == Vector3(20, 0, 0) and pos(b, 0) == Vector3(20, 0, 0), "The join point itself never moves")
	check(is_equal_approx(pos(a, 1).distance_to(pos(a, 2)), 10.0), "Track 1's neighbour keeps its distance from the join")
	check(is_equal_approx(Vector2(pos(b, 1).x - 20, pos(b, 1).z).length(), Vector2(7.07, 7.07).length()),
		"Track 2's neighbour keeps its horizontal distance from the join")
	check(is_equal_approx(pos(b, 1).y, 1.5), "Moved points keep their height")
	## Meeting in the middle: each side turns by half of 45°.
	check(absf(rad_to_deg(Vector3(1, 0, 0).angle_to(pos(a, 2) - pos(a, 1))) - 22.5) < 0.1, "Both sides share the correction")
	check(not b.points[1].has("handleIn"), "Stale handles of a moved point are dropped for auto smoothing")
	check(pos(a, 0) == Vector3.ZERO and pos(b, 2) == Vector3(40, 0, 20), "Far ends stay where they are")
	return true

func test_switch_untouched() -> bool:
	## Three track ends at one point form a switch: intentional geometry, never aligned.
	var records: Array = [
		track(3, [[90, 0, 0], [95, 0, 0], [100, 0, 0]]),
		track(4, [[100, 0, 0], [105, 0, 0], [110, 0, 0]]),
		track(5, [[100, 0, 0], [105, 0, 2], [110, 0, 6]]),
	]
	var result: Dictionary = RailTrackRepair.repair(records)
	check(result.aligned == 0 and result.records == records, "A three-way switch is left exactly as drawn")
	return true

func test_locked_neighbour() -> bool:
	## Track 6's neighbour carries metadata (a bridge), so track 7 takes the whole correction.
	var records: Array = [
		track(6, [[200, 0, 0], {"pos": [210, 0, 0], "bridge": true}, [220, 0, 0]]),
		track(7, [[220, 0, 0], [230, 0, 5], [240, 0, 20]]),
	]
	var result: Dictionary = RailTrackRepair.repair(records)
	var a: Dictionary = find(result.records, 6)
	var b: Dictionary = find(result.records, 7)
	check(result.aligned == 1, "A join with one locked side is still aligned")
	check(pos(a, 1) == Vector3(210, 0, 0) and a.points[1].bridge == true, "A point with metadata never moves")
	check(absf(pos(b, 1).z) < 0.001 and is_equal_approx(pos(b, 1).x, 220.0 + Vector2(10, 5).length()),
		"The free side turns fully onto the locked side's direction")
	return true

func test_sharp_kink_left() -> bool:
	## A right angle is no drawing slip: reported, not touched.
	var records: Array = [
		track(8, [[300, 0, 0], [310, 0, 0], [320, 0, 0]]),
		track(9, [[320, 0, 0], [320, 0, 10], [320, 0, 20]]),
	]
	var result: Dictionary = RailTrackRepair.repair(records)
	check(result.aligned == 0 and result.skipped == 1 and result.records == records, "A 90° corner is left for manual review")
	var reported: bool = false
	for line: String in result.report:
		reported = reported or (line.contains("track 8") and line.contains("manual review"))
	check(reported, "The skipped corner is named in the report")
	return true

func test_duplicates() -> bool:
	var records: Array = [
		## Plain duplicate (1 cm apart): merged.
		track(10, [[400, 0, 0], [410, 0, 0], [410, 0, 0.01], [420, 0, 0]]),
		## The second copy carries metadata: that copy survives.
		track(11, [[500, 0, 0], [510, 0, 0], {"pos": [510, 0, 0], "bridge": true}, [520, 0, 0]]),
		## Both copies carry metadata: left alone and reported.
		track(12, [[600, 0, 0], {"pos": [610, 0, 0], "bridge": true}, {"pos": [610, 0, 0], "end": true}, [620, 0, 0]]),
	]
	var result: Dictionary = RailTrackRepair.repair(records)
	check(result.duplicates == 2, "Two duplicates are merged")
	check(find(result.records, 10).points.size() == 3, "A plain duplicate point is removed")
	var kept: Dictionary = find(result.records, 11).points[1]
	check(find(result.records, 11).points.size() == 3 and kept.get("bridge") == true, "The copy with metadata is the one kept")
	check(find(result.records, 12).points.size() == 4, "Duplicates that both carry metadata are left alone")
	return true

func test_input_untouched() -> bool:
	var records: Array = [
		track(13, [[700, 0, 0], [710, 0, 0], [720, 0, 0]]),
		track(14, [[720, 0, 0], [727, 0, 7], [740, 0, 20]]),
	]
	var before: Array = records.duplicate(true)
	RailTrackRepair.repair(records)
	check(records == before, "The caller's records are never modified")
	return true
