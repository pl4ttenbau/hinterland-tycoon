@icon("res://assets/icons/icon_depot_white.png")
class_name RailDepotData extends GameObject

@export var depot_name: StringName
@export var track_num: int
@export var track_pos: String
@export var spawn_vehicle: bool = false

@export_storage var track: RailTrackData:
	get(): return RailTrackData.get_by_num(self.track_num)

static var _last_num: int = 0

func _init():
	super(Enums.EntityTypes.DEPOT)
	
static func of_json(_dict: Dictionary) -> RailDepotData:
	var inst = RailDepotData.new()
	inst.num = _dict.get("num")
	inst.track_num = _dict.get("trackNum")
	inst.track_pos = _dict.get("trackPos")
	# optionale Werte
	if _dict.has("name"):
		inst.name = _dict.get("name")
	if _dict.has("spawnVehicle"):
		inst.spawn_vehicle = _dict.get("spawnVehicle")
	return inst
	
func spawn() -> OuterDepot:
	return OuterDepot.of(self)
	
func get_depot_rail_node() -> RailNodeData:
	if self.track_pos == "START":
		return self.track.nodes[0]
	elif self.track_pos == "END":
		return self.track.get_end_node()
	return null

static func next_depot_num() -> int:
	RailDepotData._last_num += 1
	return RailDepotData._last_num
