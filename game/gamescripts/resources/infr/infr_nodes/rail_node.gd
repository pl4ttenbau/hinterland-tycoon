@icon("res://assets/icons/icon_infr_node_white.png")
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
		# Legacy maps stored only handleIn and assumed mirrored handles.
		self.handle_out = -1 * self.handle_in
	if rail_node_dict.has("handleOut"):
		self.handle_out = WorldUtils.vec3_from_float_arr(rail_node_dict.get("handleOut"))
	if rail_node_dict.has("end") && rail_node_dict.get("end") == true:
		self.is_end = true
	if rail_node_dict.has("fork"):
		var inst: RailNodeForkData = ForkMapper.node_fork_from_dict(rail_node_dict.get("fork"), self)
		# register in fork store
		Managers.rails.fork_storage.add(inst)
		# add to node
		self.fork = inst
	# Stops are attached in the interchange-loading phase, after both networks
	# exist. Track geometry no longer creates stations as a parsing side effect.

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
