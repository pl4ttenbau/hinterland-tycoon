@icon("res://assets/icons/icon_fork_white.png")
class_name RailForkData extends GameObject

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

# later-set properties
@export var railNode: RailNodeData
@export_storage var container: OuterRailFork

@export_storage var track: RailTrackData:
	get(): return self.railNode.parent_track
	set(value): pass
	
signal set_to_changed(track_num: int)

func _init():
	super(Enums.EntityTypes.FORK)
	self.num = RailForkData._next_fork_num()

static func of_dict(fork_dict: Dictionary, parent: RailNodeData) -> RailForkData:
	var inst := RailForkData.new()
	inst.railNode = parent
	# connective tracks
	inst.all_connective_tracks.append(parent.parent_track.num)
	var _connective_tracks = fork_dict.get("connectiveTracks") as Array
	for connective_track in _connective_tracks:
		inst.connective_tracks.append(int(connective_track))
		inst.all_connective_tracks.append(int(connective_track))
	# set to
	inst.set_to = fork_dict.get("setTo", null)
	return inst
	
static func get_by_num(fork_num: int) -> RailForkData:
	for rail_fork in Managers.rails.forks:
		if rail_fork.num == fork_num: return rail_fork
	return null

func spawn() -> OuterRailFork:
	var instanciated: OuterRailFork = preload(SCENE_PATH).instantiate()
	instanciated.entity = self
	# set pos
	instanciated.position = self.railNode.position
	self.container = instanciated
	# add as rail container child
	self.get_outer_track().add_child(instanciated)
	return instanciated
	
func get_outer_track() -> OuterRailTrack:
	var rail_num := self.track.num
	return GlobalState.outer_tracks.get(rail_num -1)
	
func set_to_next_track():
	var current_index: int = self.all_connective_tracks.find(self.set_to)
	var future_index = current_index + 1
	if future_index == self.all_connective_tracks.size():
		future_index = 0
	self.set_to = self.all_connective_tracks[future_index]
	
static func _next_fork_num() -> int:
	RailForkData._last_fork_num += 1
	return RailForkData._last_fork_num
