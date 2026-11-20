class_name RailJunctionArmStore extends Resource

@export var _list: Array[RailJunctionArm] = []
@export var _by_num: Dictionary = {}
@export var _by_track_num: Dictionary = {}

func add(fork_obj: RailJunctionArm):
	self._list.append(fork_obj)
	self._by_num.set(fork_obj.num, fork_obj)
	self._by_track_num.set(fork_obj.track.num, fork_obj)
	# add to global state as well
	GlobalState.forks.append(fork_obj)
	
#region Getting
func get_all() -> Array[RailJunctionArm]:
	return self._list

func get_by_num(fork_num: int) -> RailJunctionArm:
	var found: RailJunctionArm = self._by_num.get(fork_num)
	if ! found:
		Loggie.error("Cannot find RailFork with num %d" % fork_num)
	return found
	
func get_by_track(track_num: int) -> RailJunctionArm:
	return self._by_track_num.get(track_num)
#endregion	


func remove(fork: RailJunctionArm) -> void:
	_list.erase(fork)
	GlobalState.forks.erase(fork)


## A surviving endpoint may now belong to a new fragment.
func rebuild_indexes() -> void:
	_by_num.clear()
	_by_track_num.clear()
	for fork: RailJunctionArm in _list:
		_by_num[fork.num] = fork
		_by_track_num[fork.track.num] = fork
