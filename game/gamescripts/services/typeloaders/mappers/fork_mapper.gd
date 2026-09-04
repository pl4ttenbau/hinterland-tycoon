class_name ForkMapper extends Node

static func node_fork_from_dict(node_fork_dict: Dictionary, parent_node: RailNodeData) -> RailNodeForkData:
	var node_fork_data := RailNodeForkData.new()
	node_fork_data.railNode = parent_node
	# non-movable?
	if node_fork_dict.has("static"):
		node_fork_data.static_track = node_fork_dict.get("static")
	# connective tracks
	var track_num: int = parent_node.parent_track.num
	node_fork_data.all_connective_tracks.append(track_num)
	var _connective_tracks = node_fork_dict.get("connectiveTracks") as Array
	for connective_track in _connective_tracks:
		node_fork_data.connective_tracks.append(int(connective_track))
		node_fork_data.all_connective_tracks.append(int(connective_track))
	# set to
	node_fork_data.set_to = node_fork_dict.get("setTo", null)
	return node_fork_data
