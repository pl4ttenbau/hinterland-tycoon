class_name GameObject extends Resource

@export var type: Enums.EntityTypes
@export var num: int

func _init(_type: Enums.EntityTypes):
	self.type = _type
