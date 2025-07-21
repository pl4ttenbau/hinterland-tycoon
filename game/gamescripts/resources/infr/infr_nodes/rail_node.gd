class_name RailNodeData extends BasicInfrNodeData

@export_storage var parent_track: RailTrackData
@export_storage var fork: RailForkData
@export_storage var station: RailStationData

static func of(_index: int, _pos: Vector3, _trackType: String, _track: RailTrackData) -> RailNodeData:
	var instance := RailNodeData.new()
	instance.parent_track = _track
	instance.index = _index
	instance.position = _pos
	instance.trackType = _trackType
	return instance

func parse_and_add_special(rail_node_dict: Dictionary):
	if rail_node_dict.has("fork"):
		var fork_dict: Dictionary = rail_node_dict.get("fork")
		self.add_fork(RailForkData.of_dict(fork_dict, self))
	if rail_node_dict.has("station"):
		var station_dict: Dictionary = rail_node_dict.get("station")
		self.add_station(RailStationData.of_station_dict(station_dict, self))
	
func add_station(_station: RailStationData):
	self.station = _station
	# add to track & global station list
	self.parent_track.stations.append(_station)
	GlobalState.stations.append(_station)
	
func add_fork(_fork: RailForkData):
	self.fork = _fork
	# add to track & global array
	self.parent_track.add_fork(_fork)
	GlobalState.forks.append(_fork)
	
func as_ref() -> RailNodeRef:
	var track_num: int = self.parent_track.num
	return RailNodeRef.new(track_num, self.index)
	
func get_previous() -> RailNodeData:
	if self.index >= 0:
		return self.parent_track.get_rail_node(self.index -1)
	return null
	
func get_next() -> RailNodeData:
	var next_index := self.index +1
	if self.parent_track.has_node_index(next_index):
		return self.parent_track.get_rail_node(next_index)
	return null
	
func is_first() -> bool:
	return self.index == 0
	
func is_last() -> bool:
	return self.index == (self.parent_track.nodes.size() -1)
