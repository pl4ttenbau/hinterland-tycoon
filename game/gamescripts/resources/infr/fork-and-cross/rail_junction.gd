class_name RailJunctionData extends GameEntityData

signal node_fork_connected(node: RailJunctionArm)
signal switched(curr_setting: CurrentJunctionSetting)
signal setting_initialized(fork_setting: RailJunctionSetting)

@export_storage var fork3d: RailJunction3D
@export var setting: RailJunctionSetting
@export var pos: Vector3

@export var node_forks: Array[RailJunctionArm] = []

@export var connected_tracks: Array[int] = []
@export var static_tracks: Array[int] = []

static var _last_fork_num: int = 0

#region Initialization
func _init(_pos: Vector3):
	super(Enums.EntityTypes.FORK)
	self.pos = _pos
	self.setting = RailJunctionSetting.new(self)
	# assign number
	RailJunctionData._last_fork_num += 1
	self.num = RailJunctionData._last_fork_num
	self.node_fork_connected.connect(Callable(self, "_on_node_fork_connected"))
	
func connect_rail_node_fork(rail_node_fork: RailJunctionArm):
	self.node_fork_connected.emit(rail_node_fork)
#endregion

func is_changable() -> bool:
	if self.connected_tracks.size() <= 2: 
		return false
	return true

#region Getters
# Static & Switchable Track Getters
func get_static_track_num() -> int:
	if self.setting.current != null:
		return self.setting.current.root
	if self.static_tracks.is_empty():
		if self.is_changable():
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

## returns INCREASE if fork is at the start (node index 0) of track with given num
## and DECREASE if not
func get_track_dir_from_fork(track_num: int) -> Enums.PathDirection:
	for any_node_fork: RailJunctionArm in self.node_forks:
		if any_node_fork.track.num == track_num:
			if any_node_fork.railNode.is_first():
				return Enums.PathDirection.TRACK_NODES_INCREASE
			else:
				return Enums.PathDirection.TRACK_NODES_DECREASE
	return Enums.PathDirection.STOP
#endregion

#region Topology
## The track every route through this junction uses: the static root of a switch.
func get_root_track_num() -> int:
	if self.connected_tracks.size() == 2 and self.setting.current == null:
		return self.connected_tracks[0]
	return self.get_static_track_num()

## Tracks a train arriving on `from_track_num` could leave on, for any switch setting.
## Matches RailJunctionSetting.get_next_track_from_track: root to a branch, any branch back to the root.
func get_exit_track_nums(from_track_num: int) -> Array[int]:
	var exits: Array[int] = []
	if not self.connected_tracks.has(from_track_num) or self.connected_tracks.size() < 2:
		return exits
	var root: int = self.get_root_track_num()
	if from_track_num != root:
		exits.append(root)
		return exits
	for track_num: int in self.connected_tracks:
		if track_num != root and self._is_branch(track_num):
			exits.append(track_num)
	return exits

## A plain joint of two tracks always connects them; a switch connects its root to settable branches.
func _is_branch(track_num: int) -> bool:
	if self.connected_tracks.size() == 2:
		return true
	if self.setting.current != null and self.setting.current.connected == track_num:
		return true
	return not self.static_tracks.has(track_num)

## The leg of this junction on the given track, or null.
func get_node_fork(track_num: int) -> RailJunctionArm:
	for node_fork: RailJunctionArm in self.node_forks:
		if node_fork.track.num == track_num:
			return node_fork
	return null
#endregion

#region Switching
func switch():
	var curr_setting: CurrentJunctionSetting = self.setting.switch()
	self.switched.emit(curr_setting)

## Point the switch at one branch. Returns false if that branch cannot be selected here.
func set_connected_track(track_num: int) -> bool:
	var curr_setting: CurrentJunctionSetting = self.setting.set_connected(track_num)
	if curr_setting == null:
		return false
	self.switched.emit(curr_setting)
	return true
#endregion

## Break the junction ↔ leg and junction ↔ setting links so the data can be freed with its loader.
func release_legs() -> void:
	for node_fork: RailJunctionArm in self.node_forks:
		node_fork.junction = null
	self.node_forks.clear()
	if self.setting != null:
		self.setting.parent = null

func refresh_setting() -> void:
	self.setting.init_current_setting()
	self.setting_initialized.emit(self.setting)

#region Callables
func _on_node_fork_connected(node_fork: RailJunctionArm):
	var track_num: int = node_fork.track.num
	node_fork.junction = self
	# add to own NodeForkData array
	self.node_forks.append(node_fork)
	# remember all connected, but also unmovable track connections
	self.connected_tracks.append(track_num)
	if node_fork.static_track == true:
		self.static_tracks.append(track_num)
#endregion
