class_name ForkMapper extends Node

## A fork lists the tracks meeting at a track end (connectiveTracks). Junctions choose their own initial
## setting; maps no longer store one.
static func node_fork_from_dict(node_fork_dict: Dictionary, parent_node: RailNodeData) -> RailJunctionArm:
	var node_fork_data := RailJunctionArm.new()
	node_fork_data.railNode = parent_node
	# non-movable?
	if node_fork_dict.has("static"):
		node_fork_data.static_track = node_fork_dict.get("static")
	# connective tracks
	var _connective_tracks = node_fork_dict.get("connectiveTracks") as Array
	for connective_track in _connective_tracks:
		node_fork_data.connective_tracks.append(int(connective_track))
	return node_fork_data
