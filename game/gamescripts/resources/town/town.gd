@tool
@icon("res://assets/icons/icon_town_white.png")
class_name TownData extends GameObject

const BUIDLING_BLOCKAGE_RADIUS = 20.0

@export var town_name: String
@export var pos_xz: Vector2
@export var totalPops: int
@export var is_minor: bool = false
@export_storage var res_buildings: Array[OuterResBld] = []
@export_storage var stations: Array[RailStationData] = []

func _init():
	super(Enums.EntityTypes.TOWN)

func _to_string():
	return "<Town %s>" % self.town_name
	
func get_initial_bld_count() -> int:
	if self.is_minor: return 3
	else: return 5
	
func add_building(_building: BaseStructure):
	self.structures.append(_building)
	_building.town = self

#region Constructors
static func of(_name: String, _pos2: Vector2, pops = null, _minor: bool = false) -> TownData:
	var instance := TownData.new()
	instance.town_name = _name
	instance.pos_xz = _pos2
	instance.is_minor = _minor
	if pops && typeof(pops) == TYPE_ARRAY && pops.size() == 2:
		instance.peasantPops = pops.get(0)
		instance.bourgiePops = pops.get(1)
	return instance

static func from_json(_jsonDict: Dictionary) -> TownData:
	var townPosArr = _jsonDict["pos"] as Array
	if ! townPosArr:
		push_warning("Town %s has no known position" % _jsonDict["name"])
		return null
	else:	
		var town_name: String = _jsonDict["name"]
		var posXZ: Vector2 = Vector2(float(townPosArr[0]), float(townPosArr[1]))
		var pops = null
		var is_minor: bool = _jsonDict.get("isMinor", false)
		return TownData.of(town_name, posXZ, pops, is_minor)
#endregion

func add_res_bld(outer_res_bld: OuterResBld):
	self.res_buildings.append(outer_res_bld)
	GlobalState.res_bld_containers.append(outer_res_bld)
	
func has_bld_around(check_pos: Vector3) -> bool:
	for outer_res_bld: OuterResBld in self.res_buildings:
		var dist_to := outer_res_bld.position.distance_to(check_pos)
		if dist_to <= BUIDLING_BLOCKAGE_RADIUS: 
			return true
	# Loggie.warn("Pos %v blocked by building in town %s" % [check_pos, self.town_name])
	return false
