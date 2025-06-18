class_name RailNode extends BasicInfrNode

@export_storage var parent_track: RailTrack

static func of(_index: int, _pos: Vector3, _trackType: String, _track: RailTrack) -> RailNode:
	var instance: RailNode = RailNode.new()
	instance.parent_track = _track
	instance.index = _index
	instance.position = _pos
	instance.trackType = _trackType
	return instance

func parse_and_add_special(rail_node_dict: Dictionary):
	if rail_node_dict.has("fork"):
		var fork_dict: Dictionary = rail_node_dict.get("fork")
		self.add_fork(RailFork.of_dict(fork_dict, self))
	if rail_node_dict.has("station"):
		var station_dict: Dictionary = rail_node_dict.get("station")
		self.add_station(RailStationResource.of_station_dict(station_dict, self))
	
func add_station(station: RailStationResource):
	Loggie.info("Found station: %s" %station.station_name)
	self.set_meta("station", station)
	GlobalState.stations.append(station)
	
func add_fork(fork: RailFork):
	self.set_meta("fork", fork)
	# add to track & global array
	self.parent_track.add_fork(fork)
	GlobalState.forks.append(fork)
