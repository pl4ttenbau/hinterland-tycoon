class_name RailNode extends Node

@export var parent_track: RailTrack
@export var index: int
@export var position: Vector3
@export var trackType: String
@export var specialNode: RailNodeSpecial

static func of(_index: int, _pos: Vector3, _trackType: String, _track: RailTrack) -> RailNode:
	var instance: RailNode = RailNode.new()
	instance.parent_track = _track
	instance.index = _index
	instance.position = _pos
	instance.trackType = _trackType
	return instance

func parse_and_add_special(rail_node_dict: Dictionary):
	if rail_node_dict.has("special"):
		var json_special: Dictionary = rail_node_dict.get("special")
		self.specialNode = RailNodeSpecial.of(json_special.nodeType)
		if !json_special:
			return
		if json_special.nodeType == "STATION":
			Loggie.info("station found")
			add_station(json_special)
		elif json_special.nodeType == "SWITCH":
			add_fork(json_special)
	
func add_station(_special_node_dict: Dictionary):
	var station_obj = RailStation.of_node_dict(_special_node_dict, self)
	self.set_meta("station", station_obj)
	GlobalState.stations.append(station_obj)
	
func add_fork(_special_node_dict: Dictionary):
	var connected_tracks: Array = _special_node_dict.get("connectiveTracks")
	var fork_obj = RailFork.of(self, connected_tracks)
	self.set_meta("fork", fork_obj)
	GlobalState.forks.append(fork_obj)
	
	GlobalState
