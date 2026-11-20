class_name RailJunctionSetting extends Resource

@export var parent: RailJunctionData

@export var current: CurrentJunctionSetting

@export var settable_tracks: Array[int] = []

func _init(_parent: RailJunctionData):
	self.parent = _parent
	
func init_current_setting() -> void:
	var tracks: Array[int] = self.parent.connected_tracks
	if tracks.size() < 2:
		return
	if tracks.size() == 2:
		if self.current == null:
			self.current = CurrentJunctionSetting.new(tracks[0], tracks[1])
			self.parent.switched.emit(self.current)
		return

	var root_track: int = self.parent.get_static_track_num()
	self.settable_tracks = self.parent.get_switchable_track_nums()
	self.settable_tracks.erase(root_track)
	# A formerly fixed two-track connection remains selectable when a branch is added.
	if self.current != null:
		if not self.settable_tracks.has(self.current.connected):
			self.settable_tracks.push_front(self.current.connected)
		return
	if self.settable_tracks.is_empty():
		return
	self.current = CurrentJunctionSetting.new(root_track, self.settable_tracks[0])
	self.parent.switched.emit(self.current)

func switch() -> CurrentJunctionSetting:
	if self.current == null or self.settable_tracks.size() < 2:
		return self.current
	var old_connected: int = self.current.connected
	var settable_i: int = self.settable_tracks.find(self.current.connected)
	var future_i = settable_i + 1
	if future_i == self.settable_tracks.size():
		future_i = 0
	return self._switch_to_track(self.settable_tracks[future_i], old_connected)

## Select a settable branch directly, as route-setting will. Returns null if it is not settable.
func set_connected(track_num: int) -> CurrentJunctionSetting:
	if self.current == null or not self.settable_tracks.has(track_num):
		return null
	if self.current.connected == track_num:
		return self.current
	return self._switch_to_track(track_num, self.current.connected)

func _switch_to_track(track_num: int, _previous_track_num) -> CurrentJunctionSetting:
	self.current.connected = track_num
	Loggie.info("Fork%d: Changed switch from connecting %d to %d" % [self.parent.num, _previous_track_num, track_num])
	return self.current

func get_next_track_from_track(from_track_num: int) -> int:
	if self.current.root == from_track_num:
		return self.current.connected
	return self.current.root

## gets next RailNode in the direction this fork is currently set to
func get_connected_next_node() -> RailNodeData:
	var conn_fork_node: RailNodeData = null
	var node_is_first: bool = true
	for connected_node_fork: RailJunctionArm in self.parent.node_forks:
		var fork_node: RailNodeData = connected_node_fork.railNode
		if fork_node.parent_track.num == self.current.connected:
			conn_fork_node = fork_node
			if fork_node.index != 0: node_is_first = false
	var next_node_i: int = 1
	if ! node_is_first:
		next_node_i = conn_fork_node.index -1
	return conn_fork_node.parent_track.nodes[next_node_i]

## returns whether there's even the possibility of changing for setting: at least 3 connected tracks
func is_changable() -> bool:
	return self.parent.is_changable()
