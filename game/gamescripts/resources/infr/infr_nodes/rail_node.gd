class_name RailNode extends BasicInfrNode

@export_storage var parent_track: RailTrack
@export_storage var fork: RailFork
@export_storage var station: RailStationResource

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
	
func add_station(_station: RailStationResource):
	Loggie.info("Found station: %s" % _station.station_name)
	self.station = _station
	# add to track & global station list
	self.parent_track.stations.append(_station)
	GlobalState.stations.append(_station)
	
func add_fork(_fork: RailFork):
	self.fork = _fork
	# add to track & global array
	self.parent_track.add_fork(_fork)
	GlobalState.forks.append(_fork)
