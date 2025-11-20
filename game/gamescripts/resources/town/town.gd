@tool
@icon("res://assets/icons/icon_town_white.png")
class_name TownData extends GameObject

const BUIDLING_BLOCKAGE_RADIUS = 20.0

signal town_name_changed(new_name: String)

#region Properties
@export var town_name: String:
	set(value):
		town_name = value
		self.town_name_changed.emit(value)
	get():
		return town_name

@export var pos_xz: Vector2
@export var is_minor: bool = false

@export var autogenerate_houses: bool = true
@export_storage var totalPops: int
@export_storage var res_bld_containers: Array[OuterResBld] = []

@export_storage var stations: Array[RailNodeStationData] = []
@export_storage var station_blds_assigned: bool = false
#endregion

static var last_town_num: int = 0

func _init():
	super(Enums.EntityTypes.TOWN)
	# assign town num
	self.num = TownData.last_town_num
	TownData.last_town_num += 1

#region Constructors
static func of(_name: String, _pos2: Vector2, pops = null, _minor: bool = false,
		_autogenerate_houses: bool = false) -> TownData:
	var instance := TownData.new()
	instance.town_name = _name
	instance.pos_xz = _pos2
	instance.is_minor = _minor
	instance.autogenerate_houses = _autogenerate_houses
	if pops && typeof(pops) == TYPE_ARRAY && pops.size() == 2:
		instance.peasantPops = pops.get(0)
		instance.bourgiePops = pops.get(1)
	return instance
#endregion

#region Buildings
func add_building(_building: BaseStructure):
	self.structures.append(_building)
	_building.town = self
	
func add_res_bld(outer_res_bld: OuterResBld):
	self.res_bld_containers.append(outer_res_bld)
	GlobalState.res_bld_containers.append(outer_res_bld)
	
func has_bld_around(check_pos: Vector3) -> bool:
	for outer_res_bld: OuterResBld in self.res_bld_containers:
		var dist_to := outer_res_bld.position.distance_to(check_pos)
		if dist_to <= BUIDLING_BLOCKAGE_RADIUS: 
			return true
	# Loggie.warn("Pos %v blocked by building in town %s" % [check_pos, self.town_name])
	return false
#endregion

#region Stations
func connect_new_station(station: AbstractStation):
	self.stations.append(station)
	self.reassign_buildings_to_stations()
	
func reassign_buildings_to_stations():
	for res_bld_container: OuterResBld in self.res_bld_containers:
		var closest_station_obj := self.find_closest_station_to_bld(res_bld_container)
		self.station_blds_assigned = true
		if closest_station_obj:
			res_bld_container.res_bld.connected_station = closest_station_obj
			
func find_closest_station_to_bld(res_bld: OuterResBld) -> RailNodeStationData:
	var closest_station_obj: RailNodeStationData
	var closest_station_distance: float = 9999
	for station: RailNodeStationData in self.stations:
		var dist = res_bld.global_position.distance_to(station.position)
		if dist < closest_station_distance:
			closest_station_distance = dist
			closest_station_obj = station
	return closest_station_obj
#endregion

#region Helper-Methods
func _to_string():
	return "<Town %s>" % self.town_name
	
static func get_town_by_num(_num: int) -> TownData:
	var found: TownData = Managers.towns.storage.get_by_num(_num)
	if !found: Loggie.error("Cannot get town with num %d" % _num)
	return found
	
func get_initial_bld_count() -> int:
	if self.is_minor: return 3
	else: return 5
#endregion
