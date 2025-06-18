@tool
@icon("res://assets/icons/icon_town_white.png")
class_name TownResource extends GameObject

@export var town_name: String;
@export var pos_xz: Vector2
@export var totalPops: int
@export var is_minor: bool = false

@export_storage var structures: Array[BaseStructure] = []
@export_storage var stations: Array[RailStationResource] = []

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

# == CONSTRUCTOR METHODS ==
static func of(_name: String, _pos2: Vector2, pops = null, _minor: bool = false) -> TownResource:
	var instance: TownResource = TownResource.new()
	instance.town_name = _name
	instance.pos_xz = _pos2
	instance.is_minor = _minor
	if pops && typeof(pops) == TYPE_ARRAY && pops.size() == 2:
		instance.peasantPops = pops.get(0)
		instance.bourgiePops = pops.get(1)
	return instance

static func from_json(_jsonDict: Dictionary) -> TownResource:
	var townPosArr = _jsonDict["pos"] as Array
	if ! townPosArr:
		push_warning("Town %s has no known position" % _jsonDict["name"])
		return null
	else:	
		var town_name: String = _jsonDict["name"]
		var posXZ: Vector2 = Vector2(float(townPosArr[0]), float(townPosArr[1]))
		var pops = null
		var is_minor: bool = _jsonDict.get("isMinor", false)
		return TownResource.of(town_name, posXZ, pops, is_minor)
