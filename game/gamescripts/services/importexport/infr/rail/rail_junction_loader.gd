@icon("res://assets/icons/icon_fork_white.png")
class_name RailJunctionLoader extends Node

const SCENE_PATH = "res://scenes/subscenes/infr/fork_3d/rail_fork_3d.tscn"

@export var forks_by_pos: Dictionary = {}
@export var fork_store: RailJunctionArmStore = RailJunctionArmStore.new()

signal forks_spawned()

## Junctions and their legs and settings reference each other; break the cycles when the loader goes away.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for junction: RailJunctionData in forks_by_pos.values():
			junction.release_legs()
		forks_by_pos.clear()

func add_new_or_connection(node_fork: RailJunctionArm):
	var fork_pos: Vector3 = node_fork.railNode.position
	if ! forks_by_pos.has(fork_pos):
		# create new NewRailFork
		var new_fork := RailJunctionData.new(fork_pos)
		# Settings resolve once all junction views exist; erasing a junction disconnects this.
		self.forks_spawned.connect(new_fork.refresh_setting)
		new_fork.connect_rail_node_fork(node_fork)
		self.forks_by_pos.set(fork_pos, new_fork)
	else:
		# add connected_to
		var existing: RailJunctionData = self.forks_by_pos.get(fork_pos)
		if node_fork in existing.node_forks:
			return
		existing.connect_rail_node_fork(node_fork)

## Grouping by position is only for loading: legs at one position form one junction.
## Everywhere else, reach the junction through `RailJunctionArm.junction`.
func get_fork_at_pos(fork_pos: Vector3) -> RailJunctionData:
	return self.forks_by_pos.get(fork_pos)
		
func spawn_rail_forks():
	var fork_counter: int = 0
	for fork_data: RailJunctionData in self.forks_by_pos.values():
		var fork3d = self.spawn_single_fork(fork_data)
		fork3d.adjust_rotation.call_deferred()
		fork_counter += 1
	Loggie.info("%d forks spawned" % fork_counter)
	self.forks_spawned.emit()

func spawn_single_fork(fork_data: RailJunctionData) -> RailJunction3D:
	var fork3d: RailJunction3D = preload(SCENE_PATH).instantiate()
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
