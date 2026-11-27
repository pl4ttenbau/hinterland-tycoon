@tool
## Repairs common faults in a map's rail track JSON (tracks.json): duplicate points and kinked joins.
##
## Pure data in, data out: `repair()` takes the parsed track records and returns repaired copies plus a
## human-readable report. It never touches files or the scene; RailTrackRepairCli does that, and only
## with --write. That keeps every change reviewable as a plan first, and makes the logic easy to test.
##
## Background: tracks are polylines of authored points. The game turns each into a centripetal
## Catmull-Rom curve (InfrUtils.smooth_curve3d), one track at a time. At an open end the curve's
## direction is simply the chord towards the neighbouring point. So where one track continues into
## another, the curve can only be smooth if both tracks' neighbouring points lie on one straight line
## through the shared end point. If they do not, the line shows a visible corner there, however well
## each track is curved on its own. Smoothing cannot fix that, because it never sees both tracks.
##
## What it repairs (steps 1 and 2 of the track clean-up plan; radius relaxation and grades come later):
## 1. Duplicate points: consecutive points of one track at (almost) the same position. Catmull-Rom has no
##    direction there and falls back to a sharp corner. The two are merged, keeping any metadata.
## 2. Kinked joins: two track ends meeting at one point (a plain continuation, not a switch), whose
##    directions disagree. Both neighbouring points are turned onto the average direction, keeping
##    their distance from the join and their height, so the line runs straight through the join.
##
## What it never moves: end points (other tracks, depots and stations attach there), and any point that
## carries metadata (a fork/switch, an end marker, a bridge, ...) or is shared with another track.
class_name RailTrackRepair extends RefCounted

## Consecutive points closer than this (in metres, 3D) count as duplicates.
const DUPLICATE_TOLERANCE: float = 0.05
## Points of different tracks closer than this (in metres, 3D) count as the same physical point. Track
## ends are snapped together when drawn, so real joins are far closer; 0.25 m tolerates rounding.
const JOIN_TOLERANCE: float = 0.25
## Joins kinked by less than this are left alone: invisible, and not worth moving points for.
const MIN_KINK_DEGREES: float = 1.0
## Joins kinked by more than this are reported but not touched. A corner that sharp is unlikely to be a
## plain continuation drawn slightly off; it needs a look by hand (a missing curve, a misplaced end, or
## two tracks that only happen to touch).
const MAX_KINK_DEGREES: float = 60.0
## Point keys that only describe geometry. A point with any other key carries meaning (fork, end, bridge,
## station link, ...) and must not move or be merged away.
const GEOMETRY_KEYS: Array[String] = ["pos", "handleIn", "handleOut"]

## Repair the given track records. The input stays untouched.
## Returns {"records": Array (repaired deep copy), "report": Array[String], "duplicates": int,
## "aligned": int, "skipped": int, "max_shift": float} where max_shift is the largest distance any
## point was moved, in metres.
static func repair(records: Array) -> Dictionary:
	var output: Array = records.duplicate(true)
	var report: Array[String] = []
	var duplicates: int = 0
	for record: Dictionary in output:
		duplicates += _merge_duplicates(record, report)
	var joins: Dictionary = _align_joins(output, report)
	report.append("Summary: %d duplicate point(s) merged, %d join(s) aligned, %d join(s) left for manual review, largest point shift %.2f m." \
		% [duplicates, joins.aligned, joins.skipped, joins.max_shift])
	return {"records": output, "report": report, "duplicates": duplicates,
		"aligned": joins.aligned, "skipped": joins.skipped, "max_shift": joins.max_shift}

