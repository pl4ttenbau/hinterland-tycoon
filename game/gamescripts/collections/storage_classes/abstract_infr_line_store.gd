## Shared bookkeeping for a store of curve-based lines (rail tracks, roads) and their views.
## Subclasses keep the typed arrays, because typed arrays cannot be shared, and
## expose them through their typed get_all() and get_containers().
@abstract
class_name AbstractInfrLineStore extends Resource

@export var _by_id: Dictionary = {}
## Highest number added so far; new lines take next_num().
@export var _max_num: int = -1

@export_storage var _containers_by_id: Dictionary = {}

signal line_added(line: AbstractInfrLine)

## The subclass's typed line array.
@abstract func _lines() -> Array
## The subclass's typed view array.
@abstract func _views() -> Array
## Used in lookup errors, e.g. "road".
@abstract func _kind_name() -> String

#region Add
func add(line: AbstractInfrLine) -> void:
	self._lines().append(line)
	self._by_id.set(line.num, line)
	self._max_num = maxi(self._max_num, line.num)
	self.line_added.emit(line)

func add_container(view: InfrLine3D) -> void:
	self._views().append(view)
	self._containers_by_id.set(view.get_line().num, view)

## Number for a newly built or split-off line.
func next_num() -> int:
	return self._max_num + 1
#endregion

## Remove the indexes and detach the view immediately so it stops colliding.
func remove(line: AbstractInfrLine) -> void:
	if self._by_id.get(line.num) != line:
		return
	self._lines().erase(line)
	self._by_id.erase(line.num)
	# Untyped: a freed view cannot be assigned to a typed variable.
	var view: Variant = self._containers_by_id.get(line.num)
	self._containers_by_id.erase(line.num)
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
func get_by_num(num: int) -> AbstractInfrLine:
	var found: AbstractInfrLine = self._by_id.get(num)
	if found == null:
		Loggie.error("Cannot get %s %d; out of index?" % [self._kind_name(), num])
	return found

## Null when the line has no live view; never logs.
func find_container(num: int) -> InfrLine3D:
	var view: Variant = self._containers_by_id.get(num)
	return view if is_instance_valid(view) else null

func get_container_by_num(num: int) -> InfrLine3D:
	var found: InfrLine3D = self.find_container(num)
	if found == null:
		Loggie.error("Cannot get the view of %s %d; out of index?" % [self._kind_name(), num])
	return found
#endregion
