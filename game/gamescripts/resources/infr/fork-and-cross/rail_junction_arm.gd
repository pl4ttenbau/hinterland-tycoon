## One arm of a junction: a track endpoint that belongs to the physical switch `junction`.
## The switch setting lives only on the junction (RailJunctionData); arms hold no setting state.
@icon("res://assets/icons/icon_fork_white.png")
class_name RailJunctionArm extends GameEntityData

static var _last_fork_num = -1

## Other tracks meeting at this junction, as loaded from the map and kept up to date on erasure.
@export var connective_tracks: Array[int] = []

## is a nonemovable fork connection
## in a "fork" with only 2 connected nodes, all connections are static
@export var static_track: bool = false

# later-set properties
@export var railNode: RailNodeData

## The physical junction this leg belongs to; set when the fork loader connects the leg.
## Not exported: the junction already lists its legs, and saving both directions would form a cycle.
var junction: RailJunctionData

@export var position: Vector3:
	get(): return railNode.position

@export_storage var container: RailJunction3D

@export_storage var track: RailTrackData:
	get(): return self.railNode.parent_line
	set(value): pass

#region Initialization
func _init():
	super(Enums.EntityTypes.FORK)
	self.num = RailJunctionArm._next_fork_num()

static func _next_fork_num() -> int:
	RailJunctionArm._last_fork_num += 1
	return RailJunctionArm._last_fork_num
#endregion
