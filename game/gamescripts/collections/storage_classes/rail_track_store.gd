@icon("res://assets/icons/icon_rail_track_white.png")
class_name RailTrackStore extends Resource

var SAVE_PATH_FORMAT = "res://world/%s/reslists/rail_tracks.dat"

@export var _list: Array[RailTrackData] = []
@export var _by_id: Dictionary = {}
@export var _max_num: int = -1

@export_storage var _containers: Array[RailTrack3D] = []
@export_storage var _containers_by_id: Dictionary = {}

signal track_added(track_obj: RailTrackData)
	
#region Add Track
func add(track_obj: RailTrackData):
	self._list.append(track_obj)
	self._create_indexes(track_obj)
	if track_obj.num > self._max_num:
		self._max_num = track_obj.num
	self.track_added.emit(track_obj)
	
func add_container(outer_track: RailTrack3D):
	self._containers.append(outer_track)
	self._containers_by_id.set(outer_track.track.num, outer_track)
	
func _create_indexes(track_obj: RailTrackData):
	self._by_id.set(track_obj.num, track_obj)
#endregion

## Remove the indexes and detach the view immediately so it stops colliding.
func remove(track: RailTrackData) -> void:
	if _by_id.get(track.num) != track:
		return
	_list.erase(track)
	_by_id.erase(track.num)
	var view: RailTrack3D = _containers_by_id.get(track.num)
	_containers_by_id.erase(track.num)
	if is_instance_valid(view):
		_containers.erase(view)
		GlobalState.outer_tracks.erase(view)
		if view.get_parent() != null:
			view.get_parent().remove_child(view)
		view.queue_free()


#region Get Rail Tracks
func get_all() -> Array[RailTrackData]:
	return self._list

func get_by_num(track_num: int) -> RailTrackData:
	var found: RailTrackData =  self._by_id.get(track_num)
	if ! found: Loggie.error("Cannot get track %d; out of index?" % track_num)
	return found
	
func get_container_by_num(track_num: int) -> RailTrack3D:
	var found: RailTrack3D = self._containers_by_id.get(track_num, null)
	if ! found: Loggie.error("Cannot get RailTrack3D %d; out of index?" % track_num)
	return found
#endregion
