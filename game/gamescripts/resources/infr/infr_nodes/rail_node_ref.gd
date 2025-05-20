class_name RailNodeRef extends RefCounted

@export_storage var track_num: int
@export_storage var node_num: int

func get_ref() -> RailNode:
	var track: RailTrack = GlobalState.tracks.get(self.track_num)
	return track.get_rail_node(self.node_num)
