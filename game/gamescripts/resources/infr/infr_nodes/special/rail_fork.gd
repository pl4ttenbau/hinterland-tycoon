class_name RailFork extends GameObject

@export_storage var container: OuterRailFork
@export var connectiveTracks: Array
@export var railNode: RailNode
@export var setTo: int

const SCENE_PATH = "res://assets/meshes/infr/rail/fork/rail_fork.tscn"

static func of_dict(fork_dict: Dictionary, parent: RailNode) -> RailFork:
	var inst: RailFork = RailFork.new(Enums.EntityTypes.FORK)
	inst.railNode = parent
	inst.connectiveTracks = fork_dict.get("connectiveTracks") as Array
	inst.setTo = fork_dict.get("setTo", null)
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
	
func get_track() -> RailTrack:
	return self.railNode.parent_track
	
func get_outer_track() -> OuterRailTrack:
	var rail_num := self.get_track().num
	return GlobalState.outer_tracks.get(rail_num -1)
