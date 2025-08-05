@icon("res://assets/icons/icon_fork_white.png")
class_name RailForkData extends GameObject

# json object properties
@export var connectiveTracks: Array
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

const SCENE_PATH = "res://assets/meshes/infr/rail/fork/rail_fork.tscn"

static func of_dict(fork_dict: Dictionary, parent: RailNodeData) -> RailForkData:
	var inst := RailForkData.new(Enums.EntityTypes.FORK)
	inst.railNode = parent
	inst.connectiveTracks = fork_dict.get("connectiveTracks") as Array
	inst.set_to = fork_dict.get("setTo", null)
	return inst

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
