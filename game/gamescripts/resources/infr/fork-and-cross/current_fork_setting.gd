class_name CurrentForkSetting extends Resource

signal setting_changed()

signal setting_initialized()

## static part of the fork, which is always connected
@export var root: int

## changeable part of the fork, which can be changed
@export var connected: int:
	get(): return connected
	set(value):
		connected = value
		self.setting_changed.emit()

func _init(_root: int, _connected: int):
	self.root = _root
	self.connected = _connected
	self.setting_initialized.emit()
