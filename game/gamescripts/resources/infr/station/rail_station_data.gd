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

## The track the platform stands on, and where on it (node + offset, see TrackAnchor).
## Since 2026-11-23 the stop itself holds its place; rail nodes no longer know about stops (the former
## NodeStationLinkData between node and stop was a strong two-way link that leaked at shutdown).
@export var track_num: int = -1
@export var anchor: TrackAnchor = TrackAnchor.new()

## The platform in the scene (rail_node_station_3d.tscn), set when it is spawned. A scene node, so not
## reference-counted: no cycle with the view, which holds this stop as its entity.
var platform_view: NodeStationLink3D

#region Initialization
func _init(_num: int = -1, _name: String = "", _town_num: int = -1):
	super()
	self.num = _num
	self.station_name = _name
	self.town_num = _town_num

static func of_dict(_station_data: Dictionary) -> RailStationData:
	for field: String in ["num", "trackNum"]:
		if not InterchangeData.is_valid_num(_station_data.get(field)):
			push_error("Rail stop requires a nonnegative integer %s" % field)
			return null
	var place: TrackAnchor = TrackAnchor.from_dict(_station_data)
	if place == null:
		push_error("Rail stop requires a nonnegative integer nodeIndex and an optional numeric nodeOffset")
		return null
	if not _station_data.get("type", "STATION_PASS") is String \
			or not _station_data.get("hideBuilding", false) is bool:
		push_error("Rail stop type/hideBuilding metadata is invalid")
		return null
	# Name and town are inherited from the interchange after registration.
	var station_obj := RailStationData.new(int(_station_data["num"]))
	station_obj.track_num = int(_station_data["trackNum"])
	station_obj.anchor = place
	station_obj.station_type = _station_data.get("type", "STATION_PASS")
	station_obj.hide_building = _station_data.get("hideBuilding", false)
	return station_obj
#endregion

static func get_by_num(station_num: int) -> RailStationData:
	var found = Managers.stations.stations_by_num.get(station_num)
	if ! found: Loggie.error("Cannot find RailStation with num %d" % station_num)
	return found
