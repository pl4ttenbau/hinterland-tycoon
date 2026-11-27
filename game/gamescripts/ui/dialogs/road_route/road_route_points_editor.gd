## Route points tab of the road route dialog: the ordered list of places the
## vehicle visits. Edits the dialog's draft plan in place and reports which
## point is selected, so the actions tab can show that point's load/unload steps.
##
## A point targets a stop, a depot or a road marker by number. Older plans can
## also hold road/node points (Kind.NODE); they still show and validate here,
## but new ones cannot be added.
class_name RoadRoutePointsEditor extends VBoxContainer

## index into the plan's points, or -1 when nothing is selected.
signal point_selected(index: int)
signal status_changed(message: String)

var _plan: RoadRoutePlan
var _markers: RoadMarkerStore
var _stops: Dictionary
var _depots: Array[RoadDepotData]
## Target numbers in the same order as the items of the %Targets dropdown,
## so the dropdown index maps straight to the number a new point stores.
var _target_ids: Array[int] = []

## The route so far, one row per point.
@onready var _points: ItemList = %Points
## What kind of place to add next: stop, depot or marker.
@onready var _kind: OptionButton = %PointKind
## The concrete places of that kind.
@onready var _targets: OptionButton = %Targets


func _ready() -> void:
	# A new kind refills the target dropdown.
	_kind.item_selected.connect(_fill_point_choices)
	_points.item_selected.connect(_on_point_selected)
	%AddPoint.pressed.connect(_add_point)
	%MoveUp.pressed.connect(_move_point.bind(-1))
	%MoveDown.pressed.connect(_move_point.bind(1))
	%RemovePoint.pressed.connect(_remove_point)


## Starts editing a draft. Selects the first point, which emits point_selected.
func edit(plan: RoadRoutePlan, markers: RoadMarkerStore, stops: Dictionary,
		depots: Array[RoadDepotData]) -> void:
	_plan = plan
	_markers = markers
	_stops = stops
	_depots = depots
	# Maps can have many stops; let the player type to find one.
	_targets.get_popup().allow_search = true
	_fill_point_choices(0)
	refresh_points()


## Lists the places of the chosen kind. The argument comes from the kind
## dropdown's item_selected signal; the selected kind is read from it directly.
func _fill_point_choices(_selection: int) -> void:
	_targets.clear()
	_target_ids.clear()
	match _kind.get_selected_id():
		RoadRoutePoint.Kind.MARKER:
			if _markers != null:
				for marker: RoadMarkerData in _markers.markers:
					_offer_target(marker.num, "%s · %d" % [marker.marker_name, marker.num])
			if _target_ids.is_empty():
				status_changed.emit("No markers yet. On foot, open Build, then Road, and choose Place road marker while standing on a road.")
		RoadRoutePoint.Kind.STOP:
			# stops holds rail stops too; a road vehicle can only visit road stops.
			for id: int in _stops:
				var stop := _stops[id] as RoadStationData
				if stop != null:
					_offer_target(id, "%s · stop %d" % [stop.get_display_name(), id])
		RoadRoutePoint.Kind.DEPOT:
			for depot: RoadDepotData in _depots:
				_offer_target(depot.num, "%s · depot %d" % [depot.depot_name, depot.num])
	%AddPoint.disabled = _target_ids.is_empty()


func _offer_target(id: int, label: String) -> void:
	_target_ids.append(id)
	_targets.add_item(label)


## Appends the chosen place as the route's new last point and selects it.
func _add_point() -> void:
	if _targets.selected < 0:
		return
	var point := RoadRoutePoint.new()
	point.kind = _kind.get_selected_id() as RoadRoutePoint.Kind
	point.target_num = _target_ids[_targets.selected]
	_plan.points.append(point)
	refresh_points(_plan.points.size() - 1)


## Moves the selected point one place up (-1) or down (+1); it stays selected.
func _move_point(direction: int) -> void:
	var index: int = _selected_point()
	var target: int = index + direction
	if index < 0 or target < 0 or target >= _plan.points.size():
		return
	var point: RoadRoutePoint = _plan.points.pop_at(index)
	_plan.points.insert(target, point)
	refresh_points(target)


## Removes the selected point, along with its load/unload actions, and selects
## its neighbour.
func _remove_point() -> void:
	var index: int = _selected_point()
	if index >= 0:
		_plan.points.remove_at(index)
		refresh_points(mini(index, _plan.points.size() - 1))


func _selected_point() -> int:
	var selected: PackedInt32Array = _points.get_selected_items()
	return selected[0] if not selected.is_empty() else -1


## Readable name of a point. Markers show their player-given name; other kinds
## fall back to the point's own description ("Stop 12", "Depot 3", …).
func point_label(point: RoadRoutePoint) -> String:
	if point.kind == RoadRoutePoint.Kind.MARKER and _markers != null:
		var marker: RoadMarkerData = _markers.get_by_num(point.target_num)
		if marker != null:
			return "%s · marker %d" % [marker.marker_name, marker.num]
	return point.describe()


## Rebuilds the numbered list from the draft and selects `selected` if it
## exists. Always emits point_selected, so the actions tab follows every change.
func refresh_points(selected: int = 0) -> void:
	_points.clear()
	for index: int in range(_plan.points.size()):
		_points.add_item("%d. %s" % [index + 1, point_label(_plan.points[index])])
	if selected >= 0 and selected < _plan.points.size():
		_points.select(selected)
	point_selected.emit(_selected_point())


func _on_point_selected(index: int) -> void:
	point_selected.emit(index)
