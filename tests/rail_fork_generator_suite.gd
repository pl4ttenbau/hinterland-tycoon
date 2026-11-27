extends RefCounted
## RailForkGenerator on hand-made track records. Each fixture sits far from the others, so only the ends
## meant to meet can meet.

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run(_tree: SceneTree) -> int:
	for test: Callable in [test_switch, test_continuation_and_open_ends, test_undrivable_joins, test_apply]:
		check(test.call() == true, "%s completed without runtime errors" % test.get_method())
	print("Rail fork generator tests: %d failures" % failures)
	return 1 if failures > 0 else 0

static func track(num: int, points: Array, fork: Array = []) -> Dictionary:
	var out: Array = []
	for point: Array in points:
		out.append({"pos": point})
	if not fork.is_empty():
		out[-1]["fork"] = {"connectiveTracks": fork}
	return {"num": num, "name": "Fixture %d" % num, "type": "750_MM", "points": out}

func test_switch() -> bool:
	## Track 1 runs along +x into a switch at (100,0,0). Track 2 continues straight on, track 3 diverges by
	## about 15° (a typical switch angle). Both branches start at the switch point.
	var forks: Dictionary = RailForkGenerator.generate([
		track(1, [[80, 0, 0], [90, 0, 0], [100, 0, 0]]),
		track(2, [[100, 0, 0], [110, 0, 0], [120, 0, 0]]),
		track(3, [[100, 0, 0], [109.66, 0, 2.59], [119, 0, 6]]),
	])
	check(forks["1:2"] == [2, 3], "The main track's end lists both branches")
	check(forks["2:0"] == [1] and forks["3:0"] == [1], "Each branch lists only the main track: no V through the switch")
	check(forks["1:0"] == [] and forks["2:2"] == [] and forks["3:2"] == [], "Unconnected ends get no fork")
	return true

func test_continuation_and_open_ends() -> bool:
	## Track 4 hands over to track 5 with a gentle 10° bend: a plain joint, connected both ways.
	var forks: Dictionary = RailForkGenerator.generate([
		track(4, [[200, 0, 0], [210, 0, 0], [220, 0, 0]]),
		track(5, [[220, 0, 0], [229.85, 0, 1.74], [239.7, 0, 3.47]]),
	])
	check(forks["4:2"] == [5] and forks["5:0"] == [4], "A joint between two tracks is connected in both directions")
	check(forks["4:0"] == [] and forks["5:2"] == [], "Open ends (buffer stops) get no fork")
	return true

func test_undrivable_joins() -> bool:
	var forks: Dictionary = RailForkGenerator.generate([
		## A right-angle corner: no train curves through that, even though the ends touch.
		track(6, [[300, 0, 0], [310, 0, 0], [320, 0, 0]]),
		track(7, [[320, 0, 0], [320, 0, 10], [320, 0, 20]]),
		## Ends 5 cm apart are not snapped together, so they do not meet (tolerance 2 cm, like roads).
		track(8, [[400, 0, 0], [410, 0, 0], [420, 0, 0]]),
		track(9, [[420.05, 0, 0], [430, 0, 0], [440, 0, 0]]),
	])
	check(forks["6:2"] == [] and forks["7:0"] == [], "A 90° corner is not connected")
	check(forks["8:2"] == [] and forks["9:0"] == [], "Ends a few centimetres apart do not meet")
	return true

func test_apply() -> bool:
	## The hand data forgot branch 3 at the switch, lets track 2 list itself (marked static, which must
	## survive), and gives the open end of track 3 a fork to nowhere.
	var records: Array = [
		track(1, [[80, 0, 0], [90, 0, 0], [100, 0, 0]], [2.0]),
		track(2, [[100, 0, 0], [110, 0, 0], [120, 0, 0]]),
		track(3, [[100, 0, 0], [109.66, 0, 2.59], [119, 0, 6]], [7.0]),
	]
	records[1].points[0]["fork"] = {"connectiveTracks": [2.0], "static": true}
	records[2].points[0]["fork"] = {"connectiveTracks": [1.0]}
	var before: Array = records.duplicate(true)
	var result: Dictionary = RailForkGenerator.apply(records)
	## Agreeing: track 3 start and two open ends. Differing: track 1 end, track 2 start, track 3 end.
	check(result.same == 3 and result.differ == 3, "Three of six track ends differ from the geometry")
	check(result.report[0] == "Track 1 end: has [2], geometry says [2, 3]", "The missing branch is reported")
	check(result.report[1] == "Track 2 start: has [2], geometry says [1]", "A track listing itself is reported")
	check(result.report[2] == "Track 3 end: has [7], geometry says no fork", "A fork at an open end is reported")
	check(result.report[-1] == "Summary: 3 track ends agree, 3 differ.", "The report ends with a summary")
	check(records == before, "The input records are never changed")
	var out: Array = result.records
	check(out[0].points[2].fork.connectiveTracks == [2, 3], "The missing branch is added")
	check(out[1].points[0].fork == {"connectiveTracks": [1], "static": true}, "Other fork keys survive the rewrite")
	check(out[2].points[0] == before[2].points[0], "An agreeing end is left exactly as it was")
	check(not out[2].points[2].has("fork") and not out[0].points[0].has("fork"), "Open ends have no fork")
	return true
