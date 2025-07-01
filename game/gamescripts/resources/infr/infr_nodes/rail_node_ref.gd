class_name RailNodeRef extends RefCounted

@export_storage var track_num: int
@export_storage var node_num: int

func _init(_track_num: int, _node_num: int):
	self.track_num = _track_num
	self.node_num = _node_num

func get_ref() -> RailNodeData:
	var track: RailTrackData = GlobalState.tracks.get(self.track_num)
	return track.get_rail_node(self.node_num)
