class_name VehicleStartPos extends Resource

@export var track_num: int:
	get(): return track_num
	set(value):
		track_num = value
		track_obj = RailTrackData.get_by_num(value)
		
@export var track_obj: RailTrackData

@export var node_index: int

@export var dir: VehicleMotor.Direction

static func of(_track_num: int, _node_index: int, _dir: VehicleMotor.Direction) -> VehicleStartPos:
	var inst = VehicleStartPos.new()
	inst.track_num = _track_num
	inst.node_index = _node_index
	inst.dir = _dir
	return inst
