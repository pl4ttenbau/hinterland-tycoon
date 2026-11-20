## Shared bookkeeping for a store of curve-based lines (rail tracks, roads) and their views.
## Subclasses keep the typed arrays, because typed arrays cannot be shared, and
## expose them through their typed get_all() and get_containers().
@abstract
class_name AbstractTrackStore extends Resource

@export var _by_id: Dictionary = {}
## Highest number added so far; new tracks take next_num().
@export var _max_num: int = -1

@export_storage var _containers_by_id: Dictionary = {}

signal track_added(track: AbstractTrack)

## The subclass's typed track array.
@abstract func _tracks() -> Array
## The subclass's typed view array.
@abstract func _views() -> Array
## Used in lookup errors, e.g. "road".
@abstract func _kind_name() -> String

#region Add
func add(track: AbstractTrack) -> void:
	self._tracks().append(track)
	self._by_id.set(track.num, track)
	self._max_num = maxi(self._max_num, track.num)
	self.track_added.emit(track)

func add_container(view: InfrLine3D) -> void:
	self._views().append(view)
	self._containers_by_id.set(view.get_line().num, view)

## Number for a newly built or split-off track.
func next_num() -> int:
	return self._max_num + 1
#endregion

## Remove the indexes and detach the view immediately so it stops colliding.
func remove(track: AbstractTrack) -> void:
	if self._by_id.get(track.num) != track:
		return
	self._tracks().erase(track)
	self._by_id.erase(track.num)
	# Untyped: a freed view cannot be assigned to a typed variable.
	var view: Variant = self._containers_by_id.get(track.num)
	self._containers_by_id.erase(track.num)
	if is_instance_valid(view):
		self._views().erase(view)
		self._on_view_removed(view)
		if view.get_parent() != null:
			view.get_parent().remove_child(view)
		view.queue_free()

## For subclasses that also list their views elsewhere.
func _on_view_removed(_view: InfrLine3D) -> void:
	pass

#region Lookup
func get_by_num(num: int) -> AbstractTrack:
	var found: AbstractTrack = self._by_id.get(num)
	if found == null:
		Loggie.error("Cannot get %s %d; out of index?" % [self._kind_name(), num])
	return found

## Null when the track has no live view; never logs.
func find_container(num: int) -> InfrLine3D:
	var view: Variant = self._containers_by_id.get(num)
	return view if is_instance_valid(view) else null

func get_container_by_num(num: int) -> InfrLine3D:
	var found: InfrLine3D = self.find_container(num)
	if found == null:
		Loggie.error("Cannot get the view of %s %d; out of index?" % [self._kind_name(), num])
	return found
#endregion
