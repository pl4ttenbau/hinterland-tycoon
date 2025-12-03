class_name NewRailForkData extends GameObject

const SCENE_PATH = "res://assets/meshes/infr/rail/fork/rail_fork.tscn"

@export_storage var container: RailFork3D
@export var setting: RailForkSetting
@export var pos: Vector3

@export var rail_nodes: Array[RailNodeData] = []
@export var connected_tracks: Array[int] = []

signal node_added(node: RailNodeData)

signal switched(curr_setting: CurrentForkSetting)

#region Initialization & Spawning
func _init(_pos: Vector3):
	super(Enums.EntityTypes.FORK)
	self.pos = _pos
	self.setting = RailForkSetting.new(self)
	# connect 2 signal
	Managers.forks.forks_spawned.connect(Callable(self, "_on_forks_spawned"))
	
func add_node(rail_node: RailNodeData):
	self.rail_nodes.append(rail_node)
	self.connected_tracks.append(rail_node.parent_track.num)
	self.node_added.emit(rail_node)
	
func spawn() -> RailFork3D:
	var instanciated: RailFork3D = preload(SCENE_PATH).instantiate()
	instanciated.fork_obj = self
	# set pos
	instanciated.position = self.pos
	self.container = instanciated
	# add as rail container child
	Managers.forks.add_child(instanciated)
	return instanciated
#endregion

#region Switching
func switch():
	var curr_setting: CurrentForkSetting = self.setting.switch()
	self.switched.emit(curr_setting)
#endregion

#region Callables
func _on_forks_spawned():
	self.setting.init_current_setting()
#endregion
