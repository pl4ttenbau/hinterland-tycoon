@icon("res://assets/icons/icon_depot_white.png")
class_name RailDepotData extends GameObject

@export var track_num: int
@export var track_pos: String
@export var spawn_vehicle: bool = false

static var _last_num: int = 0

func _init():
	super(Enums.EntityTypes.DEPOT)
	
static func of_json(_dict: Dictionary) -> RailDepotData:
	var inst = RailDepotData.new()
	inst.num = _dict.get("num")
	inst.track_num = _dict.get("trackNum")
	inst.track_pos = _dict.get("trackPos")
	if _dict.has("spawnVehicle"):
		inst.spawn_vehicle = _dict.get("spawnVehicle")
	return inst
	
func spawn() -> OuterDepot:
	return OuterDepot.of(self)

static func next_depot_num() -> int:
	RailDepotData._last_num += 1
	return RailDepotData._last_num
	
static func get_track_by_num(_track_num: int) -> RailTrackData:
	return GlobalState.tracks[_track_num -1]