#region Step 1: duplicate points
## Merge runs of consecutive duplicate points within one record. Returns how many points were removed.
## Of each duplicate pair the copy with metadata survives; if both carry metadata they are left as they
## are and reported, since merging would have to pick one meaning over the other.
static func _merge_duplicates(record: Dictionary, report: Array[String]) -> int:
	var points: Array = record.points
	var removed: int = 0
	var index: int = 0
	while index < points.size() - 1:
		var here: Dictionary = points[index]
		var next: Dictionary = points[index + 1]
		if _pos(here).distance_to(_pos(next)) > DUPLICATE_TOLERANCE:
			index += 1
			continue
		var here_meta: bool = _has_metadata(here)
		var next_meta: bool = _has_metadata(next)
		if here_meta and next_meta:
			report.append("Track %d: points %d and %d coincide but both carry metadata; left for manual review." \
				% [int(record.num), index + 1, index + 2])
			index += 1
			continue
		## Keep the meaningful one. Its authored handles described a curve through a duplicate point and
		## are stale now, so the game recomputes them.
		var keep: Dictionary = next if next_meta else here
		keep.erase("handleIn")
		keep.erase("handleOut")
		points[index] = keep
		points.remove_at(index + 1)
		report.append("Track %d: merged duplicate points %d and %d." % [int(record.num), index + 1, index + 2])
		removed += 1
		## Stay on this index: a third copy may follow.
	return removed
#endregion

#region Step 2: kinked joins
## Find every plain two-track join and straighten the line through it.
static func _align_joins(records: Array, report: Array[String]) -> Dictionary:
	var locations: Array[Dictionary] = _all_points(records)
	## Points moved by an earlier join are locked, so two joins never pull one point back and forth.
	var locked: Dictionary = {}
	var seen_pairs: Dictionary = {}
	var aligned: int = 0
	var skipped: int = 0
	var max_shift: float = 0.0
	for record: Dictionary in records:
		for at_start: bool in [true, false]:
			var end_index: int = 0 if at_start else record.points.size() - 1
			var join: Vector3 = _pos(record.points[end_index])
			var here: Array[Dictionary] = _points_near(locations, join)
			## Exactly two points, and both are track ends: a plain continuation. Three or more is a
			## switch or a crossing, where the authored geometry is intentional.
			if here.size() != 2 or not here[0].is_end or not here[1].is_end:
				continue
			var pair_key: String = "%d:%d-%d:%d" % _sorted_pair(here)
			if seen_pairs.has(pair_key):
				continue
			seen_pairs[pair_key] = true
			var result: Dictionary = _align_one(here[0], here[1], join, locations, locked)
			if result.status == "aligned":
				aligned += 1
				max_shift = maxf(max_shift, result.shift)
			elif result.status == "skipped":
				skipped += 1
			if not result.message.is_empty():
				report.append(result.message)
	return {"aligned": aligned, "skipped": skipped, "max_shift": max_shift}

## Straighten one join between end `a` and end `b`, both at `join`.
static func _align_one(a: Dictionary, b: Dictionary, join: Vector3, locations: Array[Dictionary], locked: Dictionary) -> Dictionary:
	var label: String = "Join of track %d (%s) and track %d (%s)" % [a.num, "start" if a.index == 0 else "end",
		b.num, "start" if b.index == 0 else "end"]
	var a_neighbour: Dictionary = _neighbour(a)
	var b_neighbour: Dictionary = _neighbour(b)
	## Work in the horizontal plane: heights are a separate job (grades), and the kink is a plan view fault.
	var a_flat: Vector3 = _flat(join - _pos(a_neighbour.point))
	var b_flat: Vector3 = _flat(join - _pos(b_neighbour.point))
	if a_flat.is_zero_approx() or b_flat.is_zero_approx():
		return {"status": "skipped", "shift": 0.0, "message": label + ": a neighbouring point sits on the join; left for manual review."}
	## Directions of travel through the join: arriving along A, leaving along B.
	var arriving: Vector3 = a_flat.normalized()
	var leaving: Vector3 = -b_flat.normalized()
	var kink: float = rad_to_deg(arriving.angle_to(leaving))
	if kink < MIN_KINK_DEGREES:
		return {"status": "fine", "shift": 0.0, "message": ""}
	if kink > MAX_KINK_DEGREES:
		return {"status": "skipped", "shift": 0.0,
			"message": "%s: %.1f° kink is too sharp to be a drawing slip; left for manual review." % [label, kink]}
	var a_free: bool = _movable(a_neighbour, locations, locked)
	var b_free: bool = _movable(b_neighbour, locations, locked)
	## Both free: meet in the middle, so each side turns by half the kink and neither moves far.
	## One free: that side turns by the whole kink onto the other's direction.
	var through: Vector3
	if a_free and b_free:
		through = (arriving + leaving).normalized()
	elif a_free:
		through = leaving
	elif b_free:
		through = arriving
	else:
		return {"status": "skipped", "shift": 0.0,
			"message": "%s: %.1f° kink, but both neighbouring points are fixed (track ends, metadata or shared); left for manual review." % [label, kink]}
	var shift: float = 0.0
	if a_free:
		shift = maxf(shift, _place(a_neighbour, join - through * a_flat.length(), locked))
	if b_free:
		shift = maxf(shift, _place(b_neighbour, join + through * b_flat.length(), locked))
	## The end points' own handles, if authored, would keep the old corner.
	for end: Dictionary in [a, b]:
		end.point.erase("handleIn")
		end.point.erase("handleOut")
	return {"status": "aligned", "shift": shift,
		"message": "%s: straightened a %.1f° kink, moved %s by up to %.2f m." % [label, kink,
			"both neighbouring points" if a_free and b_free else "one neighbouring point", shift]}

