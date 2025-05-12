@tool
extends Node3D
class_name Town

@export var town_name: String;
@export var pos_xz: Vector2
@export var totalPops: int

@export var structures: Array[BaseStructure] = []
@export var stations: Array[RailStation] = []

func _to_string():
	return "<Town %s>" % self.town_name
	
func add_building(_building: BaseStructure):
	self.structures.append(_building)
	_building.town = self

# == CONSTRUCTURE METHODS ==
static func of(_name: String, _pos2: Vector2, pops = null) -> Town:
	var instance: Town = Town.new()
	instance.town_name = _name
	instance.pos_xz = _pos2
	if pops && typeof(pops) == TYPE_ARRAY && pops.size() == 2:
		instance.peasantPops = pops.get(0)
		instance.bourgiePops = pops.get(1)
	return instance

static func from_json(_jsonDict: Dictionary) -> Town:
	var townPosArr = _jsonDict["pos"] as Array
	if ! townPosArr:
		push_warning("Town %s has no known position" % _jsonDict["name"])
		return null
	else:	
		var posXZ: Vector2 = Vector2(float(townPosArr[0]), float(townPosArr[1]))
		return Town.of(_jsonDict["name"], posXZ)
