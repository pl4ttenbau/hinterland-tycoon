@tool
## Works out rail switches ("forks") from track geometry: the rail counterpart of the automatic road
## crossings that RoadEndpointConnection writes on every road save.
##
## Every switch in the maps sits at track ends (all 742 at the time of writing): a track is split where a
## switch is, and the pieces meet at one point. A track end's fork lists the tracks a train can continue
## into from there, in "fork": {"connectiveTracks": [...]}.
##
## Which tracks those are is a matter of direction, not just position. At a switch, the main track's end
## lists both branches, but each branch lists only the main track: from one branch into the other a train
## would have to run a V through the switch. So only tracks a train can reasonably curve into are listed:
## the line must continue through the point, turning by at most MAX_TURN_DEGREES. Checked against
## the hand-made forks of all four maps on 2026-11-22: 767 of 830 track ends agree, and the
## differences seen were mostly mistakes in the hand data (tracks listing themselves, numbers off by one, missing forks).
##
## Pure data in, data out, like RailTrackRepair: nothing here touches files or scenes. Used by the
## command line (tools/rail/tracks.sh forks) and by every rail save in the editor
## (InfrLineJsonStore._prepare_records_for_save), like road crossings.
class_name RailForkGenerator extends RefCounted

## Largest change of direction a train can take through a joint or switch. Two ends meeting at a sharper
## angle are not connected: no train runs through a V (two branches of one switch, turning back on itself)
## or round a corner it cannot reasonably curve through. Real switch branches diverge by well under 30°.
const MAX_TURN_DEGREES: float = 60.0

## The forks the geometry calls for, per track end: {"<num>:<point index>": [track nums, ascending]}.
## Every track end appears, with an empty list where nothing connects (an open end, e.g. a buffer stop).
## Ends meet when they are within RoadEndpointConnection.JOIN_DISTANCE (2 cm) after rounding to the
## centimetres JSON stores, the same rule as road crossings.
static func generate(records: Array) -> Dictionary:
	var ends: Array[EditorRoadEndpoint] = []
	var arriving: Array[Vector3] = []
	for record: Dictionary in records:
		var points: Array = record.points
		if points.size() < 2:
			continue
		for end: int in [0, 1]:
			var index: int = 0 if end == 0 else points.size() - 1
			var neighbour: int = 1 if end == 0 else points.size() - 2
			var position: Vector3 = _pos(points[index])
			## EditorRoadEndpoint only carries a number, an end and a position; its "road" is our track.
			ends.append(EditorRoadEndpoint.new(int(record.num), end, position, index))
			## Direction of travel arriving at this end along its own track, in plan view.
			var direction: Vector3 = position - _pos(points[neighbour])
			arriving.append(Vector3(direction.x, 0.0, direction.z))
	var links: Array = RoadEndpointConnection.neighbors(ends)
	var forks: Dictionary = {}
	for i: int in range(ends.size()):
		var connected: Array[int] = []
		for j: int in links[i]:
			## Arriving along track i, a train leaves along track j in the direction opposite to j's own
			## arriving direction. The turn between the two is what a train would have to curve through.
			if _turn_degrees(arriving[i], -arriving[j]) <= MAX_TURN_DEGREES and not connected.has(ends[j].road_num):
				connected.append(ends[j].road_num)
		connected.sort()
		forks[_key(ends[i].road_num, ends[i].node_index)] = connected
	return forks

## Set every track end's fork to what the geometry calls for. The input stays untouched.
## Returns {"records": Array (deep copy with the generated forks), "same": int, "differ": int,
## "report": Array[String]}: one report line per differing track end, naming the hand-made and the
## generated list, then a summary line. With differ == 0 the copy equals the input.
##
## Only "connectiveTracks" is replaced; other keys of an existing fork (e.g. "static") stay. A track end
## that connects to nothing loses its fork entirely, since ForkMapper expects every fork to list tracks.
## Points between the ends are never touched (no fork in the maps sits there). Ends that already agree
## are left exactly as they are, even if their list is unsorted or repeats a number.
static func apply(records: Array) -> Dictionary:
	var output: Array = records.duplicate(true)
	var generated: Dictionary = generate(output)
	var report: Array[String] = []
	var same: int = 0
	for record: Dictionary in output:
		var points: Array = record.points
		if points.size() < 2:
			continue
		for index: int in [0, points.size() - 1]:
			var wanted: Array = generated.get(_key(int(record.num), index), [])
			var current: Array[int] = _existing(points[index])
			if current == wanted:
				same += 1
				continue
			report.append("Track %d %s: has %s, geometry says %s" % [int(record.num),
				"start" if index == 0 else "end", _list_text(current), _list_text(wanted)])
			_set_fork(points[index], wanted)
	report.append("Summary: %d track ends agree, %d differ." % [same, report.size()])
	return {"records": output, "same": same, "differ": report.size() - 1, "report": report}

#region Helpers
## Change of direction between two plan-view directions, 0° = straight on, 180° = turning back.
static func _turn_degrees(from: Vector3, to: Vector3) -> float:
	if from.is_zero_approx() or to.is_zero_approx():
		return 180.0
	return rad_to_deg(from.angle_to(to))

## Hand-made connections of one point, sorted, or [] without a fork. JSON numbers arrive as floats.
static func _existing(point: Dictionary) -> Array[int]:
	var result: Array[int] = []
	var fork: Variant = point.get("fork")
	if fork is Dictionary:
		for num: Variant in fork.get("connectiveTracks", []):
			if not result.has(int(num)):
				result.append(int(num))
	result.sort()
	return result

## Write `nums` into the point's fork, creating the fork if needed, or drop the fork when `nums` is empty.
static func _set_fork(point: Dictionary, nums: Array) -> void:
	if nums.is_empty():
		point.erase("fork")
		return
	var fork: Variant = point.get("fork")
	if not fork is Dictionary:
		fork = {}
		point["fork"] = fork
	fork["connectiveTracks"] = nums.duplicate()

static func _list_text(nums: Array) -> String:
	return "[%s]" % ", ".join(nums.map(func(n: int) -> String: return str(n))) if not nums.is_empty() else "no fork"

static func _key(num: int, index: int) -> String:
	return "%d:%d" % [num, index]

static func _pos(point: Dictionary) -> Vector3:
	return Vector3(float(point.pos[0]), float(point.pos[1]), float(point.pos[2]))
#endregion
