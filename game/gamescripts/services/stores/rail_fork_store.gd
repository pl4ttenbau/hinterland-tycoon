class_name RailForkStore extends Resource

@export var _list: Array[RailForkData] = []
@export var _by_num: Dictionary = {}
@export var _by_track_num: Dictionary = {}
@export var _by_pos: Dictionary = {}

func add(fork_obj: RailForkData):
	self._list.append(fork_obj)
	self._by_num.set(fork_obj.num, fork_obj)
	self._by_track_num.set(fork_obj.track.num, fork_obj)
	self._by_pos.set(fork_obj.railNode.position, fork_obj)
	# add to global state as well
	GlobalState.forks.append(fork_obj)
	
#region Getting
func get_all() -> Array[RailForkData]:
	return self._list

func get_by_num(fork_num: int) -> RailForkData:
	var found: RailForkData = self._by_num.get(fork_num)
	if ! found:
		Loggie.error("Cannot find RailFork with num %d" % fork_num)
	return found
	
func get_by_pos(fork_pos: Vector3) -> RailForkData:
	return self._by_pos.get(fork_pos)
	
func get_by_track(track_num: int) -> RailForkData:
	return self._by_track_num.get(track_num)
#endregion	
