## Shared erasure for loaders of curve-based lines (rail tracks, roads).
## Erasing cuts a gap into a line: the line keeps the part before the gap,
## and the part after it becomes a new line with the next free number.
## Subclasses veto edits and keep their junctions, ends and views in sync.
@abstract
class_name AbstractTrackLoader extends Node

## Emitted after any edit to the network's topology.
signal network_changed()

## Lines and nodes of one split, handed to the hooks.
class Split extends RefCounted:
	var track: AbstractInfrLine
	## The nodes before the split, in their old order.
	var old_nodes: Array
	## The line itself first if it keeps a part, then at most one new line.
	var fragments: Array[AbstractInfrLine] = []
	## Every node that keeps a line, as a set.
	var surviving: Dictionary = {}

	func removed_nodes() -> Array:
		return self.old_nodes.filter(func(node: AbstractInfrNode) -> bool:
			return not self.surviving.has(node))

@abstract func _store() -> AbstractTrackStore
## An empty line of the subclass's type; the split fills it.
@abstract func _new_track() -> AbstractInfrLine
@abstract func _spawn_view(track: AbstractInfrLine) -> void
## OK, or the reason the line must not change now (usually ERR_BUSY).
@abstract func _split_blocker(track: AbstractInfrLine) -> Error

#region Erasure
## A segment is the span between adjacent authored nodes.
func erase_segment(track: AbstractInfrLine, segment_index: int) -> Error:
	return erase_span(track, segment_index, segment_index + 1)


## The selected endpoints survive if they still have a span on their outside.
func erase_span(track: AbstractInfrLine, from_index: int, to_index: int) -> Error:
	var first: int = mini(from_index, to_index)
	var last: int = maxi(from_index, to_index)
	if not _has_track(track) or not track.has_node_index(first) or not track.has_node_index(last) or first == last:
		return ERR_INVALID_PARAMETER
	return _erase_gap(track, first, last)


## Erase the node and both incident spans, leaving a gap.
func erase_node(track: AbstractInfrLine, index: int) -> Error:
	if not _has_track(track) or not track.has_node_index(index):
		return ERR_INVALID_PARAMETER
	return _erase_gap(track, index - 1, index + 1)


func _has_track(track: AbstractInfrLine) -> bool:
	return track != null and _store()._by_id.get(track.num) == track


## Removes the nodes strictly between left_end and right_start.
## Nothing changes unless every check passes.
func _erase_gap(track: AbstractInfrLine, left_end: int, right_start: int) -> Error:
	var blocker: Error = _split_blocker(track)
	if blocker != OK:
		return blocker
	var source: Curve3D = track.ensure_curve()
	if source.point_count != track.node_count():
		return ERR_INVALID_DATA
	var store: AbstractTrackStore = _store()
	var view: InfrLine3D = store.find_container(track.num)
	var split := Split.new()
	split.track = track
	# A copy: the line's own node array is refilled below.
	split.old_nodes = track.get_nodes().duplicate()
	for points: Vector2i in PathCurveUtils.ranges_after_erase(split.old_nodes.size(), left_end, right_start):
		var section: Curve3D = PathCurveUtils.copy_point_range(source, points, Vector3.ZERO)
		if section.get_baked_length() <= 0.0:
			continue
		var fragment: AbstractInfrLine = track if split.fragments.is_empty() else _new_track()
		if fragment != track:
			fragment.num = store.next_num()
			_copy_track_fields(fragment, track)
		fragment.get_nodes().assign(split.old_nodes.slice(points.x, points.y + 1))
		fragment.start_pos = fragment.first_node().position
		for index: int in fragment.node_count():
			var node: AbstractInfrNode = fragment.get_node_at(index)
			node.parent_track = fragment
			node.index = index
			split.surviving[node] = true
		fragment.curve = section
		_init_fragment(fragment, points.x > 0, points.y < split.old_nodes.size() - 1)
		split.fragments.append(fragment)
	if split.fragments.is_empty():
		store.remove(track)
	elif split.fragments.size() == 2:
		# Publish the new number before junctions and views look it up.
		store.add(split.fragments[1])
	# Erased nodes still know their old line and index while the hook runs.
	_relink(split)
	for node: AbstractInfrNode in split.removed_nodes():
		node.parent_track = null
		node.index = -1
	if split.fragments.is_empty():
		track.get_nodes().clear()
		track.curve = null
	# The surviving view refits itself on curve_built below.
	if is_instance_valid(view) and split.fragments.size() == 2:
		_spawn_view(split.fragments[1])
	for fragment: AbstractInfrLine in split.fragments:
		fragment.curve_built.emit(fragment.curve)
		fragment.track_changed.emit()
		_on_fragment_shown(fragment, is_instance_valid(view))
	_publish_network_change()
	return OK
#endregion

#region Split hooks
## Fields a new line takes over from the line it was cut from.
func _copy_track_fields(fragment: AbstractInfrLine, source: AbstractInfrLine) -> void:
	fragment.track_name = source.track_name
	fragment.tag = source.tag
	fragment.infr_type_key = source.infr_type_key


## Runs once the fragment has its nodes and curve. cut_start/cut_end tell
## whether the gap lies directly before or after it.
func _init_fragment(_fragment: AbstractInfrLine, _cut_start: bool, _cut_end: bool) -> void:
	pass


## Reconnect junctions after the store knows every fragment.
func _relink(_split: Split) -> void:
	pass


## After the fragment's view (if any) shows its new curve.
func _on_fragment_shown(_fragment: AbstractInfrLine, _has_view: bool) -> void:
	pass


func _publish_network_change() -> void:
	network_changed.emit()
#endregion
