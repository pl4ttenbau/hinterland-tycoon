class_name RailForkSetting extends Resource

@export var parent: NewRailForkData

@export var current: CurrentForkSetting

@export var settable_tracks: Array[int] = []

@export var all_set_to: Array[int] = []

@export var is_changeable: bool = true

func _init(_parent: NewRailForkData):
	self.parent = _parent
	
func init_current_setting():
	# not connected to anything, rly only track end
	if self.parent.connected_tracks.size() <= 1: 
		self.is_changeable = false
		return
	# straightly connected but no third rail
	if parent.connected_tracks.size() == 2:
		self.is_changeable = false
		self.current = CurrentForkSetting.new(self.parent.connected_tracks[0], 
			self.parent.connected_tracks[1])
	# connected with at least 2 switchable settings
	else:
		self.is_changeable = true
		self.current = CurrentForkSetting.new(self.parent.connected_tracks[0], 
			self.parent.connected_tracks[1])
		self._set_changeable_tracks()
	self.parent.switched.emit(self.current)
			
func _set_changeable_tracks(): 
	for connected_track_num: int in self.parent.connected_tracks:
		if connected_track_num == self.current.root: continue
		if connected_track_num in self.settable_tracks: continue
		self.settable_tracks.append(connected_track_num)
			
func switch() -> CurrentForkSetting:
	if ! self.is_changeable: return
	var old_connected: int = self.current.connected
	var settable_i: int = self.settable_tracks.find(self.current.connected)
	var future_i = settable_i + 1
	if future_i == self.settable_tracks.size():
		future_i = 0
	return self.connect_to_track(self.settable_tracks[future_i], old_connected)

func connect_to_track(track_num: int, _previous_track_num) -> CurrentForkSetting:
	self.current.connected = track_num
	Loggie.info("Changed switch from connecting %d to %d" % [_previous_track_num, track_num])
	return self.current
	
func get_connected_next_node() -> RailNodeData:
	var conn_fork_node: RailNodeData = null
	var node_is_first: bool = true
	for fork_node: RailNodeData in self.parent.rail_nodes:
		if fork_node.parent_track.num == self.current.connected:
			conn_fork_node = fork_node
			if fork_node.index != 0: node_is_first = false
	var next_node_i: int = 1
	if ! node_is_first:
		next_node_i = conn_fork_node.index -1
	return conn_fork_node.parent_track.nodes[next_node_i]
	
