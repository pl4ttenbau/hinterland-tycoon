class_name RailForkSetting extends Resource

@export var parent: NewRailForkData

@export var current: CurrentForkSetting

@export var all_set_to: Array[int] = []

@export var is_changeable: bool = true

func _init(_parent: NewRailForkData):
	self.parent = _parent
	
func init_current_setting():
	# not connected to anything, rly only track end
	if self.parent.connected_tracks.size() <= 1: 
		self.is_changeable = false
		return
	if parent.connected_tracks.size() == 2:
		self.is_changeable = false
	else:
		self.is_changeable = true
	self.current = CurrentForkSetting.new(self.parent.connected_tracks[0], 
			self.parent.connected_tracks[1])
