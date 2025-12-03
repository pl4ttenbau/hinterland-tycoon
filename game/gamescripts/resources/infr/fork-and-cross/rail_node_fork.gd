@icon("res://assets/icons/icon_fork_white.png")
class_name RailNodeForkData extends GameObject

const SCENE_PATH = "res://assets/meshes/infr/rail/fork/rail_fork.tscn"
static var _last_fork_num = -1

# json object properties
@export var connective_tracks: Array[int] = []

@export var all_connective_tracks: Array[int] = []

@export var set_to: int:
	get(): return set_to
	set(value): 
		set_to = value
		self.set_to_changed.emit(value)
		SignalBus.fork_changed.emit(self)

# later-set properties
@export var railNode: RailNodeData

@export_storage var container: RailFork3D

@export_storage var track: RailTrackData:
	get(): return self.railNode.parent_track
	set(value): pass
	
signal set_to_changed(track_num: int)

func _init():
	super(Enums.EntityTypes.FORK)
	self.num = RailNodeForkData._next_fork_num()

static func of_dict(fork_dict: Dictionary, parent: RailNodeData) -> RailNodeForkData:
	var inst := RailNodeForkData.new()
	inst.railNode = parent
	# connective tracks
	inst.all_connective_tracks.append(parent.parent_track.num)
	var _connective_tracks = fork_dict.get("connectiveTracks") as Array
	for connective_track in _connective_tracks:
		inst.connective_tracks.append(int(connective_track))
		inst.all_connective_tracks.append(int(connective_track))
	# set to
	inst.set_to = fork_dict.get("setTo", null)
	# register in fork store
	Managers.rails.fork_storage.add(inst)
	return inst
	
static func get_by_num(fork_num: int) -> RailNodeForkData:
	return Managers.rails.fork_storage.get_by_num(fork_num)
	
func set_to_next_track():
	var current_index: int = self.all_connective_tracks.find(self.set_to)
	var future_index = current_index + 1
	if future_index == self.all_connective_tracks.size():
		future_index = 0
	self.set_to = self.all_connective_tracks[future_index]
	
static func _next_fork_num() -> int:
	RailNodeForkData._last_fork_num += 1
	return RailNodeForkData._last_fork_num
