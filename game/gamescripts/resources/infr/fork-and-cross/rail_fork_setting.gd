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
			
func _set_changeable_tracks(): 
	for connected_track_num: int in self.parent.connected_tracks:
		if connected_track_num == self.current.root: continue
		if connected_track_num in self.settable_tracks: continue
		self.settable_tracks.append(connected_track_num)
			
func set_to_next_track() -> CurrentForkSetting:
	if ! self.is_changeable: return
	var old_connected: int = self.current.connected
	var settable_i: int = self.settable_tracks.find(self.current.connected)
	var future_i = settable_i + 1
	if future_i == self.settable_tracks.size():
		future_i = 0
	self.current.connected = self.settable_tracks[future_i]
	Loggie.info("Changed switch from connecting %d to %d" % [old_connected, self.current.connected])
	return self.current
