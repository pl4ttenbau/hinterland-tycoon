@icon("res://assets/icons/icon_connect_white.png")
class_name NodeStationLinkData extends GameEntityData

#region Generated Properties
@export var parent_node: RailNodeData

@export var position: Vector3

@export var track_num: int:
	set(value): pass
	get(): return self.parent_node.parent_track.num
	
@export var hide_building: bool = false

@export_storage var station3d: NodeStationLink3D

@export_category("Parent Station")
@export var parent_station_num: int
@export var parent_station: RailStationData
#endregion

static var _last_station_num: int = 0

func _init():
	super(Enums.EntityTypes.NODE_STATION)
	self.num = NodeStationLinkData.next_station_num()

static func of(_rail_node: RailNodeData, _station_num: int) -> NodeStationLinkData:
	var instance := NodeStationLinkData.new()
	instance.parent_station_num = _station_num
	instance.position = _rail_node.position
	instance.parent_node = _rail_node
	return instance
	
func spawn() -> NodeStationLink3D:
	self.station3d = NodeStationLink3D.of(self)
	return self.station3d

#region Connections
func connect_house(outer_res_bld: Residence3D):
	self.connections.connect_house(outer_res_bld)
	
func connect_industry(industry: IndustryData):
	self.connections.connect_industry(industry)
#endregion

#region Find By Distance
static func find_closest_station_to_bld(res_bld: Residence3D) -> NodeStationLinkData:
	var closest_node_station: NodeStationLinkData
	var closest_station_distance: float = 9999
	for station: RailStationData in GlobalState.station_objs:
		for node_station: NodeStationLinkData in station.node_stations:
			var dist = res_bld.global_position.distance_to(node_station.position)
			if dist <= 200 && dist < closest_station_distance:
				closest_station_distance = dist
				closest_node_station = node_station
	return closest_node_station
#endregion

#region Helper Methods
static func of_station_dict(_station_dict: Dictionary, _node: RailNodeData) -> NodeStationLinkData:
	var station_obj := NodeStationLinkData.of(_node, _station_dict.get("num"))
	# set optional values
	if _station_dict.has("hideBuilding"):
		station_obj.hide_building = _station_dict.get("hideBuilding", false)
	return station_obj

static func next_station_num() -> int:
	NodeStationLinkData._last_station_num += 1
	return NodeStationLinkData._last_station_num
	
func _to_string() -> String:
	return "Station-%s@%s" % [self.station_name, self.town_name]
#endregion
