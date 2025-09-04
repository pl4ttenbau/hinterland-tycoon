@icon("res://assets/icons/icon_rail_track_white.png")
class_name RailTrackStore extends Resource

var SAVE_PATH_FORMAT = "res://world/%s/reslists/rail_tracks.dat"

@export var _list: Array[RailTrackData] = []
@export var _by_id: Dictionary = {}

signal track_added(track_obj: RailTrackData)
	
func _enter_tree() -> void:
	self.track_added.connect(Callable(self, "_on_track_loaded"))

#region Add City
func add(track_obj: RailTrackData):
	self._list.append(track_obj)
	self._create_indexes(track_obj)
	self.track_added.emit(track_obj)
	
func _create_indexes(track_obj: RailTrackData):
	self._by_id.set(track_obj.num, track_obj)
#endregion

#region Get City
func get_all() -> Array[RailTrackData]:
	return self._list

func get_by_num(track_num: int) -> RailTrackData:
	var found: RailTrackData =  self._by_id.get(track_num)
	if ! found: Loggie.error("Cannot get track %d; out of index?" % track_num)
	return found
	
func get_by_name(track_name: StringName) -> RailTrackData:
	return self._by_name.get(track_name)
#endregion

#region Callbacks & Helpers 
func _on_track_loaded(track_obj: RailTrackData):
	GlobalState.tracks.append(track_obj)
#endregion
