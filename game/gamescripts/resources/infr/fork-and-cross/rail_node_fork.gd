@icon("res://assets/icons/icon_fork_white.png")
class_name RailNodeForkData extends GameEntityData

static var _last_fork_num = -1

# json object properties
@export var connective_tracks: Array[int] = []

## is a nonemovable fork connection
## in a "fork" with only 2 connected nodes, all connections are static
@export var static_track: bool = false

# generated later
@export var all_connective_tracks: Array[int] = []

@export var set_to: int:
	get(): return set_to
	set(value): 
		set_to = value
		self.set_to_changed.emit(value)
		SignalBus.fork_changed.emit(self)

# later-set properties
@export var railNode: RailNodeData

@export var position: Vector3:
	get(): return railNode.position

@export_storage var container: RailFork3D

@export_storage var track: RailTrackData:
	get(): return self.railNode.parent_track
	set(value): pass

signal set_to_changed(track_num: int)

func _init():
	super(Enums.EntityTypes.FORK)
	self.num = RailNodeForkData._next_fork_num()

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
