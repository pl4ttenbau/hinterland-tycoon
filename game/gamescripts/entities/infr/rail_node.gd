class_name RailNode extends Node

@export_storage var parent_track: RailTrack
@export var index: int
@export var position: Vector3
@export var trackType: String
@export_storage var specialNode: RailNodeSpecial

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
		if json_special && json_special.nodeType == "STATION":
			Loggie.info("station found")
			check_and_add_station(json_special)
	
func check_and_add_station(special_node_dict: Dictionary):
	Loggie.info("Station %s found!" % special_node_dict)
	var station_name: String = special_node_dict.get("stationName")
	var station_town: String = special_node_dict.get("stationTown")
	var station_pos: Vector3 = self.position
	var station_obj = RailStation.of(self, station_name, station_pos, station_town)
	GlobalState.stations.append(station_obj)
	# station_obj.spawn()
