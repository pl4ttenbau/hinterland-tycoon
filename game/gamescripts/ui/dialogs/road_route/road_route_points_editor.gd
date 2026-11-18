## Edits route visits in the dialog's draft and reports the selected visit.
class_name RoadRoutePointsEditor extends VBoxContainer

signal point_selected(index: int)
signal status_changed(message: String)

var _plan: RoadRoutePlan
var _markers: RoadMarkerStore
var _stops: Dictionary
var _depots: Array[RoadDepotData]
var _target_ids: Array[int] = []

@onready var _points: ItemList = %Points
@onready var _kind: OptionButton = %PointKind
@onready var _targets: OptionButton = %Targets


func edit(plan: RoadRoutePlan, markers: RoadMarkerStore, stops: Dictionary,
		depots: Array[RoadDepotData]) -> void:
	_plan = plan
	_markers = markers
	_stops = stops
	_depots = depots
	_targets.get_popup().allow_search = true
	_fill_point_choices(0)
	refresh_points()


func _fill_point_choices(_selection: int) -> void:
	_targets.clear()
	_target_ids.clear()
	match _kind.get_selected_id():
		RoadRoutePoint.Kind.MARKER:
			if _markers != null:
				for marker: RoadMarkerData in _markers.markers:
					_offer_target(marker.num, "%s · %d" % [marker.marker_name, marker.num])
			if _target_ids.is_empty():
				status_changed.emit("No markers yet. On foot, choose Place road marker in the circular menu while standing on a road.")
		RoadRoutePoint.Kind.STOP:
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


func _add_point() -> void:
	if _targets.selected < 0:
		return
	var point := RoadRoutePoint.new()
	point.kind = _kind.get_selected_id() as RoadRoutePoint.Kind
	point.target_num = _target_ids[_targets.selected]
	_plan.points.append(point)
	refresh_points(_plan.points.size() - 1)


func _move_point(direction: int) -> void:
	var index: int = _selected_point()
	var target: int = index + direction
	if index < 0 or target < 0 or target >= _plan.points.size():
		return
	var point: RoadRoutePoint = _plan.points.pop_at(index)
	_plan.points.insert(target, point)
	refresh_points(target)


func _remove_point() -> void:
	var index: int = _selected_point()
	if index >= 0:
		_plan.points.remove_at(index)
		refresh_points(mini(index, _plan.points.size() - 1))


func _selected_point() -> int:
	var selected: PackedInt32Array = _points.get_selected_items()
	return selected[0] if not selected.is_empty() else -1


func point_label(point: RoadRoutePoint) -> String:
	if point.kind == RoadRoutePoint.Kind.MARKER and _markers != null:
		var marker: RoadMarkerData = _markers.get_by_num(point.target_num)
		if marker != null:
			return "%s · marker %d" % [marker.marker_name, marker.num]
	return point.describe()


func refresh_points(selected: int = 0) -> void:
	_points.clear()
	for index: int in range(_plan.points.size()):
		_points.add_item("%d. %s" % [index + 1, point_label(_plan.points[index])])
	if selected >= 0 and selected < _plan.points.size():
		_points.select(selected)
	point_selected.emit(_selected_point())


func _on_point_selected(index: int) -> void:
	point_selected.emit(index)
