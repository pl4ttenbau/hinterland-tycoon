@icon("res://assets/icons/icon_station_white.png")
class_name RailStationData extends AbstractStation

## Looking from the track start toward its end.
enum PlatformSide { RIGHT, LEFT }

@export var platform_side: PlatformSide = PlatformSide.RIGHT

## World position of the platform, resolved from track_num + anchor when the stop is registered.
@export var position: Vector3:
	get(): return position
	set(value):
		position = value
		self.positioned.emit(value)

## The track the platform stands on, and where on it (node + offset, see LineAnchor).
## Since 2026-11-23 the stop itself holds its place; rail nodes no longer know about stops (the former
## NodeStationLinkData between node and stop was a strong two-way link that leaked at shutdown).
@export var track_num: int = -1
@export var anchor: LineAnchor = LineAnchor.new()

## The platform in the scene (rail_stop_3d.tscn), set when it is spawned. A scene node, so not
## reference-counted: no cycle with the view, which holds this stop as its entity.
var platform_view: RailStop3D

#region Initialization
func _init(_num: int = -1, _name: String = "", _town_num: int = -1):
	super()
	self.num = _num
	self.station_name = _name
	self.town_num = _town_num
#endregion

static func get_by_num(station_num: int) -> RailStationData:
	var found = Managers.stations.stations_by_num.get(station_num)
	if ! found: Loggie.error("Cannot find RailStation with num %d" % station_num)
	return found
