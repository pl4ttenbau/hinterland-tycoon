class_name CurrentForkSetting extends Resource

@export var main: int

@export var secondary: int

func _init(_main: int, _secondary: int):
	self.main = _main
	self.secondary = _secondary
