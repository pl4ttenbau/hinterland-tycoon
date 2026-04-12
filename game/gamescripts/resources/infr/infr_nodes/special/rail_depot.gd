@icon("res://assets/icons/icon_depot_white.png")
class_name RailDepotData extends GameEntityData

#region Properties
@export var depot_name: StringName

@export var track_num: int

@export var track_pos: String

@export var spawn_vehicle: bool = false

@export_storage var track: RailTrackData:
	get(): return RailTrackData.get_by_num(self.track_num)
#endregion

static var _last_num: int = 0

#region Constructor
func _init():
	super(Enums.EntityTypes.DEPOT)
	
static func of_json(_dict: Dictionary) -> RailDepotData:
	var inst = RailDepotData.new()
	inst.num = _dict.get("num")
	inst.track_num = _dict.get("trackNum")
	inst.track_pos = _dict.get("trackPos")
	# optionale Werte
	if _dict.has("name"):
		inst.depot_name = _dict.get("name")
	if _dict.has("spawnVehicle"):
		inst.spawn_vehicle = _dict.get("spawnVehicle")
	return inst
#endregion

func spawn() -> RailDepot3D:
	return RailDepot3D.of(self)

#region Getters
static func get_by_num(depot_num: int) -> RailDepotData:
	for depot: RailDepotData in GlobalState.depots:
		if depot.num == depot_num: return depot
	Loggie.warn("Cannot find Depot with num %d" % depot_num)
	return null
	
func get_depot_rail_node() -> RailNodeData:
	if self.track_pos == "START":
		return self.track.nodes[0]
	elif self.track_pos == "END":
		return self.track.get_end_node()
	return null

func get_display_letter() -> String:
	var depot_name_str: String = self.depot_name
	if self.depot_name: return depot_name_str[0].to_upper()
	return "?"

static func next_depot_num() -> int:
	RailDepotData._last_num += 1
	return RailDepotData._last_num
