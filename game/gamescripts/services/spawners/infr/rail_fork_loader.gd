@icon("res://assets/icons/icon_fork_white.png")
class_name RailForkLoader extends Node

@export var forks_by_pos: Dictionary = {}

signal forks_spawned()

func _enter_tree() -> void:
	Managers.forks = self
	# listen to loaded tracks
	Managers.rails.track_storage.track_added.connect(Callable(self, "_on_track_loaded"))
	SignalBus.rails_spawned.connect(Callable(self, "_on_rails_spawned"))
	
func add_new_or_connection(node_fork: RailNodeForkData):
	var fork_pos: Vector3 = node_fork.railNode.position
	if ! forks_by_pos.has(fork_pos):
		# create new NewRailFork
		var new_fork := NewRailForkData.new(fork_pos)
		new_fork.setting.all_set_to.append(node_fork.set_to)
		new_fork.add_node(node_fork.railNode)
		self.forks_by_pos.set(fork_pos, new_fork)
	else:
		# add connected_to
		var existing: NewRailForkData = self.forks_by_pos.get(fork_pos)
		existing.setting.all_set_to.append(node_fork.set_to)
		existing.add_node(node_fork.railNode)
		
func spawn_rail_forks():
	for fork: NewRailForkData in self.forks_by_pos.values():
		var container = fork.spawn()
		container.adjust_rotation()
	self.forks_spawned.emit()

#region Callbacks
func _on_track_loaded(track: RailTrackData):
	for node: RailNodeData in track.nodes:
		if node.fork:
			self.add_new_or_connection(node.fork)
			
func _on_rails_spawned(_outer_rails: Array[OuterRailTrack]):
	self.spawn_rail_forks()
#endregion
