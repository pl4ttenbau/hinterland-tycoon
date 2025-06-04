@tool
class_name TownResource extends GameObject

@export var town_name: String;
@export var pos_xz: Vector2
@export var totalPops: int

@export_storage var structures: Array[BaseStructure] = []
@export_storage var stations: Array[RailStationResource] = []

func _to_string():
	return "<Town %s>" % self.town_name
	
func add_building(_building: BaseStructure):
	self.structures.append(_building)
	_building.town = self
	
func _init():
	super(Enums.EntityTypes.TOWN)

# == CONSTRUCTOR METHODS ==
static func of(_name: String, _pos2: Vector2, pops = null) -> TownResource:
	var instance: TownResource = TownResource.new()
	instance.town_name = _name
	instance.pos_xz = _pos2
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
		var posXZ: Vector2 = Vector2(float(townPosArr[0]), float(townPosArr[1]))
		return TownResource.of(_jsonDict["name"], posXZ)
