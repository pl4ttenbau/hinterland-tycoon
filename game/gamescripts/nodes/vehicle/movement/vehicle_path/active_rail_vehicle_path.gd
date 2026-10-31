class_name ActiveRailVehiclePath extends Path3D

## Show the active route with the existing green marker balls.
const SHOW_DEBUG: bool = true
const SEGMENT_NODE_MARKER_PATH = "res://assets/meshes/markers/infr_end/selected_node.tscn"
const DEBUG_MARKERS_PARENT_NAME = "DebugMarkers"

signal extended(added_segment)

@export var train3d: Train3D
@export var segments: Array[VehiclePathSegment] = []
## Each segment ends at this curve point; joined endpoints share one point.
var segment_end_points: Array[int] = []
## Distances identify segment boundaries even when a route visits the same fork twice.
var segment_end_distances: Array[float] = []
## Keep callbacks so obsolete routes and freed trains can disconnect their listeners.
var watched_forks: Dictionary = {}
## Plan at least this far ahead, without committing the fork settings.
const LOOKAHEAD_METRES: float = 20.0

static func of_segment(_train: Train3D, _segment: VehiclePathSegment) -> ActiveRailVehiclePath:
	## The active curve keeps travelled history as well as a provisional route ahead.
	var active_path := ActiveRailVehiclePath.new()
	active_path.train3d = _train
	active_path.curve = Curve3D.new()
	active_path.curve.up_vector_enabled = true
	active_path.add_segment(_segment)
	return active_path

## Append geometry, remember the segment boundary, and update its fork listeners and markers.
func add_segment(added_segment: VehiclePathSegment) -> Curve3D:
	self._append_track_curve(self._get_curve_in_travel_direction(added_segment))
	self.segments.append(added_segment)
	self.segment_end_points.append(self.curve.point_count - 1)
	self.segment_end_distances.append(self.curve.get_baked_length())
	self._watch_segment_forks(added_segment)
	self.refresh_debug_markers()
	self.extended.emit(added_segment)
	return self.curve

## Reverse both point order and handles when entering a track from its far end.
func _get_curve_in_travel_direction(segment: VehiclePathSegment) -> Curve3D:
	## Reuse the track's own curve so authored handles are preserved.
	var track: RailTrackData = segment.as_rail_track()
	if track.curve == null:
		track.build_curve()
	if segment.movement_dir == Enums.PathDirection.TRACK_NODES_DECREASE:
		return PathCurveUtils.reverse_curve3d(track.curve)
	return track.curve

## Shared endpoints become one curve point, while other points keep their rail handles.
func _append_track_curve(track_curve: Curve3D) -> void:
	for point_i: int in range(track_curve.point_count):
		if self._ends_at(track_curve.get_point_position(point_i)):
			self._join_outgoing_handle(track_curve, point_i)
		else:
			self.curve.add_point(track_curve.get_point_position(point_i), track_curve.get_point_in(point_i), track_curve.get_point_out(point_i))

## Compare the new point with the current endpoint to avoid duplicate fork points.
func _ends_at(position: Vector3) -> bool:
	return self.curve.point_count > 0 and self.curve.get_point_position(self.curve.point_count - 1).is_equal_approx(position)

## Align only the outgoing span, leaving the existing approach geometry untouched.
func _join_outgoing_handle(track_curve: Curve3D, point_i: int) -> void:
	## Prefer the approach heading; the new track supplies a fallback for degenerate geometry.
	var junction_tangent: Vector3 = self._get_approach_tangent()
	if junction_tangent.is_zero_approx():
		junction_tangent = track_curve.get_point_out(point_i).normalized()
	self.curve.set_point_out(self.curve.point_count - 1, junction_tangent * self._get_outgoing_handle_length(track_curve, point_i))

## The incoming handle points backwards, so negate it to obtain the travel direction.
func _get_approach_tangent() -> Vector3:
	## The shared junction is the last point already present in the active curve.
	var last_i: int = self.curve.point_count - 1
	## A zero handle still approaches from the previous span's final control point.
	var tangent: Vector3 = -self.curve.get_point_in(last_i).normalized()
	if tangent.is_zero_approx() and last_i > 0:
		tangent = (self.curve.get_point_position(last_i) - self.curve.get_point_position(last_i - 1) - self.curve.get_point_out(last_i - 1)).normalized()
	return tangent

## Default endpoints need a handle length derived from the next span to support a smooth join.
func _get_outgoing_handle_length(track_curve: Curve3D, point_i: int) -> float:
	## Keep an authored handle length whenever the track provides one.
	var handle_length: float = track_curve.get_point_out(point_i).length()
	if is_zero_approx(handle_length) and point_i + 1 < track_curve.point_count:
		return track_curve.get_point_position(point_i).distance_to(track_curve.get_point_position(point_i + 1)) / 3.0
	return handle_length

