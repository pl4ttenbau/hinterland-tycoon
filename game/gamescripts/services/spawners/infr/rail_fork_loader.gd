@icon("res://assets/icons/icon_fork_white.png")
class_name RailForkLoader extends Node

@export var forks_by_pos: Dictionary = {}

@export var node_forks_by_track: Dictionary = {}

func _enter_tree() -> void:
	Managers.forks = self
	# listen to loaded tracks
	Managers.rails.track_storage.track_added.connect(Callable(self, "_on_track_loaded"))
	
func add_new_or_connection(node_fork: RailNodeForkData):
	var fork_pos: Vector3 = node_fork.railNode.position
	if ! forks_by_pos.has(fork_pos):
		# create new NewRailFork
		var inst := NewRailForkData.new(fork_pos)
		inst.setting.connected_tracks.append(node_fork.railNode.parent_track.num)
		inst.setting.all_set_to.append(node_fork.set_to)
		self.forks_by_pos.set(fork_pos, inst)
	else:
		# add connected_to
		var existing: NewRailForkData = self.forks_by_pos.get(fork_pos)
		existing.setting.connected_tracks.append(node_fork.railNode.parent_track.num)
		existing.setting.all_set_to.append(node_fork.set_to)

#region Callbacks
func _on_track_loaded(track: RailTrackData):
	for node: RailNodeData in track.nodes:
		if node.fork:
			self.add_new_or_connection(node.fork)
#endregion
