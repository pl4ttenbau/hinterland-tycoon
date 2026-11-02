@icon("res://assets/icons/icon_depot_white.png")
class_name RoadDepotData extends GameEntityData

#region Properties
@export var depot_name: StringName

@export var road_num: int

@export var road_pos: String

@export var spawn_vehicle: bool = false

@export_storage var road: RoadData:
	get(): return RoadData.get_by_num(self.road_num)
#endregion

static var _last_num: int = 0

#region Constructor
func _init():
	super(Enums.EntityTypes.ROAD_DEPOT)
	
static func of_json(_dict: Dictionary) -> RoadDepotData:
	var inst = RoadDepotData.new()
	inst.num = _dict.get("num")
	inst.road_num = _dict.get("roadNum")
	inst.road_pos = _dict.get("roadPos")
	# optionale Werte
	if _dict.has("name"):
		inst.depot_name = _dict.get("name")
	if _dict.has("spawnVehicle"):
		inst.spawn_vehicle = _dict.get("spawnVehicle")
	return inst
#endregion

func spawn() -> RoadDepot3D:
	return RoadDepot3D.of(self)

#region Getters
static func get_by_num(depot_num: int) -> RoadDepotData:
	for depot: RoadDepotData in GlobalState.road_depots:
		if depot.num == depot_num: return depot
	Loggie.warn("Cannot find Depot with num %d" % depot_num)
	return null
	
func get_depot_road_node() -> RoadNode:
	if road == null or road.nodes.is_empty():
		return null
	if self.road_pos == "START":
		return self.road.nodes[0]
	elif self.road_pos == "END":
		return self.road.nodes[-1]
	return null

func get_display_letter() -> String:
	var depot_name_str: String = self.depot_name
	if self.depot_name: return depot_name_str[0].to_upper()
	return "?"

static func next_depot_num() -> int:
	RoadDepotData._last_num += 1
	return RoadDepotData._last_num