## Extend before arrival so rotation already has geometry on both sides of the fork.
func ensure_lookahead(front_distance: float) -> void:
	## The cap prevents malformed zero-length track cycles from hanging a frame.
	var extensions: int = 0
	while self.curve.get_baked_length() < front_distance + LOOKAHEAD_METRES and extensions < 64:
		## Only the final planned segment chooses the next provisional connection.
		var next_segment: VehiclePathSegment = VehiclePathSegmentBuilder.find_next_segment(self.segments.back())
		if next_segment == null:
			break
		self.add_segment(next_segment)
		extensions += 1

## Return the segment under the locomotive, rather than the furthest planned segment.
func get_segment_index(distance: float) -> int:
	for segment_i: int in range(self.segment_end_distances.size()):
		if distance < self.segment_end_distances[segment_i]:
			return segment_i
	return self.segments.size() - 1

func get_current_segment() -> VehiclePathSegment:
	return self.segments[self.get_segment_index(self.train3d.m_passed_since_start)]

## Both ends can be switched, including the starting fork beneath a parked train.
func _watch_segment_forks(segment: VehiclePathSegment) -> void:
	self._watch_fork(segment.start_node.fork)
	self._watch_fork(segment.end_node.fork)

## Reconnect only the forks still belonging to the retained route.
func _refresh_fork_listeners() -> void:
	self._disconnect_forks()
	for segment: VehiclePathSegment in self.segments:
		self._watch_segment_forks(segment)

## A fork listener also covers changes beneath a stopped train.
func _watch_fork(node_fork: RailNodeForkData) -> void:
	if node_fork == null:
		return
	## All track endpoints at this position belong to the same physical switch.
	var fork: NewRailForkData = Managers.forks.get_fork_at_pos(node_fork.position)
	if fork == null or self.watched_forks.has(fork):
		return
	## Listen to the setting itself, including changes made outside the fork UI.
	var callback: Callable = self._on_fork_changed.bind(fork)
	self.watched_forks[fork] = callback
	if fork.setting.current != null:
		fork.setting.current.setting_changed.connect(callback)
	else:
		## Trains created while loading also subscribe once switch settings are ready.
		fork.setting_initialized.connect(self._on_fork_setting_initialized.bind(fork), CONNECT_ONE_SHOT)

## Fork settings may become available after the initial train path is created.
func _on_fork_setting_initialized(_setting: RailForkSetting, fork: NewRailForkData) -> void:
	if fork.setting.current != null and not fork.setting.current.setting_changed.is_connected(self.watched_forks[fork]):
		fork.setting.current.setting_changed.connect(self.watched_forks[fork])

## Check occupancy before rebuilding anything, so a changed switch cannot reshape an occupied route.
func _on_fork_changed(fork: NewRailForkData) -> void:
	## A loop may visit the same fork more than once; each visit has its own boundary.
	var boundaries: Array[int] = self._get_fork_boundaries(fork)
	if self._is_fork_occupied(fork, boundaries):
		self.train3d.derail()
		return
	self._rebuild_ahead_of_fork(boundaries)

## Collect segment ends at this physical fork in route order.
func _get_fork_boundaries(fork: NewRailForkData) -> Array[int]:
	## Keep every occurrence so loops cannot hide an occupied crossing.
	var boundaries: Array[int] = []
	for segment_i: int in range(self.segments.size()):
		if self.segments[segment_i].end_node.position.is_equal_approx(fork.pos):
			boundaries.append(segment_i)
	return boundaries

## Include the route's starting fork as well as every segment-end crossing.
func _is_fork_occupied(fork: NewRailForkData, boundaries: Array[int]) -> bool:
	if self.segments[0].start_node.position.is_equal_approx(fork.pos) and self.train3d.occupies_path_distance(0.0):
		return true
	for segment_i: int in boundaries:
		if self.train3d.occupies_path_distance(self.segment_end_distances[segment_i]):
			return true
	return false

## Only the first unoccupied crossing ahead invalidates the provisional suffix.
func _rebuild_ahead_of_fork(boundaries: Array[int]) -> void:
	for segment_i: int in boundaries:
		if self.segment_end_distances[segment_i] > self.train3d.get_front_distance():
			self._truncate_after_segment(segment_i)
			self.ensure_lookahead(self.train3d.get_front_distance())
			return

## Preserve the route through this segment and discard only the provisional suffix.
func _truncate_after_segment(segment_i: int) -> void:
	self._trim_curve_after_point(self.curve, self.segment_end_points[segment_i])
	self._release_segment_links(segment_i + 1)
	self.segments.resize(segment_i + 1)
	self.segment_end_points.resize(segment_i + 1)
	self.segment_end_distances.resize(segment_i + 1)
	self.segments.back().next = null
	self.segments.back().continues = false
	self._refresh_fork_listeners()
	self.refresh_debug_markers()

## Trim a curve in place, keeping the selected point and all preceding geometry.
func _trim_curve_after_point(target_curve: Curve3D, last_point_i: int) -> void:
	while target_curve.point_count > last_point_i + 1:
		target_curve.remove_point(target_curve.point_count - 1)

