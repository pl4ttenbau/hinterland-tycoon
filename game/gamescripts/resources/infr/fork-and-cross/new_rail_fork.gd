class_name NewRailForkData extends GameEntityData

const SCENE_PATH = "res://scenes/subscenes/infr/fork_3d/rail_fork_3d.tscn"

signal node_fork_connected(node: RailNodeForkData)
signal switched(curr_setting: CurrentForkSetting)
signal setting_initialized(fork_setting: RailForkSetting)

@export_storage var fork3d: RailFork3D
@export var setting: RailForkSetting
@export var pos: Vector3

@export var node_forks: Array[RailNodeForkData] = []

@export var connected_tracks: Array[int] = []
@export var static_tracks: Array[int] = []

static var _last_fork_num: int = 0

#region Initialization
func _init(_pos: Vector3):
	super(Enums.EntityTypes.FORK)
	self.pos = _pos
	self.setting = RailForkSetting.new(self)
	# assign number
	NewRailForkData._last_fork_num += 1
	self.num = NewRailForkData._last_fork_num
	# connect 2 signal
	Managers.forks.forks_spawned.connect(Callable(self, "_on_forks_spawned"))
	self.node_fork_connected.connect(Callable(self, "_on_node_fork_connected"))
	
func connect_rail_node_fork(rail_node_fork: RailNodeForkData):
	self.node_fork_connected.emit(rail_node_fork)
#endregion

# Static & Switchable Track Getters
func get_static_track_num() -> int:
	if self.static_tracks.is_empty():
		var forks_tracks_arr_str: String = ", ".join(self.connected_tracks)
		Loggie.warn("Fork (tracks %s): cannot find any static track connection; returning first" % [forks_tracks_arr_str])
		return self.connected_tracks[0]
	return self.static_tracks[0]

func get_switchable_track_nums() -> Array[int]:
	var switchable_track_nums: Array[int] = []
	for connected_track_num: int in self.connected_tracks:
		if !self.static_tracks.has(connected_track_num):
			switchable_track_nums.append(connected_track_num)
	return switchable_track_nums

#region Spawning
func spawn() -> RailFork3D:
	var spawned_fork3d: RailFork3D = preload(SCENE_PATH).instantiate()
	spawned_fork3d.fork_obj = self
	# connect signals
	self.setting_initialized.connect(Callable(spawned_fork3d, "_on_setting_initialized"))
	# set pos
	spawned_fork3d.position = self.pos
	self.fork3d = spawned_fork3d
	# add as rail fork3d child
	Managers.forks.add_child(spawned_fork3d)
	return spawned_fork3d
#endregion

#region Switching
func switch():
	var curr_setting: CurrentForkSetting = self.setting.switch()
	self.switched.emit(curr_setting)
#endregion

#region Callables
func _on_forks_spawned():
	self.setting.init_current_setting()
	self.setting_initialized.emit(self.setting)

func _on_node_fork_connected(node_fork: RailNodeForkData):
	var track_num: int = node_fork.track.num
	# add to own NodeForkData array
	self.node_forks.append(node_fork)
	# remember all connected, but also unmovable track connections
	self.connected_tracks.append(track_num)
	if node_fork.static_track == true:
		self.static_tracks.append(track_num)
#endregion
