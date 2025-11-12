@icon("res://assets/icons/icon_station_white.png")
class_name RailNodeStationData extends GameObject

#region Generated Properties
@export var parent_node: RailNodeData

@export var station_num: int

@export var position: Vector3

@export var parent_station: RailStationData

@export var track_num: int:
	set(value): pass
	get(): return self.parent_node.parent_track.num
#endregion

static var _last_station_num: int = 0

func _init():
	super(Enums.EntityTypes.NODE_STATION)

static func of(_rail_node: RailNodeData, _station_num: int) -> RailNodeStationData:
	var instance := RailNodeStationData.new()
	instance.station_num = _station_num
	instance.position = _rail_node.position
	instance.parent_node = _rail_node
	return instance
	
func spawn() -> OuterRailStation:
	self.outer_node = OuterRailStation.of(self)
	return self.outer_node

#region Connections
func connect_house(outer_res_bld: OuterResBld):
	self.connections.connect_house(outer_res_bld)
	
func connect_industry(industry: IndustryData):
	self.connections.connect_industry(industry)
#endregion

#region Helper Methods
static func of_station_dict(_station_dict: Dictionary, _node: RailNodeData) -> RailNodeStationData:
	var station_obj := RailNodeStationData.of(_node, _station_dict.get("num"))
	# set optional values
	if _station_dict.has("hideBuilding"):
		station_obj.hide_building = _station_dict.get("hideBuilding", false)
	return station_obj

static func next_station_num() -> int:
	RailNodeStationData._last_station_num += 1
	return RailNodeStationData._last_station_num
	
func _to_string() -> String:
	return "Station-%s@%s" % [self.station_name, self.town_name]
#endregion
