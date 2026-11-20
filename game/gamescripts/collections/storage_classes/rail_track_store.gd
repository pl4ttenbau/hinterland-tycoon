@icon("res://assets/icons/icon_rail_track_white.png")
class_name RailTrackStore extends AbstractTrackStore

var SAVE_PATH_FORMAT = "res://world/%s/reslists/rail_tracks.dat"

@export var _list: Array[RailTrackData] = []
@export_storage var _containers: Array[RailTrack3D] = []

func _tracks() -> Array:
	return self._list

func _views() -> Array:
	return self._containers

func _kind_name() -> String:
	return "track"

func _on_view_removed(view: InfrLine3D) -> void:
	GlobalState.outer_tracks.erase(view)

#region Get Rail Tracks
func get_all() -> Array[RailTrackData]:
	return self._list

func get_containers() -> Array[RailTrack3D]:
	return self._containers
#endregion
