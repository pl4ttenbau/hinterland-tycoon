@icon("res://assets/icons/icon_infr_node_white.png")
class_name RailNodeData extends AbstractInfrNode

@export var fork: RailNodeForkData
@export var station: NodeStationLinkData

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
