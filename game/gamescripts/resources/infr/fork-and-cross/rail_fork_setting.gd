class_name RailForkSetting extends Resource

@export var parent: NewRailForkData

@export var current: CurrentForkSetting

@export var settable_tracks: Array[int] = []

@export var all_set_to: Array[int] = []

func _init(_parent: NewRailForkData):
	self.parent = _parent
	
func init_current_setting():
	# not connected to anything, rly only track end
	if self.parent.connected_tracks.size() <= 1: 
		return
	# straightly connected but no third rail
	if parent.connected_tracks.size() == 2:
		self.current = CurrentForkSetting.new(self.parent.connected_tracks[0], 
			self.parent.connected_tracks[1])
	# connected with at least 2 switchable settings
	else:
		self.current = CurrentForkSetting.new(
			self.parent.get_static_track_num(), 
			self.parent.get_switchable_track_nums()[0]
		)
		self.settable_tracks = self.parent.get_switchable_track_nums()
	# fire initial switched signal, so current setting initialized itself
	self.parent.switched.emit(self.current)

func switch() -> CurrentForkSetting:
	if ! self.is_changable(): return
	var old_connected: int = self.current.connected
	var settable_i: int = self.settable_tracks.find(self.current.connected)
	var future_i = settable_i + 1
	if future_i == self.settable_tracks.size():
		future_i = 0
	return self._switch_to_track(self.settable_tracks[future_i], old_connected)

func _switch_to_track(track_num: int, _previous_track_num) -> CurrentForkSetting:
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
	for connected_node_fork: RailNodeForkData in self.parent.node_forks:
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
	if self.parent.connected_tracks.size() <= 2: 
		return false
	return true