## Move a point horizontally to `target`, keeping its height, and drop its now stale handles.
## Returns the distance moved.
static func _place(entry: Dictionary, target: Vector3, locked: Dictionary) -> float:
	var old: Vector3 = _pos(entry.point)
	var new: Vector3 = Vector3(target.x, old.y, target.z)
	entry.point.pos = [new.x, new.y, new.z]
	entry.point.erase("handleIn")
	entry.point.erase("handleOut")
	locked[_key(entry)] = true
	return old.distance_to(new)

## A neighbouring point may move only if it is an interior point, carries no metadata, is not shared
## with another track, and has not already been placed by another join.
static func _movable(entry: Dictionary, locations: Array[Dictionary], locked: Dictionary) -> bool:
	if entry.is_end or _has_metadata(entry.point) or locked.has(_key(entry)):
		return false
	return _points_near(locations, _pos(entry.point)).size() == 1
#endregion

#region Helpers
## Every point of every record, with where it sits: {num, index, is_end, point (the live Dictionary)}.
static func _all_points(records: Array) -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	for record: Dictionary in records:
		var last: int = record.points.size() - 1
		for index: int in range(record.points.size()):
			all.append({"num": int(record.num), "index": index, "is_end": index == 0 or index == last,
				"point": record.points[index], "points": record.points})
	return all

## Every point within JOIN_TOLERANCE of `position`, from any track.
## A linear scan: maps have a few thousand points and this runs once per track end, well under a second.
static func _points_near(locations: Array[Dictionary], position: Vector3) -> Array[Dictionary]:
	var near: Array[Dictionary] = []
	for entry: Dictionary in locations:
		if _pos(entry.point).distance_to(position) <= JOIN_TOLERANCE:
			near.append(entry)
	return near

## The point next to a track end, on the inside: the one that sets the curve's direction at that end.
static func _neighbour(end: Dictionary) -> Dictionary:
	var points: Array = end.points
	var index: int = 1 if end.index == 0 else points.size() - 2
	return {"num": end.num, "index": index, "is_end": index == 0 or index == points.size() - 1,
		"point": points[index], "points": points}

## Stable identity of a point: its track and index. The point Dictionary itself cannot serve, because
## Godot hashes Dictionary keys by content, and the content changes when the point moves.
static func _key(entry: Dictionary) -> String:
	return "%d:%d" % [entry.num, entry.index]

## The two ends of a join as [num, index, num, index], lowest track first, so each join is handled once
## however it is reached. (GDScript cannot compare Arrays with <, hence the explicit test.)
static func _sorted_pair(pair: Array[Dictionary]) -> Array:
	var a: Dictionary = pair[0]
	var b: Dictionary = pair[1]
	var a_first: bool = a.num < b.num or (a.num == b.num and a.index < b.index)
	return [a.num, a.index, b.num, b.index] if a_first else [b.num, b.index, a.num, a.index]

static func _has_metadata(point: Dictionary) -> bool:
	for key: Variant in point.keys():
		if not GEOMETRY_KEYS.has(str(key)):
			return true
	return false

static func _pos(point: Dictionary) -> Vector3:
	return Vector3(float(point.pos[0]), float(point.pos[1]), float(point.pos[2]))

static func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)
#endregion
