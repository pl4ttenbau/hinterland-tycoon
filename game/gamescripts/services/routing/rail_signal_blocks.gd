## Automatic block signalling. A signal shows stop while any train body is on the track ahead of it,
## up to the next signal for the same direction, a buffer or the end of the connected route.
## The block follows the current switch settings, like a train's planned route does.
class_name RailSignalBlocks extends RefCounted

## Stop looking for the block end after this distance, so open-ended lines stay cheap.
const MAX_BLOCK_METRES: float = 5000.0
## Trains stop with their nose this far short of a signal showing stop.
const STOP_MARGIN_METRES: float = 2.0

static func get_store() -> RailSignalStore:
	return Managers.rails.signals if is_instance_valid(Managers.rails) else null

## Track offsets covered by train bodies, as {track_num: [Vector2(from, to), ...]}.
static func occupancy(trains: Array, exclude: Train3D = null) -> Dictionary:
	var spans: Dictionary = {}
	for train: Variant in trains:
		if not is_instance_valid(train) or train == exclude or train.movement == null:
			continue
		var path: ActiveRailVehiclePath = train.movement.get_active_path()
		if not is_instance_valid(path) or train.vehicles.is_empty():
			continue
		var rear: float = INF
		var front: float = -INF
		for vehicle: Vehicle3D in train.vehicles:
			var half: float = half_length(vehicle)
			var distance: float = train.movement.get_vehicle_distance(vehicle)
			rear = minf(rear, distance - half)
			front = maxf(front, distance + half)
		_add_path_spans(path, rear, front, spans)
	return spans

static func _add_path_spans(path: ActiveRailVehiclePath, rear: float, front: float, spans: Dictionary) -> void:
	for segment_i: int in range(path.segments.size()):
		var seg_start: float = 0.0 if segment_i == 0 else path.segment_end_distances[segment_i - 1]
		var seg_end: float = path.segment_end_distances[segment_i]
		var from: float = maxf(rear, seg_start)
		var to: float = minf(front, seg_end)
		if from > to:
			continue
		var segment: VehiclePathSegment = path.segments[segment_i]
		var a: float = path_to_track_offset(segment, seg_start, seg_end, from)
		var b: float = path_to_track_offset(segment, seg_start, seg_end, to)
		if not spans.has(segment.track_num):
			spans[segment.track_num] = []
		spans[segment.track_num].append(Vector2(minf(a, b), maxf(a, b)))

## Map a distance on a train's path to a distance along the segment's track from its first node.
## Proportional, because joined curve handles can make the path slightly longer or shorter than the track.
static func path_to_track_offset(segment: VehiclePathSegment, seg_start: float, seg_end: float, distance: float) -> float:
	var fraction: float = clampf((distance - seg_start) / maxf(seg_end - seg_start, 0.001), 0.0, 1.0)
	if segment.movement_dir == Enums.PathDirection.TRACK_NODES_DECREASE:
		fraction = 1.0 - fraction
	return fraction * track_length(segment.as_rail_track())

static func track_to_path_distance(segment: VehiclePathSegment, seg_start: float, seg_end: float, offset: float) -> float:
	var fraction: float = clampf(offset / maxf(track_length(segment.as_rail_track()), 0.001), 0.0, 1.0)
	if segment.movement_dir == Enums.PathDirection.TRACK_NODES_DECREASE:
		fraction = 1.0 - fraction
	return seg_start + fraction * (seg_end - seg_start)

static func track_length(track: RailTrackData) -> float:
	if track == null:
		return 0.0
	if track.curve == null:
		track.build_curve()
	return track.curve.get_baked_length()

## Whether the block a signal protects for `direction` is free of train bodies.
static func is_block_clear(rail_signal: RailSignalData, direction: Enums.PathDirection, store: RailSignalStore, spans: Dictionary) -> bool:
	var track: RailTrackData = RailTrackData.get_by_num(rail_signal.track_num)
	var dir: Enums.PathDirection = direction
	var from: float = rail_signal.offset
	var walked: float = 0.0
	var visited: Dictionary = {}
	while track != null and walked < MAX_BLOCK_METRES:
		var key: int = track.num * 2 + (0 if dir == Enums.PathDirection.TRACK_NODES_INCREASE else 1)
		if visited.has(key):
			return true
		visited[key] = true
		var increasing: bool = dir == Enums.PathDirection.TRACK_NODES_INCREASE
		var to: float = track_length(track) if increasing else 0.0
		var ends_at_signal: bool = false
		for other: RailSignalData in store.get_on_track(track.num):
			if other == rail_signal or not other.protects(dir):
				continue
			var ahead: bool = other.offset > from if increasing else other.offset < from
			if ahead and absf(other.offset - from) < absf(to - from):
				to = other.offset
				ends_at_signal = true
		if _is_occupied(spans, track.num, minf(from, to), maxf(from, to)):
			return false
		if ends_at_signal:
			return true
		walked += absf(to - from)
		var end_node: RailNodeData = track.nodes.back() if increasing else track.nodes[0]
		var next_num: int = VehiclePathSegmentBuilder.get_next_track_num_from_node(end_node)
		var next_dir: Enums.PathDirection = VehiclePathSegmentBuilder.get_next_dir_at_fork(next_num, end_node)
		if next_num < 0 or next_dir == Enums.PathDirection.STOP:
			return true
		var next_track: RailTrackData = RailTrackData.get_by_num(next_num)
		if next_track == null or not InfrType.rail_gauges_compatible(track.infr_type_key, next_track.infr_type_key):
			return true
		track = next_track
		dir = next_dir
		from = 0.0 if dir == Enums.PathDirection.TRACK_NODES_INCREASE else track_length(track)
	return true

static func _is_occupied(spans: Dictionary, track_num: int, from: float, to: float) -> bool:
	for span: Vector2 in spans.get(track_num, []):
		if span.x <= to and span.y >= from:
			return true
	return false

static func half_length(vehicle: Vehicle3D) -> float:
	if vehicle == null or vehicle.vehicle_obj == null or vehicle.vehicle_obj.veh_type == null:
		return 0.0
	return vehicle.vehicle_obj.veh_type.length_metres * 0.5
