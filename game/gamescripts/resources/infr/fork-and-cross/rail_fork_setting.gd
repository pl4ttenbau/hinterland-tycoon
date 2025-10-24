class_name RailForkSetting extends Resource

@export var parent: NewRailForkData

@export var connected_tracks: Array[int] = []

@export var main_set_to: int

@export var all_set_to: Array[int] = []
func _init(_parent: NewRailForkData):
	self.parent = _parent

func add_connected(track_num: int):
	self.connected_tracks.append(track_num)
	self._find_main_set_to(track_num)

func _find_main_set_to(added_track_num: int):
	if self.connected_tracks.count(added_track_num) >= 2:
		self.main_set_to = added_track_num
