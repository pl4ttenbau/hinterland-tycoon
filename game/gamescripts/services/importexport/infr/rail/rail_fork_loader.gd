@icon("res://assets/icons/icon_fork_white.png")
class_name RailForkLoader extends Node

const SCENE_PATH = "res://scenes/subscenes/infr/fork_3d/rail_fork_3d.tscn"

@export var forks_by_pos: Dictionary = {}
@export var fork_store: RailNodeForkStore = RailNodeForkStore.new()

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
		new_fork.connect_rail_node_fork(node_fork)
		self.forks_by_pos.set(fork_pos, new_fork)
	else:
		# add connected_to
		var existing: NewRailForkData = self.forks_by_pos.get(fork_pos)
		existing.setting.all_set_to.append(node_fork.set_to)
		existing.connect_rail_node_fork(node_fork)

# TODO: use
func _get_or_create_fork(_fork_pos: Vector3) -> NewRailForkData:
	var fork_at_pos: NewRailForkData = forks_by_pos.get(_fork_pos, null)
	if fork_at_pos: return fork_at_pos
	else: return NewRailForkData.new(_fork_pos)
		
func get_fork_at_pos(fork_pos: Vector3) -> NewRailForkData:
	return self.forks_by_pos.get(fork_pos)
		
func spawn_rail_forks():
	var fork_counter: int = 0
	for fork_data: NewRailForkData in self.forks_by_pos.values():
		var fork3d = self.spawn_single_fork(fork_data)
		fork3d.adjust_rotation.call_deferred()
		fork_counter += 1
	Loggie.info("%d forks spawned" % fork_counter)
	self.forks_spawned.emit()

func spawn_single_fork(fork_data: NewRailForkData) -> RailFork3D:
	var fork3d: RailFork3D = preload(SCENE_PATH).instantiate()
	fork3d.fork_obj = fork_data
	# link to data obj
	fork_data.fork3d = fork3d
	# add as rail fork3d child
	self.add_child(fork3d)
	return fork3d

#region Callbacks
func _on_track_loaded(track: RailTrackData):
	for node: RailNodeData in track.nodes:
		if node.fork:
			self.add_new_or_connection(node.fork)

func _on_rails_spawned(_outer_rails: Array[RailTrack3D]):
	self.spawn_rail_forks()
#endregion
