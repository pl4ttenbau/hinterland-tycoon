class_name CurrentForkSetting extends Resource

@export var root: int

@export var connected: int:
	get(): return connected
	set(value):
		connected = value
		self.setting_changed.emit()
		
signal setting_changed()

func _init(_root: int, _connected: int):
	self.root = _root
	self.connected = _connected
