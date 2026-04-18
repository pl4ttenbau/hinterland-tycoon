@icon("icon_infr_node_white")
class_name RailNodeData extends BasicInfrNodeData

@export var parent_track: AbstractTrack:
	set(value): 
		parent_track = value
	get(): return parent_track

@export var fork: RailNodeForkData
@export var station: NodeStationLinkData
@export var is_end: bool = false

static func of(_index: int, _pos: Vector3, _track: RailTrackData) -> RailNodeData:
	var instance := RailNodeData.new()
	instance.parent_track = _track
	instance.index = _index
	instance.position = _pos
	return instance

func parse_and_add_special(rail_node_dict: Dictionary):
	if rail_node_dict.has("handleIn"):
		self.handle_in = WorldUtils.vec3_from_float_arr(rail_node_dict.get("handleIn"))
		# handle_out is always the same as in, but negative
		self.handle_out = -1 * self.handle_in
	if rail_node_dict.has("end") && rail_node_dict.get("end") == true:
		self.is_end = true
	if rail_node_dict.has("fork"):
		var fork_dict: Dictionary = rail_node_dict.get("fork")
		self.fork = RailNodeForkData.of_dict(fork_dict, self)
	if rail_node_dict.has("station"):
		var station_dict: Dictionary = rail_node_dict.get("station")
		var node_station_link: NodeStationLinkData = NodeStationLinkData.of_station_dict(station_dict, self)
		self.station = node_station_link
		Managers.stations.add_station_link_from_node(node_station_link)

func as_ref() -> RailNodeRef:
	var track_num: int = self.parent_track.num
	return RailNodeRef.new(track_num, self.index)

#region Getters
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
#endregion
