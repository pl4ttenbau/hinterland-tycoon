class_name NewRailForkData extends GameObject

@export var pos: Vector3

@export var setting: RailForkSetting

func _init(_pos: Vector3):
	super(Enums.EntityTypes.FORK)
	self.pos = _pos
	self.setting = RailForkSetting.new(self)