## Reverse the geometry and its segment bookkeeping without snapping to a nearby rail node.
func reverse_route() -> void:
	## Original segment starts become segment ends when traversed in reverse order.
	var old_starts: Array[int] = self._get_segment_start_points()
	self.curve = PathCurveUtils.reverse_curve3d(self.curve)
	self.segments.reverse()
	old_starts.reverse()
	self._reverse_segment_links()
	self._rebuild_reversed_boundaries(old_starts)
	self.refresh_debug_markers()

## Adjacent segments share their boundary point, so each end is also the next start.
func _get_segment_start_points() -> Array[int]:
	## The first segment always begins at the start of the assembled curve.
	var starts: Array[int] = [0]
	for segment_i: int in range(self.segment_end_points.size() - 1):
		starts.append(self.segment_end_points[segment_i])
	return starts

## Reverse each segment's direction and reconnect neighbours in the new travel order.
func _reverse_segment_links() -> void:
	for segment_i: int in range(self.segments.size()):
		self.segments[segment_i].reverse()
		self.segments[segment_i].previous = self.segments[segment_i - 1] if segment_i > 0 else null
		self.segments[segment_i].next = self.segments[segment_i + 1] if segment_i + 1 < self.segments.size() else null
		self.segments[segment_i].continues = segment_i + 1 < self.segments.size()

## Mirror point indices and measure each prefix so repeated positions in loops remain distinct.
func _rebuild_reversed_boundaries(old_starts: Array[int]) -> void:
	self.segment_end_points.clear()
	self.segment_end_distances.clear()
	for old_start: int in old_starts:
		self.segment_end_points.append(self.curve.point_count - 1 - old_start)
		self.segment_end_distances.append(self._get_distance_to_point(self.segment_end_points.back()))

## Measure along the curve rather than finding the nearest occurrence of a repeated position.
func _get_distance_to_point(point_i: int) -> float:
	## Trimming a copy leaves the active geometry intact.
	var prefix: Curve3D = self.curve.duplicate()
	self._trim_curve_after_point(prefix, point_i)
	return prefix.get_baked_length()

## Curve samples provide both position and direction at every movement step.
func get_transf_at_m_passed(m_passed: float) -> Transform3D:
	return self.global_transform * self.curve.sample_baked_with_rotation(clampf(m_passed, 0.0, self.curve.get_baked_length()), true)

## Disconnect Resource signals explicitly because fork data can outlive the train.
func _disconnect_forks() -> void:
	for fork: NewRailForkData in self.watched_forks:
		if fork.setting.current != null and fork.setting.current.setting_changed.is_connected(self.watched_forks[fork]):
			fork.setting.current.setting_changed.disconnect(self.watched_forks[fork])
		if fork.setting_initialized.is_connected(self._on_fork_setting_initialized.bind(fork)):
			fork.setting_initialized.disconnect(self._on_fork_setting_initialized.bind(fork))
	self.watched_forks.clear()

## Break bidirectional Resource links so discarded or freed route segments can be released.
func _release_segment_links(first_segment_i: int) -> void:
	for segment_i: int in range(first_segment_i, self.segments.size()):
		self.segments[segment_i].previous = null
		self.segments[segment_i].next = null

## Fork data and linked segment resources can outlive the train unless explicitly released.
func _exit_tree() -> void:
	self._disconnect_forks()
	self._release_segment_links(0)

#region Debug Markers
## Rebuild from the current curve so discarded branches disappear and shared points show once.
func refresh_debug_markers() -> void:
	if not SHOW_DEBUG:
		return
	self._clear_debug_markers()
	for point_i: int in range(self.curve.point_count):
		self._add_debug_marker_at(self.curve.get_point_position(point_i))

## Detach old balls immediately; queued deletion alone leaves them visible until frame end.
func _clear_debug_markers() -> void:
	## All route balls live under one parent so they can be replaced together.
	var markers_parent: Node3D = self.get_or_add_markers_parent()
	for marker: Node in markers_parent.get_children():
		markers_parent.remove_child(marker)
		marker.queue_free()

func _add_debug_marker_at(pos: Vector3) -> Node3D:
	var marker_prefab: PackedScene = load(SEGMENT_NODE_MARKER_PATH)
	# check for DebugPath parent, add if null
	var markers_parent: Node3D = self.get_or_add_markers_parent()
	# instantiate
	var marker_instance: Node3D = marker_prefab.instantiate()
	markers_parent.add_child(marker_instance)
	marker_instance.position = pos
	marker_instance.position.y += .8
	return marker_instance

func get_or_add_markers_parent() -> Node3D:
	if !self.has_node(DEBUG_MARKERS_PARENT_NAME):
		var new_markers_parent: Node3D = Node3D.new()
		self.add_child(new_markers_parent)
		new_markers_parent.name = DEBUG_MARKERS_PARENT_NAME
		return new_markers_parent
	else:
		return self.get_node(DEBUG_MARKERS_PARENT_NAME)
#endregion
